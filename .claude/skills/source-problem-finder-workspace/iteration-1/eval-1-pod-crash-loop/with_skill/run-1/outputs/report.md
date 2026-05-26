# Problem Source Report

## Symptom

User reports gaku-api pod is in CrashLoopBackOff.

## Investigation

**Phase 1 — understand symptom**: Runtime pod failure; component is gaku-api.

**Phase 2 — gather signals**:

- `kubectl get pods -n gaku`: pod is currently _Running_, RESTARTS=1 (16h ago)
- `kubectl describe pod gaku-api-56fdddcb8b-z6hsw -n gaku`: Last State = Terminated, Reason = **Completed**, Exit Code = **0** — clean shutdown, not a crash
- `kubectl logs --previous`: shows `libgssapi_krb5.so.2` warning, then normal startup and clean shutdown — confirming deliberate restart
- `kubectl logs` (current): shows a `SocketException (Resource temporarily unavailable)` originating from `DataSeeder.SeedAsync()` at startup

**Phase 3 — trace to root**:

- Stack trace innermost frame: `Gaku.Infrastructure.Data.DataSeeder.SeedAsync()` at `DataSeeder.cs:line 12`
- Called from: `Program.<Main>$()` at `Program.cs:line 23`
- `DataSeeder.cs:12` is `if (await context.Trails.AnyAsync())` — first EF Core DB call on startup
- Exception chain: `DNS resolution failed (SocketException 11: Resource temporarily unavailable)` → `NpgsqlException` → `InvalidOperationException` (transient failure)
- `Program.cs:23-28` wraps the seeder call in try/catch and logs `"Seeding failed — continuing without seed data"` — the API **starts successfully despite the error**

---

## Layer

Kubernetes infra (DNS transient race) + .NET application startup code

## Evidence

```
fail: Program[0]
      Seeding failed — continuing without seed data
      System.InvalidOperationException: An exception has been raised that is likely due to a transient failure.
       ---> Npgsql.NpgsqlException (0x80004005): Resource temporarily unavailable
       ---> System.Net.Sockets.SocketException (00000001, 11): Resource temporarily unavailable
         ...
         at Gaku.Infrastructure.Data.DataSeeder.SeedAsync() in /src/src/Gaku.Infrastructure/Data/DataSeeder.cs:line 12
         at Program.<Main>$(String[] args) in /src/src/Gaku.Api/Program.cs:line 23
```

Source: `kubectl logs gaku-api-56fdddcb8b-z6hsw -n gaku --tail=60`

## Root Cause

**Current state: not in CrashLoopBackOff.** The 1 restart was a clean shutdown (exit code 0), not a crash.

The non-fatal error in the current logs:

- File: `src/Gaku.Infrastructure/Data/DataSeeder.cs:12` (`context.Trails.AnyAsync()`)
- Called at: `src/Gaku.Api/Program.cs:23`
- Cause: DNS was temporarily unavailable when the pod started, preventing the initial DB connection needed to check whether seed data exists. This is a k8s pod startup race — the API pod started before the cluster DNS was fully ready to resolve the `postgres` service hostname. The error is caught and non-fatal; the API starts normally.

The previous restart (exit code 0, ~16h ago): deliberate restart, not a crash — no code defect.

## How to confirm

```bash
# Confirm DNS transient: check if seeder errors appear only at pod start, not during normal operation
kubectl logs gaku-api-56fdddcb8b-z6hsw -n gaku | grep -i "seeding\|seed\|DataSeeder"

# Confirm pod is healthy now
kubectl get pod gaku-api-56fdddcb8b-z6hsw -n gaku
```
