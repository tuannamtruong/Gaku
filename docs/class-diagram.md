# Class Diagrams — Gaku

One diagram per project. Each project is the focal point — its own classes are shown in full detail.
External project dependencies appear as a single `<<package>>` node; arrows from internal classes point to that package, not to individual external classes.

---

## 1. Gaku.Core

No external project dependencies — innermost layer.

```mermaid
classDiagram
    namespace Entities {
        class Trail {
            +Guid Id
            +string Name
            +string Description
            +DifficultyLevel Difficulty
            +double DistanceKm
            +int ElevationGainMeters
            +Coordinates StartPoint
            +Coordinates EndPoint
            +string Country
            +string Region
            +TrailType Type
            +DateTime CreatedAt
            +DateTime? UpdatedAt
            +List~string~ Tags
            +IReadOnlyList~Waypoint~ Waypoints
            +Create(...)$ Trail
            +AddWaypoint(Waypoint) void
            +AddTag(string) void
            +Update(...) void
        }
        class Waypoint {
            +Guid Id
            +string Name
            +Coordinates Location
            +double? ElevationMeters
            +string? Description
            +int Order
            +Guid TrailId
            +Create(...)$ Waypoint
        }
        class Location {
            +Guid Id
            +string Name
            +string Country
            +string? Region
            +Coordinates Center
            +long? OsmId
            +string? OsmType
            +Create(...)$ Location
        }
    }

    namespace Interfaces {
        class IUnitOfWork {
            <<interface>>
            +SaveChangesAsync(CancellationToken) Task~int~
        }
        class ITrailRepository {
            <<interface>>
            +GetByIdAsync(Guid, CancellationToken) Task~Trail~
            +GetAllAsync(CancellationToken) Task~IReadOnlyList~Trail~~
            +GetNearbyAsync(Coordinates, double, CancellationToken) Task~IReadOnlyList~Trail~~
            +SearchAsync(string, CancellationToken) Task~IReadOnlyList~Trail~~
            +AddAsync(Trail, CancellationToken) Task
            +UpdateAsync(Trail, CancellationToken) Task
            +DeleteAsync(Guid, CancellationToken) Task
        }
        class IOpenStreetMapService {
            <<interface>>
            +GetMapInfoAsync(Coordinates, int, CancellationToken) Task~MapInfo~
            +SearchLocationsAsync(string, CancellationToken) Task~IReadOnlyList~NominatimResult~~
            +GetTrailsInBoundsAsync(BoundingBox, CancellationToken) Task~IReadOnlyList~OsmTrailData~~
        }
    }

    Trail "1" *-- "0..*" Waypoint
    ITrailRepository ..> Trail : manages
```

---

## 2. Gaku.Application

```mermaid
classDiagram
    namespace Services {
        class ITrailService {
            <<interface>>
            +GetByIdAsync(Guid, CancellationToken) Task~TrailDto~
            +GetAllAsync(CancellationToken) Task~IReadOnlyList~TrailSummaryDto~~
            +GetNearbyAsync(double, double, double, CancellationToken) Task~IReadOnlyList~TrailSummaryDto~~
            +SearchAsync(string, CancellationToken) Task~IReadOnlyList~TrailSummaryDto~~
            +CreateAsync(CreateTrailRequest, CancellationToken) Task~TrailDto~
            +UpdateAsync(Guid, UpdateTrailRequest, CancellationToken) Task
            +DeleteAsync(Guid, CancellationToken) Task
        }
        class TrailService {
            -ITrailRepository _repository
            -IUnitOfWork _unitOfWork
            +GetByIdAsync(Guid, CancellationToken) Task~TrailDto~
            +GetAllAsync(CancellationToken) Task~IReadOnlyList~TrailSummaryDto~~
            +GetNearbyAsync(double, double, double, CancellationToken) Task~IReadOnlyList~TrailSummaryDto~~
            +SearchAsync(string, CancellationToken) Task~IReadOnlyList~TrailSummaryDto~~
            +CreateAsync(CreateTrailRequest, CancellationToken) Task~TrailDto~
            +UpdateAsync(Guid, UpdateTrailRequest, CancellationToken) Task
            +DeleteAsync(Guid, CancellationToken) Task
        }
        class IMapService {
            <<interface>>
            +GetMapInfoAsync(double, double, int, CancellationToken) Task~MapInfoDto~
            +SearchLocationsAsync(string, CancellationToken) Task~IReadOnlyList~LocationDto~~
        }
        class MapService {
            -IOpenStreetMapService _osmService
            +GetMapInfoAsync(double, double, int, CancellationToken) Task~MapInfoDto~
            +SearchLocationsAsync(string, CancellationToken) Task~IReadOnlyList~LocationDto~~
        }
    }

    class GakuCore["Gaku.Core"] {
        <<package>>
        ITrailRepository
        IUnitOfWork
        IOpenStreetMapService
    }

    TrailService ..|> ITrailService
    MapService ..|> IMapService

    TrailService --> GakuCore : ITrailRepository · IUnitOfWork
    MapService --> GakuCore : IOpenStreetMapService
```

---

## 3. Gaku.Infrastructure

```mermaid
classDiagram
    namespace Data {
        class GakuDbContext {
            +DbSet~Trail~ Trails
            +DbSet~Waypoint~ Waypoints
            +DbSet~Location~ Locations
            #OnModelCreating(ModelBuilder) void
            +SaveChangesAsync(CancellationToken) Task~int~
        }
        class TrailConfiguration {
            +Configure(EntityTypeBuilder~Trail~) void
        }
        class WaypointConfiguration {
            +Configure(EntityTypeBuilder~Waypoint~) void
        }
        class LocationConfiguration {
            +Configure(EntityTypeBuilder~Location~) void
        }
    }

    namespace Repositories {
        class TrailRepository {
            -GakuDbContext _context
            +GetByIdAsync(Guid, CancellationToken) Task~Trail~
            +GetAllAsync(CancellationToken) Task~IReadOnlyList~Trail~~
            +GetNearbyAsync(Coordinates, double, CancellationToken) Task~IReadOnlyList~Trail~~
            +SearchAsync(string, CancellationToken) Task~IReadOnlyList~Trail~~
            +AddAsync(Trail, CancellationToken) Task
            +UpdateAsync(Trail, CancellationToken) Task
            +DeleteAsync(Guid, CancellationToken) Task
        }
    }

    namespace ExternalServices {
        class OpenStreetMapService {
            -IHttpClientFactory _httpClientFactory
            -ILogger _logger
            +GetMapInfoAsync(Coordinates, int, CancellationToken) Task~MapInfo~
            +SearchLocationsAsync(string, CancellationToken) Task~IReadOnlyList~NominatimResult~~
            +GetTrailsInBoundsAsync(BoundingBox, CancellationToken) Task~IReadOnlyList~OsmTrailData~~
            -ParseOverpassElements(OverpassResponse) IReadOnlyList~OsmTrailData~
            -ComputeBounds(Coordinates, int) BoundingBox
        }
        class HttpClientNames {
            <<static>>
            +Nominatim$ string
            +Overpass$ string
        }
    }

    class GakuCore["Gaku.Core"] {
        <<package>>
        ITrailRepository · IUnitOfWork
        IOpenStreetMapService
        Trail · Waypoint · Location
    }

    TrailRepository --> GakuDbContext : uses
    TrailConfiguration --> GakuDbContext : applied by
    WaypointConfiguration --> GakuDbContext : applied by
    LocationConfiguration --> GakuDbContext : applied by

    GakuDbContext --> GakuCore : implements IUnitOfWork · stores Trail/Waypoint/Location
    TrailRepository --> GakuCore : implements ITrailRepository · uses Trail
    OpenStreetMapService --> GakuCore : implements IOpenStreetMapService
    TrailConfiguration --> GakuCore : configures Trail entity
    WaypointConfiguration --> GakuCore : configures Waypoint entity
    LocationConfiguration --> GakuCore : configures Location entity
```
