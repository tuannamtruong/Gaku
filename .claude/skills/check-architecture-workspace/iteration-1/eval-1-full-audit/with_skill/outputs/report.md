## Architecture Validation Report

### Summary

- Projects checked: 5 (Gaku.Domain, Gaku.Application, Gaku.Infrastructure, Gaku.Api, Gaku.Web)
- Files scanned: 41
- **VIOLATIONS: 3**
- WARNINGS: 2

---

### Violations (must fix)

❌ [CHECK-4] Interface files in wrong folder — IMapService.cs
File: `src/Gaku.Application/Services/IMapService.cs`
Rule: Application interfaces must live in `Interfaces/`, not `Services/`
Detail: `IMapService` is an interface declaration (`public interface IMapService`) but is placed in the `Services/` subfolder; the expected location per the folder-placement rules is `Gaku.Application/Interfaces/`.

❌ [CHECK-4] Interface files in wrong folder — ITrailService.cs
File: `src/Gaku.Application/Services/ITrailService.cs`
Rule: Application interfaces must live in `Interfaces/`, not `Services/`
Detail: `ITrailService` is an interface declaration but is placed in `Services/`; it should be in `Gaku.Application/Interfaces/`.

❌ [CHECK-4] Request record types placed outside DTOs folder
File: `src/Gaku.Application/Services/ITrailService.cs`
Rule: DTO/request types must live in `DTOs/`
Detail: `CreateTrailRequest` and `UpdateTrailRequest` are request/DTO records co-located with `ITrailService` in `Services/`; they belong in `Gaku.Application/DTOs/`.

---

### Warnings (review recommended)

⚠️ [CHECK-4] Domain has no Interfaces/ subfolder
File: `src/Gaku.Domain/` (folder missing)
Rule: Expected Domain subfolders include `Interfaces/`
Detail: The folder-placement rules list `Interfaces/` as an expected subfolder of `Gaku.Domain`, but no such folder (or any domain interface files) exists. If no domain interfaces are needed this is fine, but it is worth confirming intentionally.

⚠️ [CHECK-4] Infrastructure Cache/ folder is empty
File: `src/Gaku.Infrastructure/Cache/` (no .cs files)
Rule: Expected Infrastructure subfolders include `Cache/`
Detail: The `Cache/` subfolder exists but contains no source files. This may be scaffolding left over from an earlier plan; either populate it or remove it to avoid confusion.

---

### Healthy (passing checks)

✅ Project references — all edges conform to the dependency rules

- Gaku.Domain references nothing
- Gaku.Application references only Domain
- Gaku.Infrastructure references Domain and Application
- Gaku.Api references Application and Infrastructure
- Gaku.Web references Application and Infrastructure

✅ Namespace imports — no forbidden using statements found

- No Domain file imports Application or Infrastructure namespaces
- No Application file imports Infrastructure namespaces
- No Api file outside Program.cs imports Infrastructure namespaces
- No Web file outside Program.cs imports Infrastructure namespaces
- Program.cs files in Api and Web correctly confine Infrastructure references to the composition root

✅ Naming conventions — all checked names follow the rules

- All interfaces carry the `I` prefix (ITrailRepository, IUnitOfWork, IOpenStreetMapService, ITrailService, IMapService)
- All entity, DTO, value-object, and enum names are singular (Trail, TrailDto, Coordinates, DifficultyLevel, TrailType)
- No plural class or enum names detected

---

Fix the three violations by moving `IMapService.cs` and `ITrailService.cs` from `Gaku.Application/Services/` into `Gaku.Application/Interfaces/`, and extracting `CreateTrailRequest` and `UpdateTrailRequest` from `ITrailService.cs` into a dedicated file under `Gaku.Application/DTOs/` (e.g., `TrailRequests.cs`). These changes matter because the `Interfaces/` folder is the declared contract boundary of the Application layer — mixing interface declarations with concrete service implementations in `Services/` blurs that boundary and makes it harder for contributors (and tooling) to locate capability contracts at a glance. The Api endpoints already import `Gaku.Application.Services` to resolve `ITrailService` and `IMapService`; after the move, those `using` statements would become `using Gaku.Application.Interfaces`, which correctly signals that the endpoint depends only on an abstract contract.
