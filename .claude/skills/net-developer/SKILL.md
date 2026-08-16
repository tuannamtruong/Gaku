---
name: net-developer
description: >
  Implements new features in the Gaku ASP.NET solution end-to-end: domain model,
  application service, infrastructure (EF Core / PostGIS / OSM), API endpoint, and
  Blazor component — always respecting Clean Architecture layering, naming conventions,
  and testability. Use this skill whenever the user asks to add, extend, or change a
  feature, regardless of which layer the request mentions. Also use it when the user
  says "implement", "add support for", "build a feature", "make it so that", or
  describes a new user-facing capability they want in the app.

  After every implementation step this skill verifies with a real build and test run —
  it never assumes the code compiles or tests pass.
---

# net-developer

Implement features in the Gaku ASP.NET solution correctly, safely, and verifiably.

---

## Phase 0 — scope and plan

Before writing any code, understand exactly what needs to change.

1. **Restate the feature** in one sentence: what the user can do after the change that they cannot do now.
2. **Identify which layers are touched.** Every real feature crosses at least two layers. Map it:

   | If you need to…           | Layers involved                                                                |
   | ------------------------- | ------------------------------------------------------------------------------ |
   | Store new data            | Domain → Application → Infrastructure (migration)                              |
   | Expose new API            | Application (interface + service) → Infrastructure (impl) → Api (endpoint)     |
   | New UI capability         | Application → Web (component/page)                                             |
   | Spatial / proximity query | Domain (ValueObject) → Infrastructure (PostGIS via `ST_DWithin`) → Application |
   | Call OSM / Overpass       | Application (interface) → Infrastructure (`OpenStreetMapService`)              |

3. **Decide if the feature is large** (touches ≥ 3 layers, requires a new EF Core migration, or has non-trivial domain logic). If yes, break it into numbered steps — one layer or concern per step — and state them before starting. Implement one step at a time, verify after each, then continue.

4. **Check the existing code** to avoid duplicating what already exists:
   ```bash
   grep -rn "ITrailRepository\|TrailService\|TrailEndpoints" src/ --include="*.cs" -l
   ```

---

## Phase 1 — naming and placement rules

Apply these rules strictly. A wrong name or wrong folder is a bug.

### Naming

| Kind                        | Convention                         | Example                                      |
| --------------------------- | ---------------------------------- | -------------------------------------------- |
| Entity / aggregate root     | Singular PascalCase                | `Trail`, `Location`, `Waypoint`              |
| Value object                | Singular PascalCase                | `Coordinates`, `BoundingBox`                 |
| DTO                         | Singular + `Dto` suffix            | `TrailDto`, `WaypointDto`                    |
| Request/response records    | Verb + noun + `Request`/`Response` | `CreateTrailRequest`, `SearchTrailsResponse` |
| Interface                   | `I` + singular noun                | `ITrailRepository`, `IMapService`            |
| Service (Application)       | Noun + `Service`                   | `TrailService`                               |
| Repository (Infrastructure) | Noun + `Repository`                | `TrailRepository`                            |
| Endpoint class (Api)        | Noun + `Endpoints`                 | `TrailEndpoints`                             |
| Blazor component            | Descriptive PascalCase             | `TrailCard`, `MapView`                       |
| Enum type                   | Singular                           | `DifficultyLevel`, `TrailType`               |
| DB table                    | Singular (EF convention)           | `Trail`, `Waypoint`                          |

### File placement

| What                              | Where                                                                                      |
| --------------------------------- | ------------------------------------------------------------------------------------------ |
| New entity / value object         | `src/Gaku.Domain/Entities/` or `ValueObjects/`                                             |
| New DTO                           | `src/Gaku.Application/DTOs/`                                                               |
| New Application interface         | `src/Gaku.Application/Interfaces/`                                                         |
| New service interface + impl type | Interface in `src/Gaku.Application/Services/`, impl in `src/Gaku.Infrastructure/Services/` |
| New repository interface          | `src/Gaku.Application/Interfaces/`                                                         |
| New repository implementation     | `src/Gaku.Infrastructure/Repositories/`                                                    |
| EF entity config                  | `src/Gaku.Infrastructure/Data/Configurations/`                                             |
| New endpoint                      | `src/Gaku.Api/Endpoints/`                                                                  |
| New Blazor page                   | `src/Gaku.Web/Pages/`                                                                      |
| New Blazor component              | `src/Gaku.Web/Components/`                                                                 |
| New Web service                   | `src/Gaku.Web/Services/`                                                                   |

Request/response record types used by only one interface may be defined in the same file as that interface — this is idiomatic and not a placement violation.

---

## Phase 2 — architecture rules (enforce strictly)

```
Domain ← Application ← Infrastructure
                     ← Api (Program.cs only touches Infrastructure)
                     ← Web (Program.cs only touches Infrastructure)
```

- **Domain** must never reference Application, Infrastructure, Api, or Web.
- **Application** must never reference Infrastructure.
- **Api/Web** files other than `Program.cs` must never import `Gaku.Infrastructure.*`.
- All business logic flows through Application service interfaces — not called directly from pages/endpoints.
- DI registration for Infrastructure types happens only in `Extensions/ServiceCollectionExtensions.cs` (Infrastructure project) called from `Program.cs`.

When in doubt: if you find yourself adding a `using Gaku.Infrastructure` statement outside `Program.cs`, stop — you are violating the architecture.

---

## Phase 3 — EF Core patterns

### Entity configuration

All EF Core mapping goes in `Data/Configurations/<Entity>Configuration.cs`, implementing `IEntityTypeConfiguration<T>`. Never put `[Column]`, `[Table]`, or `HasColumnType` attributes on domain entities.

```csharp
// Infrastructure/Data/Configurations/TrailConfiguration.cs
public class TrailConfiguration : IEntityTypeConfiguration<Trail>
{
    public void Configure(EntityTypeBuilder<Trail> builder)
    {
        builder.ToTable("Trail");
        builder.HasKey(t => t.Id);
        builder.Property(t => t.Name).HasMaxLength(200).IsRequired();
        // ...
    }
}
```

### PostGIS / spatial columns

`Coordinates` (domain value object) converts to `NetTopologySuite.Geometries.Point` via `HasConversion`. Never use NTS types in domain classes.

```csharp
builder.Property(t => t.StartPoint)
    .HasConversion(
        c => new Point(c.Longitude, c.Latitude) { SRID = 4326 },
        p => new Coordinates(p.Y, p.X))
    .HasColumnType("geography(Point,4326)");
```

### Migrations

After changing an entity or adding a new one, generate and apply a migration:

```bash
# From repo root — runs inside the db-migrator container pattern
dotnet ef migrations add <MigrationName> \
  --project src/Gaku.Infrastructure \
  --startup-project src/Gaku.Api \
  --output-dir Data/Migrations
```

Never hand-edit migration files. If a migration looks wrong, remove it and regenerate.

### Unit of Work

Always call `await unitOfWork.SaveChangesAsync()` after repository writes. Never call `_context.SaveChangesAsync()` directly from a service.

---

## Phase 4 — OSM / Overpass patterns

- **Nominatim** is used for geocoding (location search). The interface is `IOpenStreetMapService` in Application; the implementation is in `Infrastructure/Services/OpenStreetMapService.cs`.
- **Overpass API** is used for fetching hiking paths within map bounds.
- Rate limits matter: Nominatim max 1 req/sec; include `User-Agent` header; do not hammer the public Overpass instance.
- New OSM capabilities go through `IOpenStreetMapService`. Add a method to the interface in Application, implement it in Infrastructure.
- Do not call `HttpClient` directly from Application — always inject through the interface.

---

## Phase 5 — testability rules

Write code so that every public method can be tested without a database or HTTP call.

| Layer          | Test project                | Dependencies to mock                                                            |
| -------------- | --------------------------- | ------------------------------------------------------------------------------- |
| Domain         | `Gaku.Domain.Tests`         | None — pure logic, no mocks needed                                              |
| Application    | `Gaku.Application.Tests`    | Mock `ITrailRepository`, `IUnitOfWork`, `IOpenStreetMapService` via NSubstitute |
| Infrastructure | `Gaku.Infrastructure.Tests` | Mock `HttpClient` factory or use `HttpMessageHandler` test doubles              |
| Web            | `Gaku.Web.Tests`            | Mock Application service interfaces via NSubstitute; render with bUnit          |

**Design for testability:**

- Inject all dependencies through constructor parameters (primary constructor syntax preferred).
- No `static` mutable state.
- No `new` inside business logic — create domain objects via factory methods (`Trail.Create(…)`).
- Keep Application services thin: fetch → mutate via domain method → persist.

---

## Phase 6 — writing tests

Write tests in the same turn as the feature code. Do not defer.

### Test structure (xUnit + FluentAssertions + NSubstitute)

```csharp
public class <EntityOrService>Tests
{
    // Arrange shared state in the constructor
    private readonly IMockDependency _dep = Substitute.For<IMockDependency>();
    private readonly SubjectUnderTest _sut;

    public <EntityOrService>Tests() => _sut = new SubjectUnderTest(_dep);

    [Fact]
    public async Task MethodName_Scenario_ExpectedOutcome()
    {
        // Arrange
        _dep.SomeMethod(Arg.Any<…>()).Returns(…);

        // Act
        var result = await _sut.MethodName(…);

        // Assert
        result.Should().Be(…);
        await _dep.Received(1).SomeMethod(Arg.Any<…>());
    }
}
```

**Test naming**: `MethodName_Scenario_ExpectedOutcome` — always three parts.

**What to cover per feature:**

- Happy path: valid input returns expected output and persists correctly.
- Not-found path: missing entity returns null or throws `KeyNotFoundException`.
- Validation edge cases: invalid coordinates, empty names, negative distances.
- If OSM is involved: mock the interface; test both successful response and empty/failed response.
- Domain logic: test entity factory methods and state transitions directly without mocks.

---

## Phase 7 — verify (mandatory, no exceptions)

Never report a feature as done without running these. If any command fails, fix the issue before moving on.

### Build verification

```bash
dotnet build Gaku.sln
```

Expected: `Build succeeded. 0 Error(s)`. Any error must be fixed.

### Test verification

```bash
dotnet test Gaku.sln --no-build
```

Expected: all tests pass. A red test is a bug in the implementation.

### Quick functional check (when the cluster is running)

After confirming the build and tests pass, give the user the specific command to manually verify the feature. Choose the appropriate command for what was built:

**New API endpoint:**

```bash
# Replace with the actual route and parameters
curl -s http://localhost:8080/<route> | jq .
```

**Database change (new migration applied):**

```bash
kubectl logs $(kubectl get pod -n gaku -l job-name=db-migrate -o name) -n gaku | tail -20
```

**New Blazor page or component:**

```
Open http://localhost:8081/<path> in a browser.
```

**OSM / Overpass integration:**

```bash
curl -s "http://localhost:8080/<endpoint>?<params>" | jq '.[] | .name'
```

If the cluster is not running, state clearly what the user needs to do to start it and which URL to open.

---

## Phase 8 — step-by-step protocol for large features

When a feature is large (identified in Phase 0), implement one step at a time using this protocol:

```
Step N of M: <what this step does>
Layer: <which layer>
Files changed: <list>

[implementation]

Verification:
  dotnet build → [result]
  dotnet test  → [result]

Ready for step N+1.
```

Do not proceed to the next step if verification fails.

---

## Common patterns reference

### Adding a new field to an existing entity

1. Add the property to the Domain entity (with appropriate validation in the constructor or factory method).
2. Add a migration: `dotnet ef migrations add Add<Field>To<Entity>`.
3. Add the field to the DTO in Application.
4. Update the mapping in the Application service (`ToDto` / `ToSummaryDto`).
5. Update the endpoint or component as needed.
6. Add a test for the new mapping and any domain validation.

### Adding a new repository method

1. Add the method signature to `ITrailRepository` (or the relevant interface) in Application.
2. Implement it in `TrailRepository` in Infrastructure.
3. If the query uses PostGIS, use `FromSqlRaw` with parameterised `ST_DWithin` — never string-interpolate user input into SQL.
4. Unit-test the Application service that calls the new method (mock the repository).
5. Integration-test the repository implementation separately if the SQL is complex.

### Adding a new OSM capability

1. Add the method to `IOpenStreetMapService` in Application.
2. Implement in `Infrastructure/Services/OpenStreetMapService.cs`.
3. Respect rate limits: add a `Task.Delay(1000)` guard for Nominatim calls; batch Overpass queries where possible.
4. Mock the interface in Application tests; use a `HttpMessageHandler` test double in Infrastructure tests.

### Adding a new Blazor page

1. Create the `.razor` file in `src/Gaku.Web/Pages/`.
2. Add `@rendermode InteractiveServer` at the top.
3. Inject the Application service interface (not Infrastructure).
4. Write a bUnit test in `tests/Gaku.Web.Tests/` that mocks the service and verifies rendered markup.
