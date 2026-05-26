## TrailValidator Placement Advice and Convention Audit

### Where TrailValidator Should Go

`TrailValidator` validates business rules on `Trail` entities before they are persisted. In Clean Architecture, placement depends on whether the validation is self-contained or needs external dependencies:

**Option A — Domain layer (pure invariant validation)**

If the validator checks only structural rules (non-empty name, positive distance, coordinate range, etc.) with no external dependencies, it belongs in:

- **Folder**: `src/Gaku.Domain/Validators/`
- **File**: `src/Gaku.Domain/Validators/TrailValidator.cs`
- **Namespace**: `Gaku.Domain.Validators`

**Option B — Application layer (validation requiring dependencies)**

If the validator needs repository contracts (e.g., uniqueness check across stored trails), it belongs in:

- **Folder**: `src/Gaku.Application/Validators/`
- **File**: `src/Gaku.Application/Validators/TrailValidator.cs`
- **Namespace**: `Gaku.Application.Validators`

**Recommendation**: Start with Domain (Option A). `Trail.Create()` already throws on the most basic invariants inline; `TrailValidator` is the right place for richer or composite rules that return a collection of errors rather than throwing on the first failure. Move to Application only if a repository dependency becomes necessary.

---

### Naming and Folder Convention Audit

**No hard violations found.** Three minor issues:

1. **`Gaku.Domain/Interfaces/` is missing on disk.** CLAUDE.md's project map lists it as a standard folder, but the directory does not exist.

2. **`ITrailService` and `IMapService` live in `Services/` not `Interfaces/`.** The two service interfaces are co-located with their implementations in `Services/`. CLAUDE.md's project map implies all interfaces belong under `Interfaces/`. This is an inconsistency but not a layering violation.

3. **`CreateTrailRequest` and `UpdateTrailRequest` are defined inside `ITrailService.cs` in the `Services/` folder.** These are input DTOs and by convention should live in `Gaku.Application/DTOs/`.

**Layering**: Clean. No class outside `Program.cs` references a `Gaku.Infrastructure` namespace. `Gaku.Api/Program.cs` resolves `Gaku.Infrastructure.Data.DataSeeder` directly from the DI container, which is permitted because it is inside the composition root.
