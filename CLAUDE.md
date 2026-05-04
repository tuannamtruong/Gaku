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

## Architecture — Onion

```
Gaku.Core
  ├── Gaku.Application
  └── Gaku.Infrastructure
```


## Project Map

```
src/
  Gaku.Core/
    Entities/        Trail, Waypoint, Location  (aggregate roots + children)
    Enums/           DifficultyLevel, TrailType
    Interfaces/      ITrailRepository, IOpenStreetMapService, IUnitOfWork
    ValueObjects/    Coordinates  (pure record, haversine helper)
  Gaku.Application/
    DTOs/            TrailDto, MapInfoDto, LocationDto, …
    Services/        ITrailService / TrailService
                     IMapService   / MapService
    Extensions/      ServiceCollectionExtensions (AddApplication)
  Gaku.Infrastructure/
    Data/            GakuDbContext (also implements IUnitOfWork)
    Data/Configurations/  EF IEntityTypeConfiguration per entity
    Repositories/    TrailRepository  (PostGIS ST_DWithin for nearby)
    Services/        OpenStreetMapService (Nominatim + Overpass API)
    Extensions/      ServiceCollectionExtensions (AddInfrastructure)
tests/
  Gaku.Core.Tests/         Entity + value-object unit tests
  Gaku.Application.Tests/  Service tests with NSubstitute fakes
  Gaku.Infrastructure.Tests/ OSM service tests with MockHttp
```

## Architecture Diagrams

> See [docs/architecture.md](docs/architecture.md) for rendered C4, onion, container, ER, and sequence diagrams.
> See [docs/class-diagram.md](docs/class-diagram.md) for per-project class diagrams.

**Class diagram rule**: when creating or updating class diagrams, exclude enums, value objects, and record types — show only classes and interfaces.

---

## Naming Conventions

- **Entities, DTOs, value objects**: singular — `Trail`, `TrailDto`, `Coordinates`
- **C# folders**: singular — `Entity/`, `ValueObject/`, `Endpoint/`, `Repository/`, `Service/`
- **Interfaces**: `I` prefix + singular noun — `ITrailRepository`, `IUnitOfWork`
- **DB tables**: singular — `Trail`, `Waypoint`, `Location` (EF default; do not pluralise)
- **Enums**: singular type name, plural only for `[Flags]` — `DifficultyLevel`, `TrailType`

## Key Design Decisions

### PostGIS spatial storage
`Coordinates` (domain value object) is mapped to a PostGIS `geography(Point,4326)` column via an EF Core `HasConversion` to `NetTopologySuite.Geometries.Point`. This keeps the Core layer free of NTS types.  
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
