---
name: check-architecture
description: >
  Validates the clean architecture rules of the Gaku .NET solution. Only invoke this skill
  when the user explicitly calls /check-architecture, or when another skill or subagent
  explicitly names it. Do NOT auto-trigger on general architecture questions.
---

# check-architecture

Validate the clean architecture rules of the Gaku .NET solution. Produce a clear report
of violations and a summary of what's healthy.

## Architecture rules

### 1. Project-level dependency edges (`.csproj` `<ProjectReference>`)

| Project               | MAY reference               | MUST NOT reference                    |
| --------------------- | --------------------------- | ------------------------------------- |
| `Gaku.Domain`         | _(nothing)_                 | Application, Infrastructure, Api, Web |
| `Gaku.Application`    | Domain                      | Infrastructure, Api, Web              |
| `Gaku.Infrastructure` | Domain, Application         | Api, Web                              |
| `Gaku.Api`            | Application, Infrastructure | Web                                   |
| `Gaku.Web`            | Application, Infrastructure | Api                                   |

### 2. Namespace import rules (C# `using` statements inside `.cs` files)

These rules apply to _runtime imports_ — transitive project references do not
override them. Check `using Gaku.<Layer>` statements (or fully-qualified names inside
method bodies).

| Source file location              | MUST NOT import                           |
| --------------------------------- | ----------------------------------------- |
| `Gaku.Domain/**`                  | `Gaku.Application`, `Gaku.Infrastructure` |
| `Gaku.Application/**`             | `Gaku.Infrastructure`                     |
| `Gaku.Api/**` except `Program.cs` | `Gaku.Infrastructure`                     |
| `Gaku.Web/**` except `Program.cs` | `Gaku.Infrastructure`                     |

`Program.cs` is the composition root — Infrastructure references there are intentional
and must be skipped.

### 3. Folder placement

Files must live in the folder that matches their kind:

| Project               | Expected subfolders                                                                                   |
| --------------------- | ----------------------------------------------------------------------------------------------------- |
| `Gaku.Domain`         | `Entities/`, `Enums/`, `Interfaces/`, `ValueObjects/`                                                 |
| `Gaku.Application`    | `DTOs/`, `Interfaces/`, `Services/`, `Extensions/`                                                    |
| `Gaku.Infrastructure` | `Cache/`, `Data/`, `Data/Configurations/`, `Migrations/`, `Repositories/`, `Services/`, `Extensions/` |
| `Gaku.Api`            | `Endpoints/`                                                                                          |
| `Gaku.Web`            | `Components/`, `Components/Layout/`, `Components/Map/`, `Pages/`, `Services/`, `wwwroot/`             |

Flag any `.cs` file that does not sit under one of its project's expected folders
(ignoring `Program.cs`, `App.razor`, auto-generated files, and `obj/` output).

**Acceptable co-location**: request/response record types defined in the same file as
the interface that uses them (e.g. `CreateTrailRequest` inside `ITrailService.cs`) are
not a violation — this is a standard .NET idiom. Do not flag them separately.

---

## How to run the validation

Use shell tools (`find`, `grep`, `cat`) — do not build or run the project.

Work through each check in order. After every check, accumulate findings into one of
two lists:

- **VIOLATIONS** — broken rules that must be fixed
- **WARNINGS** — suspicious patterns that deserve a human look

### Check 1 — project references

For each `.csproj` in `src/`, extract `<ProjectReference>` elements and verify against
the allowed-edges table. A reference to a project in the MUST NOT column is a
**violation**.

```bash
grep -h "ProjectReference" src/**/*.csproj
```

### Check 2 — namespace imports

For each project, find all `.cs` files (excluding `Program.cs`), then grep for
forbidden `using Gaku.*` patterns. A match is a **violation**.

```bash
# Example: Application files must not import Infrastructure
find src/Gaku.Application -name "*.cs" \
  | xargs grep -l "using Gaku\.Infrastructure"
```

Also check for fully-qualified references inside method bodies (e.g.
`Gaku.Infrastructure.Data.GakuDbContext` used directly rather than via `using`).

### Check 3 — folder placement

For each project, list all `.cs` files and check that each one's path starts with one
of the expected subfolders. Files sitting directly at the project root (other than
`Program.cs` and `GlobalUsings.cs`) are a **warning**. Files in an unexpected
subfolder are a **violation**.

---

## Output format

Always produce the report in this exact structure:

```
## Architecture Validation Report

### Summary
- Projects checked: N
- Files scanned: N
- VIOLATIONS: N  ← highlight red if > 0
- WARNINGS: N

---

### Violations  (must fix)
[list each as]:
  ❌ [CHECK-N] <short title>
     File: <path>
     Rule: <which rule was broken>
     Detail: <one sentence explaining the problem>

### Warnings  (review recommended)
[list each as]:
  ⚠️  [CHECK-N] <short title>
     File: <path>
     Rule: <which rule applies>
     Detail: <why this is suspicious>

### Healthy  (passing checks)
  ✅ Project references — all edges conform to the dependency rules
  ✅ Namespace imports — no forbidden using statements found
  ✅ Folder placement — all files in expected locations
  (show only the checks that fully passed; omit checks that had violations)
```

If there are no violations and no warnings, end with:

> All architecture checks passed. The solution conforms to clean architecture rules.

If violations exist, end with a one-paragraph recommendation on what to fix first and
why, written for someone who understands the layering model.
