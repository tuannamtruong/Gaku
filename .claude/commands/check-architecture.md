Review the current codebase for Clean Architecture violations in the Gaku project.

Check the following rules:
- `Gaku.Domain` must not reference Application, Infrastructure, Api, or Web namespaces
- `Gaku.Application` must not reference Infrastructure, Api, or Web namespaces
- `Gaku.Infrastructure` must not reference Api or Web namespaces
- In `Gaku.Api` and `Gaku.Web`, Infrastructure types may only be referenced inside `Program.cs` (the composition root) — no page, component, endpoint, or service outside Program.cs should import an Infrastructure namespace directly
- All business interactions outside Program.cs must go through Application service interfaces

Search the source files for any `using` statements or direct type references that violate these rules. Report each violation with the file path and line number. If no violations are found, confirm the architecture is clean.
