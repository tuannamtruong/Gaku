# Gaku

ASP.NET application for hiking across Europe.

## Architecture

### Deep dive

See [docs/software-architecture.md](docs/software-architecture.md) for more architectural details and diagrams.

### Clean Architecture Overview

```
Gaku.Domain                             business rules and data shapes
  ▲
  ├── Gaku.Application ◄─────┐          business workflows and capability contracts
  │     ▲                    │
  │     │                    │
  └── Gaku.Infrastructure ◄──│          technical implementations of those contracts
                         Frontend

```

**Dependency rule**: arrows point inward only — outer layers depend on inner layers, never the reverse. `Domain` must never reference `Application`, `Infrastructure`, or Frontend. `Application` must never reference `Infrastructure`.

### Frontend and Infrastructure

`Gaku.Api` and `Gaku.Web` reference Infrastructure **only** in `Program.cs` (the composition root) to call `AddInfrastructure()` and wire up DI. No page, component, or controller should import an Infrastructure type directly — all business interactions go through Application service interfaces. If code outside `Program.cs` references an Infrastructure namespace, it is a layering violation.

---

## Project

See [docs/class-diagram.md](docs/class-diagram.md) for per-project class diagrams.

### Project Map

```
src/
  Gaku.Domain/
    Entities/                   Aggregate roots + children
    Enums/
    Interfaces/
    ValueObjects/
  Gaku.Application/
    DTOs/
    Interfaces/
    Services/
    Extensions/
  Gaku.Infrastructure/
    Cache/
    Data/
    Data/Configurations/
    Repositories/
    Services/
    Extensions/
  Gaku.Api/
    Endpoints/
    Program.cs
  Gaku.Web/
    Components/Layout/
    Components/Map/
    Pages/                      Home (map view), Trails (trail list)
    Services/
    wwwroot/js/
tests/
  Gaku.Domain.Tests/
  Gaku.Application.Tests/
  Gaku.Infrastructure.Tests/
  Gaku.Web.Tests/
```

### Naming Conventions

- **Entities, DTOs, value objects**: singular — `Trail`, `TrailDto`, `Coordinates`
- **C# folders**: singular — `Entity/`, `ValueObject/`, `Endpoint/`, `Repository/`, `Service/`, `Interface/`
- **Interfaces**: `I` prefix + singular noun — `ITrailRepository`, `IUnitOfWork`
- **DB tables**: singular — `Trail`, `Waypoint`, `Location` (EF default; do not pluralise)
- **Enums**: singular type name, plural only for `[Flags]` — `DifficultyLevel`, `TrailType`

## Key Design Decisions

### PostGIS spatial storage

`Coordinates` (domain value object) is mapped to a PostGIS `geography(Point,4326)` column via an EF Core `HasConversion` to `NetTopologySuite.Geometries.Point`. This keeps the Domain layer free of NTS types.
The `TrailRepository.GetNearbyAsync` uses `FromSqlRaw` with `ST_DWithin` to leverage the GIST spatial index.

### OpenStreetMap integration

- **Nominatim** (`/search`) — location geocoding and search
- **Overpass API** — retrieves hiking paths (`highway=path/track` + `sac_scale`, `route=hiking`) within the map bounds
- Tile URL template (`https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png`) is resolved client-side by Leaflet

### Leaflet JS interop

`LeafletInterop` (scoped service) loads `leaflet-interop.js` as an ES module via `IJSRuntime`. Map instances are keyed by element ID to support multiple maps on one page. The component calls `destroyMap` on `IAsyncDisposable.DisposeAsync` to prevent memory leaks.

### Blazor render mode

All interactive pages use `@rendermode InteractiveServer` so server-side services (EF Core, HTTP clients) are available directly without a separate API call from the frontend.

## Tech Stack

| Layer          | Technology                             |
| -------------- | -------------------------------------- |
| Runtime        | .NET 10                                |
| Backend API    | ASP.NET Core Minimal APIs              |
| Frontend       | Blazor Web App (InteractiveServer)     |
| Maps           | Leaflet.js + OpenStreetMap tiles       |
| ORM            | EF Core 10 + Npgsql                    |
| Database       | PostgreSQL 16 + PostGIS 3.4            |
| Backend tests  | xUnit + FluentAssertions + NSubstitute |
| Frontend tests | bUnit + NSubstitute                    |

## External API Rate Limits

| Service   | Policy                                                                 |
| --------- | ---------------------------------------------------------------------- |
| Nominatim | Max 1 req/sec; `User-Agent` header required                            |
| Overpass  | Public instance; avoid hammering; consider self-hosting for production |
| OSM Tiles | Tile Usage Policy applies; add attribution                             |

---

## Environment Variables (override in appsettings)

```
ConnectionStrings__DefaultConnection   PostgreSQL connection string
```

## Environment Files

All `.env` files are gitignored and must be created manually. Three files exist in the project:

### `.env` (repo root)

Used by: local `docker compose` and EF Core CLI tools.

| Variable                               | Responsibility                                                                                                 |
| -------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| `POSTGRES_DB`                          | Database name for the PostgreSQL container                                                                     |
| `POSTGRES_USER`                        | PostgreSQL login role                                                                                          |
| `POSTGRES_PASSWORD`                    | PostgreSQL login password                                                                                      |
| `ConnectionStrings__DefaultConnection` | Full ADO.NET connection string for the ASP.NET Core apps and EF Core migrations                                |
| `HOST_SYSTEM_REPO`                     | Absolute path to the repo on the host machine (used when bind-mounting the source into containers)             |
| `DOCKERHUB_USERNAME`                   | DockerHub account name used by `make docker_login` / `make docker_push`                                        |
| `DOCKERHUB_TOKEN`                      | DockerHub personal access token (Read/Write/Delete) — generate at hub.docker.com > Account Settings > Security |

### `infra/k8s/local/.env.k8s`

Used by: `kubectl apply -k infra/k8s/local/` — Kustomize reads this to generate the `gaku-secret` Kubernetes secret. Co-located with `kustomization.yaml`.

| Variable                               | Responsibility                                                 |
| -------------------------------------- | -------------------------------------------------------------- |
| `POSTGRES_DB`                          | Database name inside the cluster                               |
| `POSTGRES_USER`                        | PostgreSQL login role inside the cluster                       |
| `POSTGRES_PASSWORD`                    | PostgreSQL login password inside the cluster                   |
| `ConnectionStrings__DefaultConnection` | ADO.NET connection string used by the API and db-migrator pods |

### `jenkins/local/.env`

Used by: `jenkins/local/docker-compose.yml` to configure the Smee relay sidecar.

| Variable   | Responsibility                                                                        |
| ---------- | ------------------------------------------------------------------------------------- |
| `SMEE_URL` | Smee.io channel URL that relays GitHub webhook payloads to the local Jenkins instance |

---

## Local Development — PostgreSQL

PostgreSQL + PostGIS runs in Docker via the root `docker-compose.yml`. Credentials are read from `.env`.

```bash
# Start database only
docker compose up postgres -d

# Start database + run EF Core migrations
docker compose up postgres db-migrator -d

# Start full stack (postgres + migrations + api + web)
docker compose up --build -d
```

Ports: PostgreSQL on `5432` · API on `8080` · Web on `8081`.

Stop and remove containers (data volume is preserved):

```bash
docker compose down
```

---

## CICD + Infrastructure

> For CI/CD setup (Jenkins, pipeline, Smee) see [docs/cicd-workflow-local-first.md](docs/cicd-workflow-local-first.md).
> For Infrastructure setup (Kubernetes, Minikube, Terraform) setup see [docs/infrastructure.md](docs/infrastructure.md).
