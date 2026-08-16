# Gaku

Trail discovery for hiking in Europe. Gaku renders OpenStreetMap hiking paths on an interactive
Leaflet map and stores curated trails in PostgreSQL with PostGIS spatial indexing, so "what can I
walk within 20 km of here?" is a database query rather than a scan.

The whole stack — database, migrations, REST API, Blazor web app — comes up with one
`docker compose up`.

| | |
| --- | --- |
| Runtime | .NET 10 |
| API | ASP.NET Core Minimal APIs |
| Web | Blazor Web App, `InteractiveServer` render mode |
| Maps | Leaflet.js + OpenStreetMap tiles |
| Data | EF Core 10 + Npgsql → PostgreSQL 16 + PostGIS 3.4 |
| External | Nominatim (geocoding), Overpass (trail geometry) |
| Tests | xUnit + FluentAssertions + NSubstitute; bUnit for components |

## 1. Quick start

Gaku reads its configuration from a `.env` file at the repository root. That file is gitignored and
does not exist on a fresh clone — create it first, or `docker compose` and `make` will both fail on
unset variables.

```bash
cat > .env <<'EOF'
POSTGRES_DB=gaku
POSTGRES_USER=gaku
POSTGRES_PASSWORD=change-me

# Used by host-run tools (dotnet run, EF Core CLI). Containers get their own
# connection string from docker-compose.yml, pointing at the postgres service.
ConnectionStrings__DefaultConnection=Host=localhost;Port=5432;Database=gaku;Username=gaku;Password=change-me

# Absolute path to this repo on the host, for bind mounts and patch exchange.
HOST_SYSTEM_REPO=/absolute/path/to/Gaku
EOF

docker compose up --build -d
```

| Service | URL | Health check |
| --- | --- | --- |
| Web | http://localhost:8081 | `/health` |
| API | http://localhost:8080 | `/api/health` |
| API reference | http://localhost:8080/scalar/v1 | development environment only |
| PostgreSQL | `localhost:5432` | `pg_isready` |

`db-migrator` runs EF Core migrations to completion before the API and web containers start, so the
first boot on an empty volume is ordered correctly. The API also seeds sample trails on startup;
seeding failures are logged and swallowed rather than blocking the app.

Tear down with `docker compose down`. The `postgres_data` volume survives, so trail data persists
across restarts.

## 2. Repository layout

```
src/
  Gaku.Domain/          entities, value objects, enums — no dependencies
  Gaku.Application/     DTOs, service interfaces, use cases
  Gaku.Infrastructure/  EF Core, PostGIS queries, OSM HTTP clients
  Gaku.Api/             Minimal API endpoints
  Gaku.Web/             Blazor pages and Leaflet interop
tests/                  one test project per layer except Api
docker/                 one Dockerfile per deployable + docker.mk
infra/k8s/local/        Kustomize manifests for the minikube cluster
jenkins/local/          Jenkins controller + Smee relay, via compose
scripts/                redeploy and benchmark helpers
docs/                   source of truth for the GitHub wiki
```

## 3. Architecture

Clean architecture with the dependency rule enforced by project references — arrows point inward
only:

```
Gaku.Domain
  ▲
  ├── Gaku.Application ◄─────┐
  │     ▲                    │
  └── Gaku.Infrastructure ◄──│
                         Gaku.Api / Gaku.Web
```

`Domain` references nothing. `Application` declares the contracts (`ITrailRepository`,
`IOpenStreetMapService`) that `Infrastructure` implements. `Gaku.Api` and `Gaku.Web` touch
`Infrastructure` in exactly one place each — `Program.cs`, where `AddInfrastructure()` wires up DI.
An Infrastructure namespace imported anywhere else is a layering violation.

Two design decisions carry most of the weight:

**Spatial storage.** The `Coordinates` value object maps to a PostGIS `geography(Point,4326)` column
through an EF Core `HasConversion` to `NetTopologySuite.Geometries.Point`, which keeps NTS types out
of the Domain layer. `TrailRepository.GetNearbyAsync` drops to `FromSqlRaw` with `ST_DWithin` so the
GIST index actually gets used.

**Server-side interactivity.** Every interactive page runs as `InteractiveServer`, so EF Core and
the OSM HTTP clients are available directly in component code — the Blazor app talks to Application
services rather than calling its own REST API over the network. `Gaku.Api` exists for external
consumers.

See [Architecture Overview](../../wiki/Architecture-Overview) and
[Class Diagrams](../../wiki/Class-Diagrams) for the full picture.

## 4. Local development

Run the database in Docker and the apps on the host, which is the fastest edit-debug loop:

```bash
make pg_up                          # postgres only
dotnet run --project src/Gaku.Api   # http://localhost:5000
dotnet run --project src/Gaku.Web   # http://localhost:5001
dotnet test                         # all four test projects
```

Applying migrations against the containerised database:

```bash
dotnet ef database update \
  --project src/Gaku.Infrastructure \
  --startup-project src/Gaku.Api
```

`make local_up` brings up the full local platform instead — Jenkins, minikube, and PostgreSQL
together.

## 5. API

| Method | Route | Purpose |
| --- | --- | --- |
| GET | `/api/trails` | All trails, summary projection |
| GET | `/api/trails/{id}` | Full trail with waypoints |
| GET | `/api/trails/nearby?lat=&lon=&radiusKm=` | `ST_DWithin` radius search |
| GET | `/api/trails/search?q=` | Free-text trail search |
| POST | `/api/trails` | Create |
| PUT | `/api/trails/{id}` | Update |
| DELETE | `/api/trails/{id}` | Delete |
| GET | `/api/map/info?lat=&lon=&zoom=` | Tile URL, bounds, and trails in view |
| GET | `/api/map/locations/search?q=` | Nominatim geocoding passthrough |

Nominatim permits one request per second and requires a descriptive `User-Agent`. The current
implementation does not enforce the rate limit — callers debounce. See
[OSM Integration](../../wiki/OSM-Integration).

## 6. Deployment

Images build from `docker/`, one per deployable:

```bash
make docker_build                   # api, web, migrator
make docker_push IMAGE_TAG=1.2.3    # needs DOCKERHUB_USERNAME + DOCKERHUB_TOKEN in .env
```

The local Kubernetes target is minikube, configured through Kustomize. `infra/k8s/local/.env.k8s`
generates the `gaku-secret` secret and must be created by hand, like the root `.env`:

```bash
make minikube_up
make k8s_apply
make k8s_test                       # five layers: resources, pods, DNS, TCP, ingress
```

`make k8s_test` is the one to reach for when a deploy looks wrong — it walks outward from "do the
objects exist" to "does `gaku.local/api/health` answer through the ingress" and prints a checklist
at each layer.

CI runs on a local Jenkins instance fed by a Smee relay, so GitHub webhooks reach a controller that
has no public address. `make jenkins_up` starts it. The pipeline lives in `Jenkinsfile`.

## 7. Documentation

Long-form documentation lives in `docs/` and publishes to the
[GitHub wiki](../../wiki) automatically — `docs/` is the source of truth, the wiki is the rendered
copy. Edit the files here and open a PR; never edit wiki pages in the browser, since the next
publish overwrites them.

| Page | Source |
| --- | --- |
| [System Context](../../wiki/System-Context) | `docs/solution-architecture.md` |
| [Architecture Overview](../../wiki/Architecture-Overview) | `docs/software-architecture.md` |
| [Class Diagrams](../../wiki/Class-Diagrams) | `docs/class-diagram.md` |
| [Database Schema](../../wiki/Database-Schema) | `docs/database.md` |
| [OSM Integration](../../wiki/OSM-Integration) | `docs/osm-integration.md` |
| [CICD Workflow](../../wiki/CICD-Workflow) | `docs/cicd-workflow-local-first.md` |
| [CICD Roadmap](../../wiki/CICD-Roadmap) | `docs/cicd-plan.md` |

Publishing mechanics, including how to add a page, are in
[§2 Adding a page](docs/wiki/README.md#2-adding-a-page).