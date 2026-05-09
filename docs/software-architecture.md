# Architecture

## Projects Overview

```mermaid
graph TD
  subgraph Hosts["Frontend"]
    direction TB
    API["RestAPI"]
    Web["Web App"]
  end

  subgraph Infra["Gaku.Infrastructure"]
    direction TB
    ContractImp["Contract Implementation"]
    DB["Communication with Repo/DB \n (PostgreSQL, PostGIS, OSM)"]
    OSMSvc["Communication with external Service \n (Nominatim, Overpass)"]
  end

  subgraph App["Gaku.Application"]
    direction TB
    DTOs["DTO"]
    ContractDef["Contract Definition \n Repository & Service"]
    UseCase["Domain Logic Usecase"]
  end

  subgraph Core["Gaku.Core"]
    direction TB
    Entity["Domain Entity"]
    DomainLogic["Domain Logic"]
    ValueObject["Value Object"]
  end

  App -->| | Core
  Infra -->| | App
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
| `Gaku.Web` | Presentation | Browser-facing UI. Renders interactive pages and map components.|
| `Gaku.Api` | Presentation | HTTP entry point. Exposes application use cases as REST endpoints. |
| `Gaku.Infrastructure` | Infrastructure | Fulfils the contracts defined by Application using real technology (database persistence, spatial queries, and external HTTP APIs). No business logic.|


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