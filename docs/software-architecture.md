# Architecture

## Projects Overview

```mermaid
graph TD
  subgraph Hosts["Frontend"]
    direction LR
    API["API · Scalar"]
    Web["Web Blazor InteractiveServer"]
  end

  subgraph Infra["Gaku.Infrastructure"]
    direction TB
    DB["EF Core + PostGIS"]
    Repo["ST_DWithin spatial queries"]
    OSMSvc["Nominatim + Overpass"]
  end

  subgraph App["Gaku.Application"]
    direction TB
    TrailSvc["TrailService"]
    MapSvc["MapService"]
    DTOs["DTOs"]
  end

  subgraph Core["Gaku.Core"]
    direction TB
    Entity["Hiking Domain Entity \nTrail&nbsp;·&nbsp;Waypoint&nbsp;·&nbsp;Location"]
    ValueObject["Value Object \n Coordinates"]
    Inf["ITrailRepository · IOpenStreetMapService · IUnitOfWork"]
  end

  App -->| | Core
  Infra -->| | Core
  Hosts -->| | App
  Hosts -->| | Infra

  style Core fill:#d4edda,stroke:#28a745
  style App fill:#d1ecf1,stroke:#17a2b8
  style Infra fill:#fff3cd,stroke:#ffc107
  style Hosts fill:#f8d7da,stroke:#dc3545
```

| Project | Layer | Responsibility |
|---|---|---|
| `Gaku.Domain` | Domain | Business rules and data shapes. Defines entities (`Trail`, `Waypoint`, `Location`), value objects (`Coordinates`), enums, and repository/unit-of-work interfaces. |
| `Gaku.Application` | Application | Defines what the application can do (trail management and map exploration). Orchestrates domain logic to fulfil use cases, and declares contracts for external services that Infrastructure must satisfy. |
| `Gaku.Infrastructure` | Infrastructure | Fulfils the contracts defined by Application using real technology (database persistence, spatial queries, and external HTTP APIs). No business logic.|
| `Gaku.Api` | Presentation | HTTP entry point. Exposes application use cases as REST endpoints and translates between HTTP requests/responses and Application service calls. |
| `Gaku.Web` | Presentation | Browser-facing UI. Renders interactive pages and map components, calls Application services directly (same process), and bridges to JavaScript for map rendering.|

---


## System Context - Gaku

```mermaid
C4Context

  Person(hiker, "Hiker", "Discovers and navigates European hiking trails")
  System(gaku, "Gaku", "ASP.NET Core 10 web app for hiking in Europe")
  SystemDb_Ext(postgres, "PostgreSQL + PostGIS", "Stores trails, waypoints, locations with spatial indexing")
  System_Ext(osm_tiles, "OSM Tile Server", "Serves raster map tiles to the browser")
  System_Ext(nominatim, "Nominatim", "Free geocoding and location search (OSM data)")
  System_Ext(overpass, "Overpass API", "Queries hiking paths and trails from OSM data")

  Rel(hiker, gaku, "Browses trails, searches locations, views map")
  Rel(gaku, postgres, "Reads/writes trail data", "EF Core / Npgsql")
  Rel(gaku, nominatim, "Searches locations by name", "HTTPS / JSON")
  Rel(gaku, overpass, "Fetches hiking paths in viewport", "HTTPS / OverpassQL")
  Rel(gaku, osm_tiles, "Serves map tiles to browser", "HTTPS (Leaflet)")
```

---


## Containers — runtime components and communication

```mermaid
graph LR
  Browser["(Hiker)"]

  subgraph GakuSystem["Gaku"]
    Web["Web App:5001  InteractiveServer"]
    API["REST API:5000  Minimal API"]
  end

  subgraph Data["Data"]
    PG[("PostgreSQL + PostGIS :5432")]
  end

  subgraph OSM["OpenStreetMap"]
    Tiles["OSM Tile Server"]
    Nom["Nominatim"]
    Over["Overpass API"]
  end

  Browser -->|"Blazor SignalR / HTTPS"| Web
  Browser -->|"Leaflet tile requests"| Tiles
  Web -->|"direct service calls\nsame process"| API
  API -->|"EF Core / Npgsql"| PG
  API -->|"HTTPS"| Nom
  API -->|"HTTPS"| Over
```

---


## Map Load Sequence — request flow when a hiker opens the map

```mermaid
sequenceDiagram
  actor Hiker
  participant Blazor as Blazor Web (Server)
  participant MapSvc as MapService
  participant OSMSvc as OpenStreetMapService
  participant Overpass
  participant JS as leaflet-interop.js

  Hiker->>Blazor: Navigate to "/"
  Blazor->>MapSvc: GetMapInfoAsync(46.8, 8.2, zoom=7)
  MapSvc->>OSMSvc: GetMapInfoAsync(center, zoom)
  OSMSvc-->>MapSvc: MapInfo { tileUrl, bounds }
  MapSvc->>OSMSvc: GetTrailsInBoundsAsync(bounds)
  OSMSvc->>Overpass: POST /api/interpreter (OverpassQL)
  Overpass-->>OSMSvc: nodes + ways JSON
  OSMSvc-->>MapSvc: [OsmTrailData]
  MapSvc-->>Blazor: MapInfoDto { center, tileUrl, nearbyTrails }
  Blazor->>JS: initMap(elementId, lat, lon, zoom)
  Blazor->>JS: renderTrails(elementId, trails)
  JS-->>Hiker: Interactive map with colour-coded trail overlays
```