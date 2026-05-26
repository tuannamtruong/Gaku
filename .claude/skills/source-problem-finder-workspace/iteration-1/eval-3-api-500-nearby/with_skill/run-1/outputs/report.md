# Problem Source Report

## Symptom

GET /api/trails/nearby returns 500; map spinner never resolves.

## Investigation

**Phase 1 — understand symptom**: Runtime API failure on a specific endpoint; frontend effect is a permanent spinner. Component: gaku-api `/api/trails/nearby` endpoint. No recent code changes reported.

**Phase 2 — gather signals**:

- `kubectl get pods -n gaku`: gaku-api Running (1 past restart, unrelated)
- `curl http://localhost:18080/api/trails/nearby?lat=47.0&lon=11.0&radiusKm=50`: confirmed **HTTP 500** with empty body
- `kubectl logs deployment/gaku-api -n gaku --tail=50`: exception captured immediately after the curl

Exception from pod logs:

```
Npgsql.PostgresException (0x80004005): 42P01: relation "trails" does not exist
  at Gaku.Infrastructure.Repositories.TrailRepository.GetNearbyAsync() in TrailRepository.cs:line 26
  at Gaku.Application.Services.TrailService.GetNearbyAsync()          in TrailService.cs:line 26
  at Gaku.Api.Endpoints.TrailEndpoints.GetNearby()                    in TrailEndpoints.cs:line 41
```

**Phase 3 — trace to root**:
Call chain from stack trace:

- `TrailEndpoints.cs:41` → `TrailService.cs:26` → `TrailRepository.cs:26`
- Read `src/Gaku.Infrastructure/Repositories/TrailRepository.cs:28`:
  ```sql
  SELECT * FROM trails
  WHERE ST_DWithin(start_point::geography, ...)
  ```
- DB schema check (`\d "Trail"`): table is named `"Trail"` (PascalCase singular) — project convention is singular DB table names. The raw SQL uses `trails` (lowercase plural).
- `start_point` column name is correct — only the table reference is wrong.
- All other `TrailRepository` methods use EF Core LINQ (which resolves the table name from the EF model configuration) — only `GetNearbyAsync` uses `FromSqlRaw`, so only this endpoint fails.

---

## Layer

.NET Infrastructure code — `TrailRepository.GetNearbyAsync` (raw SQL with wrong table name)

## Evidence

```
Npgsql.PostgresException: 42P01: relation "trails" does not exist
  MessageText: relation "trails" does not exist
  SqlState: 42P01
  at TrailRepository.GetNearbyAsync() in TrailRepository.cs:line 26

# DB actual table name:
Table "public.Trail"   ← PascalCase singular
```

Source: `kubectl logs deployment/gaku-api -n gaku` + `psql \d "Trail"`

## Root Cause

File: `src/Gaku.Infrastructure/Repositories/TrailRepository.cs:28`

The `FromSqlRaw` query hardcodes `FROM trails` but the PostgreSQL table is named `"Trail"` (singular, PascalCase — the project's DB naming convention). PostgreSQL is case-sensitive for unquoted identifiers; `trails` matches no table. Every other repository method uses EF Core LINQ, which resolves the correct table name from the model, so only `/api/trails/nearby` is broken.

## How to confirm

```bash
# Reproduce the 500:
kubectl port-forward svc/gaku-api -n gaku 18080:8080 &
curl -v "http://localhost:18080/api/trails/nearby?lat=47.0&lon=11.0&radiusKm=50"
# → HTTP 500

# Confirm table name:
kubectl exec -n gaku deploy/postgres -- psql -U gaku -d gaku -c '\dt'
# → "Trail" listed, not "trails"
```
