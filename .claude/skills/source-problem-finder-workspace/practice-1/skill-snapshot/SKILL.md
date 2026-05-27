---
name: source-problem-finder
description: >
  Diagnoses the source of errors, exceptions, unexpected behaviour, or symptoms in the Gaku stack.
  Given any symptom — a stack trace, pod crashing, failing Jenkins build, bad API response, blank
  page, missing data, build error — this skill traces it all the way to the root cause without
  assuming the layer first.

  Trigger whenever the user reports: an error message, exception, stack trace, "it's broken",
  "not working", "failing", "crashing", "can't deploy", unexpected behaviour, or any symptom
  that needs a diagnosis. Also trigger when another skill or subagent needs a root cause
  identified before proceeding.

  This skill diagnoses only — it finds and explains the source. It does NOT fix anything.
---

# source-problem-finder

Find the root cause of a problem in the Gaku stack. Your job ends when you can point at the exact
file, line, config key, migration, or query that is causing the observed symptom. Do not fix it.

---

## Phase 1 — understand the symptom

Read what the user reported:

- **What** was observed? (error text, exception type, unexpected output, missing data, blank page)
- **When** does it happen? (build time, deploy time, startup, at a specific user action)
- **Which component** seems involved? (gaku-api, gaku-web, db-migrate, Jenkins, postgres, a specific endpoint or page)

**Do not assume the layer.** A "database error" might be a misconfigured connection string in a
k8s secret. A pod crash might trace to a Docker build that cached a stale binary. A 500 from the
API might originate in a missing EF Core migration. Verify before concluding.

---

## Phase 2 — gather signals

Pick the signal sources most relevant to the symptom and run them. If you are unsure where to
start, check the k8s pods first — almost every runtime problem leaves a trace there.

### Kubernetes pods (start here for any runtime symptom)

```bash
kubectl get pods -n gaku                                             # what state are pods in?
kubectl describe pod <pod-name> -n gaku                              # events, image pull errors, probe failures, OOM
kubectl logs <pod-name> -n gaku --previous                           # logs from the last crashed instance
kubectl logs <pod-name> -n gaku --tail=200                           # current instance
kubectl logs deployment/gaku-api -n gaku --tail=200
kubectl logs deployment/gaku-web -n gaku --tail=200
kubectl get events -n gaku --sort-by='.lastTimestamp'
```

### db-migrate job (EF Core migration failures)

```bash
kubectl get pod -n gaku -l job-name=db-migrate
kubectl logs <migrator-pod> -n gaku
kubectl describe job db-migrate -n gaku
```

### .NET build / MSBuild (compile errors, missing references)

```bash
dotnet build src/Gaku.sln 2>&1
dotnet build src/<Project>/<Project>.csproj 2>&1
```

### Docker image builds (failed build stages, missing packages)

```bash
docker build -f docker/Dockerfile.Gaku.Api . 2>&1 | tail -60
docker build -f docker/Dockerfile.Gaku.Web . 2>&1 | tail -60
docker build -f docker/Dockerfile.Migrator  . 2>&1 | tail -60
```

### EF Core migrations (schema drift, pending migrations)

```bash
dotnet ef migrations list \
  --project src/Gaku.Infrastructure \
  --startup-project src/Gaku.Api
```

### PostgreSQL (schema problems, missing extension, bad query)

```bash
# In cluster:
kubectl exec -n gaku deploy/postgres -- \
  psql -U <user> -d <db> -c "\dt"

# Via docker compose (local):
docker compose exec postgres psql -U $POSTGRES_USER -d $POSTGRES_DB -c "\dt"
docker compose exec postgres psql -U $POSTGRES_USER -d $POSTGRES_DB -c "SELECT PostGIS_Version();"
```

### Static resources missing (page partially renders — HTML loads, JS/CSS features dead)

When the server-side output works (navbar, SSR text, API responses) but client-side features
do not (interactive components, maps, modals, styles), the first question is whether the
browser can fetch the static resources the page needs. Check the ingress before reading code.

```bash
# Look for 4xx on any path the browser requests automatically (framework, vendor, CSS)
kubectl logs ingress-nginx-controller-<pod> -n ingress-nginx --tail=100 \
  | grep " 404 \| 403 " | grep -v "favicon"
```

If 404s appear on paths the app is supposed to serve (framework files, compiled bundles,
static assets), the container is not publishing those files. Verify directly:

```bash
# Port-forward and probe the missing path from the host
kubectl port-forward svc/gaku-web -n gaku 18081:8080 &
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:18081/<missing-path>

# Compare the container's publish output to what the path expects
kubectl exec -n gaku deployment/gaku-web -- ls -la /app/wwwroot/
```

If a directory or file that should exist is absent, the Dockerfile build step did not produce
it — move to the "Works locally, broken in container" trace in Phase 3.

### API endpoint (wrong response, 5xx, 4xx)

```bash
# Port-forward if needed:
kubectl port-forward svc/gaku-api -n gaku 18080:8080 &
curl -s http://localhost:18080/<endpoint> | jq .

# Local docker compose:
curl -s http://localhost:8080/<endpoint> | jq .
```

### Jenkins pipeline (CI build or deploy stage failure)

Use the available Jenkins MCP tools:

- `mcp__jenkins__jenkins_get_build_status` — overall build result
- `mcp__jenkins__jenkins_get_console_log` — full console output
- `mcp__jenkins__jenkins_get_pipeline_stages` — which stage failed

Also read `jenkins/Jenkinsfile` to understand what the failing stage does.

### Source code search (exception class, method, error string)

```bash
grep -rn "ExceptionClassName" src/ --include="*.cs"
grep -rn "error message fragment" src/ --include="*.cs" -l
grep -rn "MethodName" src/ --include="*.cs"
```

---

## Phase 3 — trace to root

Once a signal points you at a layer, follow the chain all the way to source. Do not stop at
the symptom; find what caused it.

### Exception in .NET application code

1. Read the full stack trace — the innermost frame closest to the problem is the one to follow.
2. Locate the file and line: `grep -rn "MethodName\|ClassName" src/ --include="*.cs"`
3. Read that file at the indicated line.
4. Common root causes to check:
   - Null reference → is the dependency registered in DI? Check `Extensions/ServiceCollectionExtensions.cs`
   - Missing configuration value → check `appsettings.json` and the k8s secret / configmap
   - Wrong type cast → check the DTO / entity mapping in the service or repository layer
   - Interface not implemented → check if the implementation is in Infrastructure and registered

### Pod CrashLoopBackOff

1. `kubectl describe pod` → read the Events section for the root signal (OOM, failed liveness probe, image pull error, non-zero exit code)
2. `kubectl logs --previous` → last log lines before the crash — this is usually where the startup exception is
3. If **image pull error**: compare the image name in the k8s deployment manifest vs what `minikube image ls` shows
4. If **OOMKilled**: check `resources.limits.memory` in the deployment manifest
5. If **non-zero exit on startup**: follow the app startup exception into the source code

### Docker build failure

1. Find the failing `RUN` step in the build output
2. Read the relevant Dockerfile (`docker/Dockerfile.Gaku.Api`, `.Web`, `.Migrator`)
3. For `dotnet restore` failures: check the `.csproj` for bad `<PackageReference>` or broken `<ProjectReference>` paths
4. For file-not-found during `COPY`: check that the path in the Dockerfile matches what actually exists in the repo

### EF Core / db-migrate failure

1. Get the exact error from the migrator pod logs
2. `relation does not exist` → a table the migration expects is missing; run `migrations list` and compare applied vs pending
3. `already exists` → migration partially applied before; check what the failed migration creates and what already exists in the schema
4. Read the failing migration file in `src/Gaku.Infrastructure/Migrations/`
5. For PostGIS errors: confirm `CREATE EXTENSION IF NOT EXISTS postgis` ran first (check earlier migrations)

### PostgreSQL / spatial query failure

1. Get the raw SQL — EF Core logs it at Debug level, or find it in the stack trace
2. Run the query manually in psql to reproduce
3. Check: table name casing, column name, spatial type (`geography` vs `geometry`), SRID mismatch, missing index
4. `TrailRepository.GetNearbyAsync` uses `ST_DWithin` with `geography(Point,4326)` — verify the parameter type matches

### Jenkins pipeline failure

1. Find the failing stage name in the console log
2. Read `jenkins/Jenkinsfile` for what that stage executes
3. Check associated Makefile targets: `Makefile`, `infra/k8s/k8s.mk`, `jenkins/jenkins.mk`
4. Common causes: docker build failure, kubectl command targeting wrong namespace, image name mismatch, test failure

### Unexpected runtime behaviour (wrong data, missing results)

1. Curl the API endpoint directly — isolates whether it is a frontend or backend issue
2. If API returns wrong/empty data: trace `Endpoint → Service → Repository → SQL query`
3. If API returns 500: find the exception in the pod logs, then trace to source code
4. If only the Web renders incorrectly: check gaku-web pod logs for Blazor component errors; look at the relevant Page or Component file

---

## Phase 4 — report

Always produce this structured report. Be specific — "the exception is at TrailService.cs:47" is
useful; "there might be an issue in the service layer" is not.

```
## Problem Source Report

### Symptom
[Restate what was reported, one sentence]

### Layer
[.NET code | Docker build | Kubernetes infra | EF Core / migration | PostgreSQL | Jenkins CI]

### Evidence
[The specific log line, exception message, or build output that points to the source]
  Source: <kubectl logs gaku-api / docker build output / MSBuild output / etc.>

### Root Cause
  File: <src/Gaku.X/Y/Z.cs line N> (or config: infra/k8s/local/... or migration: 20250101_AddX.cs)

  [One clear sentence: what is wrong and the mechanical reason it produces the observed symptom]

### How to confirm
  [Single command the user can run to reproduce or verify the diagnosis]
```

If the evidence points to multiple possible causes, list each with its supporting evidence and your
confidence. Do not speculate without evidence — if a layer shows no matching signal, state that
clearly and move to the next. A diagnosis with honest uncertainty is better than a confident guess.
