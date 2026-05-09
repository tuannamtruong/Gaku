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
| `Gaku.Application` | Application | Defines what the application can do (trail management and map exploration). Orchestrates domain logic to fulfil use cases and declares all contracts that Infrastructure must satisfy. |
| `Gaku.Domain` | Domain | Pure business model. Defines domain entities (`Trail`, `Waypoint`, `Location`), domain logic, value objects (`Coordinates`), and enums. No persistence or infrastructure concerns. |

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