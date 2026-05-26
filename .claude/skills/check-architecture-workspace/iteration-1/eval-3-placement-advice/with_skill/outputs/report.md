## Architecture Validation Report

### Placement Recommendation: TrailValidator

`TrailValidator` validates business rules on `Trail` entities — this is pure application-layer logic (a workflow step), not a domain-layer concern. It belongs in **`Gaku.Application/Services/`** as a concrete implementation, with a corresponding interface `ITrailValidator` in **`Gaku.Application/Interfaces/`**.

**Rationale:** Validation of business invariants before persistence is exercised by `TrailService` before calling `ITrailRepository.AddAsync` — that lifecycle belongs to the Application layer. It must not go in `Gaku.Domain` (that layer has no persistence lifecycle concept). It must not go in `Gaku.Infrastructure` (no EF Core or external services are needed).

Concrete placement:

- `src/Gaku.Application/Services/TrailValidator.cs` — class `TrailValidator : ITrailValidator`
- `src/Gaku.Application/Interfaces/ITrailValidator.cs` — interface `ITrailValidator`

Register both in `src/Gaku.Application/Extensions/ServiceCollectionExtensions.cs`.

---

### Summary

- Projects checked: 5
- Files scanned: 49 (41 .cs + 8 .razor)
- VIOLATIONS: 1
- WARNINGS: 2

---

### Violations (must fix)

❌ [CHECK-4] Interface files misplaced in Services/ folder
File: `src/Gaku.Application/Services/IMapService.cs`
`src/Gaku.Application/Services/ITrailService.cs`
Rule: Folder placement — `Gaku.Application` interface files must live in `Interfaces/`, not `Services/`
Detail: Both `IMapService` and `ITrailService` are interface declarations but reside in `Services/`. The architecture map specifies that `Gaku.Application` separates contracts (`Interfaces/`) from implementations (`Services/`).

---

### Warnings (review recommended)

⚠️ [CHECK-3] Plural class name `HttpClientNames`
File: `src/Gaku.Infrastructure/Services/OpenStreetMapService.cs` (line 161)
Rule: Naming conventions — class names should be singular
Detail: `HttpClientNames` is a static constants-holder class whose name ends in `s`. This is a common .NET idiom for grouped string constants and may be intentional, but it deviates from the singular-name rule.

⚠️ [CHECK-4] `Gaku.Domain` is missing its `Interfaces/` subfolder
File: `src/Gaku.Domain/` (directory)
Rule: Folder placement — expected subfolders for `Gaku.Domain` include `Interfaces/`
Detail: The project map in CLAUDE.md lists `Interfaces/` as an expected subfolder of `Gaku.Domain`, but no such directory exists on disk.

---

### Healthy (passing checks)

✅ Project references — all edges conform to the dependency rules
✅ Namespace imports — no forbidden `using Gaku.*` statements found
✅ Naming conventions — all checked names follow the rules (entities, DTOs, value objects, enums, interfaces are all singular with I prefix)
