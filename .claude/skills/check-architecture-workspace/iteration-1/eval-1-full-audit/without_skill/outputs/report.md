# Gaku Architecture Audit Report

## Summary

The Gaku solution largely follows Clean Architecture principles. The core dependency rule — outer layers depend on inner layers, never the reverse — is enforced at the project reference level. No critical layer violations were found. However, several lower-severity structural issues were identified.

---

## Project Dependency Graph (from .csproj files)

```
Gaku.Domain
  (no project references — correct)

Gaku.Application
  -> Gaku.Domain (correct)

Gaku.Infrastructure
  -> Gaku.Domain (correct)
  -> Gaku.Application (correct)

Gaku.Api
  -> Gaku.Application (correct)
  -> Gaku.Infrastructure (acceptable — composition root)

Gaku.Web
  -> Gaku.Application (correct)
  -> Gaku.Infrastructure (acceptable — composition root)
```

---

## Layer Violations

**PASS: Domain layer is clean.**
Gaku.Domain references no other Gaku project. All source files use only Gaku.Domain.\* namespaces.

**PASS: Application layer is clean.**
Gaku.Application does not reference Infrastructure, Api, or Web types anywhere.

**PASS: Infrastructure namespace not used outside composition roots.**
No file in Gaku.Api/Endpoints/, Gaku.Web/Pages/, Gaku.Web/Components/, or Gaku.Web/Services/ imports Gaku.Infrastructure._. The only using Gaku.Infrastructure._ directives are in the two Program.cs files, which is explicitly permitted.

**PASS: Razor components use Application interfaces only.**
\_Imports.razor imports only Gaku.Application.DTOs and Gaku.Application.Services. No Razor file references Infrastructure types.

---

## Structural Issues (Non-Critical)

### Issue 1 — Direct Infrastructure concrete type resolved in Gaku.Api/Program.cs

**File:** src/Gaku.Api/Program.cs, line 22

DataSeeder is a concrete Infrastructure class referenced by name in Program.cs. A cleaner approach: define IDataSeeder in Gaku.Application.Interfaces, register the concrete against it inside AddInfrastructure(), and resolve IDataSeeder in Program.cs.

**Severity:** Minor / borderline — still inside Program.cs.

### Issue 2 — Service interfaces colocated with implementations in Application/Services/

**Files:** src/Gaku.Application/Services/IMapService.cs, src/Gaku.Application/Services/ITrailService.cs

IMapService and ITrailService live in Application/Services/ alongside their concrete implementations. The Interfaces/ folder correctly holds ITrailRepository, IUnitOfWork, and IOpenStreetMapService.

**Severity:** Minor — placement inconsistency, not a dependency-direction violation.

### Issue 3 — Plural folder names diverge from documented naming convention

CLAUDE.md states C# folders should be singular. Every folder in the codebase uses the plural form (Entities/, Enums/, ValueObjects/, DTOs/, Interfaces/, Services/, etc.).

**Severity:** Low — documentation inaccuracy; no functional impact.

### Issue 4 — Domain Interfaces/ folder listed in project map but does not exist on disk

CLAUDE.md shows Gaku.Domain/Interfaces/ as a subdirectory, but it does not exist.

**Severity:** Documentation only.

### Issue 5 — HttpClientNames helper class nested inside OpenStreetMapService.cs

HttpClientNames is defined at file scope but used in both that file and ServiceCollectionExtensions.cs.

**Severity:** Code quality / minor structural.

### Issue 6 — Empty Infrastructure/Cache/ folder

The Cache/ folder exists but contains no files.

**Severity:** Informational.

---

## Conclusion

| Check                                                 | Result                                                            |
| ----------------------------------------------------- | ----------------------------------------------------------------- |
| Domain depends on nothing external                    | PASS                                                              |
| Application does not depend on Infrastructure/Api/Web | PASS                                                              |
| Infrastructure does not depend on Api/Web             | PASS                                                              |
| Api/Web only reference Infrastructure in Program.cs   | PASS (minor: DataSeeder concrete type resolved directly)          |
| No Razor component imports Infrastructure             | PASS                                                              |
| Naming conventions (folders singular per CLAUDE.md)   | FAIL — entire codebase uses plural folder names                   |
| Service interfaces in Application/Interfaces/         | FAIL — IMapService and ITrailService are in Application/Services/ |
| Domain Interfaces/ folder exists per project map      | FAIL — folder absent from disk                                    |

**No critical architecture violations detected.** The dependency rule is correctly enforced at every layer boundary. All identified issues are naming/structural inconsistencies of minor severity.
