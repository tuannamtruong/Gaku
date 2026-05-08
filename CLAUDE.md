# Gaku — Hiking in Europe

ASP.NET Core 10 application for discovering and navigating hiking trails across Europe.

## Tech Stack

| Layer | Technology |
|---|---|
| Runtime | .NET 10 |
| Backend API | ASP.NET Core Minimal APIs |
| Frontend | Blazor Web App (InteractiveServer) |
| Maps | Leaflet.js + OpenStreetMap tiles |
| ORM | EF Core 10 + Npgsql |
| Database | PostgreSQL 16 + PostGIS 3.4 |
| Backend tests | xUnit + FluentAssertions + NSubstitute |
| Frontend tests | bUnit + NSubstitute |

## Architecture — Clean Architecture

```
Gaku.Domain                       business rules and data shapes
  ├── Gaku.Application            business workflows and capability contracts
  │     └── Gaku.Infrastructure   technical implementations of those contracts
  └── Gaku.Infrastructure   
```

**Dependency rule**: arrows point inward only — outer layers depend on inner layers, never the reverse. `Application` must never reference `Infrastructure`.

### Presentation layer and Infrastructure

`Gaku.Api` and `Gaku.Web` reference Infrastructure **only** in `Program.cs` (the composition root) to call `AddInfrastructure()` and wire up DI. No page, component, or controller should import an Infrastructure type directly — all business interactions go through Application service interfaces. If code outside `Program.cs` references an Infrastructure namespace, it is a layering violation.

---
**Rule**: dependencies only point inward. `Core` must never reference `Application`, `Infrastructure`, `Api`, or `Web`. `Application` and `Infrastructure` are sibling layers — neither references the other.

## Project Map

```
src/
  Gaku.Domain/
    Entities/        Trail, Waypoint, Location  (aggregate roots + children)
    Enums/           DifficultyLevel, TrailType
    Interfaces/      ITrailRepository, IUnitOfWork
    ValueObjects/    Coordinates  (pure record, haversine helper)
  Gaku.Application/
    DTOs/            TrailDto, MapInfoDto, LocationDto, ...
    Interfaces/      IOpenStreetMapService  (OSM facade contract)
    Services/        ITrailService / TrailService
                     IMapService   / MapService
    Extensions/      ServiceCollectionExtensions (AddApplication)
  Gaku.Infrastructure/
    Data/            GakuDbContext (also implements IUnitOfWork)
    Data/Configurations/  EF IEntityTypeConfiguration per entity
    Repositories/    TrailRepository  (PostGIS ST_DWithin for nearby)
    Services/        OpenStreetMapService (Nominatim + Overpass API)
    Extensions/      ServiceCollectionExtensions (AddInfrastructure)
  Gaku.Api/
    Endpoints/       TrailEndpoints, MapEndpoints  (Minimal API)
    Program.cs
  Gaku.Web/
    Components/Layout/   MainLayout, NavMenu
    Components/Map/      LeafletMap  (JS interop wrapper)
    Pages/               Home (map view), Trails (trail list)
    Services/            LeafletInterop  (IJSRuntime wrapper)
    wwwroot/js/          leaflet-interop.js  (ES module)
tests/
  Gaku.Domain.Tests/       Entity + value-object unit tests
  Gaku.Application.Tests/  Service tests with NSubstitute fakes
  Gaku.Infrastructure.Tests/ OSM service tests with MockHttp
  Gaku.Web.Tests/          bUnit component tests
```

## Architecture Diagrams

> See [docs/architecture.md](docs/architecture.md) for rendered C4, clean architecture, container, ER, and sequence diagrams.
> See [docs/class-diagram.md](docs/class-diagram.md) for per-project class diagrams.

**Class diagram rule**: when creating or updating class diagrams, exclude enums, value objects, and record types — show only classes and interfaces.

---

## Naming Conventions

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

## External API Rate Limits

| Service | Policy |
|---|---|
| Nominatim | Max 1 req/sec; `User-Agent` header required |
| Overpass | Public instance; avoid hammering; consider self-hosting for production |
| OSM Tiles | Tile Usage Policy applies; add attribution |

## Environment Variables (override in appsettings)

```
ConnectionStrings__DefaultConnection   PostgreSQL connection string
```

## Environment Files

All `.env` files are gitignored and must be created manually. Two files exist in the project:

### `.env` (repo root)
Used by: local `docker compose`, EF Core CLI tools, and `kubectl apply -k` (Kustomize reads this to generate the `gaku-secret` Kubernetes secret).

| Variable | Responsibility |
|---|---|
| `POSTGRES_DB` | Database name for the PostgreSQL container |
| `POSTGRES_USER` | PostgreSQL login role |
| `POSTGRES_PASSWORD` | PostgreSQL login password |
| `ConnectionStrings__DefaultConnection` | Full ADO.NET connection string for the ASP.NET Core apps and EF Core migrations |
| `HOST_SYSTEM_REPO` | Absolute path to the repo on the host machine (used when bind-mounting the source into containers) |

### `jenkins/.env`
Used by: `jenkins/docker-compose.yml` to configure the Smee relay sidecar.

| Variable | Responsibility |
|---|---|
| `SMEE_URL` | Smee.io channel URL that relays GitHub webhook payloads to the local Jenkins instance |

---

## CI/CD Pipeline (Local — Docker + Jenkins)

### Files

```
Jenkinsfile                  declarative pipeline (repo root)
.dockerignore                excludes bin/, obj/, .git/, .vs/ from build context
docker/Dockerfile.ci         multi-stage: stage `build` compiles, stage `test` runs tests
jenkins/docker-compose.yml   Jenkins container (port 8090) with Docker socket mounted
```
### Starting Jenkins

```bash
# 1. Get a Smee channel URL (one-time, free, permanent)
#    Visit https://smee.io/new — copy the URL, then:
echo "SMEE_URL=https://smee.io/your-channel-id" > jenkins/.env

# 2. Start Jenkins + Smee relay
cd jenkins && docker compose up -d
# UI at http://localhost:8090
docker exec gaku-jenkins cat /var/jenkins_home/secrets/initialAdminPassword

# 3. Register the Smee URL as a webhook in the GitHub repo
#    GitHub repo → Settings → Webhooks → Add webhook
#    Payload URL : <your smee.io URL>
#    Content type: application/json
#    Events      : Just the push event
```

Required Jenkins plugins: **Pipeline**, **Git**, **GitHub**, **JUnit**, **Timestamper**.

Pipeline job config: SCM → Git → `https://github.com/tuannamtruong/Gaku` → branch `*/master` → script path `Jenkinsfile`.
