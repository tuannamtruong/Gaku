# Problem Source Report

## Symptom

db-migrate job failing after adding a waypoints migration; Web app won't start properly.

## Investigation

**Phase 1 — understand symptom**: Two related symptoms — EF Core migration job failing + Web app startup problem. Migration job runs at deploy time. Need to check both separately.

**Phase 2 — gather signals**:

_db-migrate job:_

- `kubectl describe job db-migrate -n gaku`: Pods Statuses = **1 Succeeded / 0 Failed** — job completed cleanly, 13s duration
- `kubectl logs db-migrate-bkhq9 -n gaku`: Build succeeded, migrations ran successfully, `Done.` — no error
- Applied migrations (via psql `__EFMigrationsHistory`): `InitialCreate`, `AddDataProtectionKeys`, `SyncCoordinatesValueConverter` — 3 migrations applied

_Codebase search for waypoints migration:_

- `ls src/Gaku.Infrastructure/Migrations/`: only 2 named migrations exist — `20260524140213_AddDataProtectionKeys` and `20260525104253_SyncCoordinatesValueConverter`. No waypoints-specific migration file.
- `grep -r "Waypoint" src/Gaku.Infrastructure/Migrations/`: the `Waypoint` table is already defined in `20260506160058_InitialCreate.cs` — it was part of the initial schema, not a separate migration.

_gaku-web logs:_

- `kubectl logs deployment/gaku-web -n gaku --tail=30`: pod is running and serving requests (Overpass API calls visible). Errors present: `JSDisconnectedException` from `LeafletMap.DisposeAsync()` — but this is a Blazor circuit teardown warning on client disconnect, not a startup failure.

**Phase 3 — trace to root**:

- The reported waypoints migration does not exist in the codebase. The `Waypoint` table was created in `InitialCreate` (20260506160058) and is applied.
- If a new migration had been added that tried to create or alter `Waypoint` when it already exists, EF Core would fail with `relation "Waypoint" already exists` or a duplicate column error.
- The Web app "won't start" symptom does not match the logs — the app is running. The `JSDisconnectedException` in `LeafletMap.razor:35` / `LeafletInterop.cs:35` is a normal Blazor teardown path triggered when a client navigates away during an async dispose. It is not a startup error.

---

## Layer (db-migrate)

EF Core / migration — but currently no failure. The described waypoints migration is not present in the codebase.

## Layer (Web app)

.NET code — `Gaku.Web.Services.LeafletInterop.DestroyMapAsync` / `Gaku.Web.Components.Map.LeafletMap.DisposeAsync`

## Evidence

```
# db-migrate job: healthy
Pods Statuses: 0 Active / 1 Succeeded / 0 Failed
[logs] Done.

# Migrations applied:
20260506160058_InitialCreate        ← Waypoint table created here
20260524140213_AddDataProtectionKeys
20260525104253_SyncCoordinatesValueConverter

# Web app error (not startup):
fail: CircuitHost[111]
      Microsoft.JSInterop.JSDisconnectedException: JavaScript interop calls cannot be issued
      at Gaku.Web.Services.LeafletInterop.DestroyMapAsync() in LeafletInterop.cs:line 35
      at Gaku.Web.Components.Map.LeafletMap.DisposeAsync() in LeafletMap.razor:line 35
```

## Root Cause

**db-migrate**: No failure currently. The described waypoints migration does not exist in the repository — the `Waypoint` table has been in the schema since `InitialCreate` (`src/Gaku.Infrastructure/Migrations/20260506160058_InitialCreate.cs`). If a migration was "added yesterday", it was not committed to the image being deployed. A migration applied to a schema where `Waypoint` already exists would fail with `42P07: relation "Waypoint" already exists`.

**Web app**: The `JSDisconnectedException` at `src/Gaku.Web/Services/LeafletInterop.cs:35` / `src/Gaku.Web/Components/Map/LeafletMap.razor:35` is not a startup failure — it is a teardown-path warning thrown when `DestroyMapAsync` is called after the Blazor circuit has already disconnected. The app is running normally.

## How to confirm

```bash
# Confirm no waypoints migration in the image
kubectl exec -n gaku db-migrate-bkhq9 -- ls /src/src/Gaku.Infrastructure/Migrations/ 2>/dev/null || \
  ls src/Gaku.Infrastructure/Migrations/ | grep -i waypoint

# Confirm Waypoint table already exists
kubectl exec -n gaku deploy/postgres -- psql -U gaku -d gaku -c "\d \"Waypoint\""
```
