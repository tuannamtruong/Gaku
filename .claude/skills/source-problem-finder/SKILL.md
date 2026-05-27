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

**The risk to avoid**: chasing the first signal deep into one layer before ruling out the others.
Always scope the impact and isolate the layer before diving into detailed investigation.

---

## Phase 1 — Understand the symptom

Read what the user reported:

- **What** was observed? (error text, exception type, unexpected output, missing data, blank page)
- **When** does it happen? (build time, deploy time, startup, at a specific user action)
- **Which component** seems involved? (gaku-api, gaku-web, db-migrate, Jenkins, postgres, a specific endpoint or page)
- **Regression or new?** Did this work before and break after a change, or has it never worked?
  - If regression: what changed? (new commit, new image, config update, migration, infra change)

**Do not assume the layer.** A "database error" might be a misconfigured connection string in a
k8s secret. A pod crash might trace to a Docker build that cached a stale binary. A 500 from the
API might originate in a missing EF Core migration. Verify before concluding.

---

## Phase 2 — Scope the impact

Use the reported scope to form an initial layer hypothesis — not a conclusion, just where to look first.

| Who is affected            | Initial hypothesis                                            |
| -------------------------- | ------------------------------------------------------------- |
| One user                   | Data or config issue (bad record, user-specific state)        |
| One feature / one endpoint | Code path, dependency, or migration specific to that feature  |
| One pod instance           | Infrastructure (OOM, scheduling failure, stale image)         |
| All users / all instances  | Systemic — deployment, shared dependency, or platform failure |

This narrows which layer to suspect first. Validate the hypothesis in Phase 3 before committing to it.

---

## Phase 3 — Layer isolation

Run the minimal signals needed to identify which layer owns the problem. Pick one layer and prove it
before switching. Do not mix layers.

### Step 1 — Check pod health (fastest gate for runtime problems)

```bash
kubectl get pods -n gaku                               # pod state, restart count
kubectl get events -n gaku --sort-by='.lastTimestamp'  # OOM, scheduling, image pull errors
```

- Pods are **Pending / CrashLoopBackOff / OOMKilled / ImagePullBackOff** → **Platform layer** — go to Phase 4 › Platform.
- All pods Running, 0 restarts → continue to Step 2.

### Step 2 — Check for application exceptions

```bash
kubectl logs deployment/gaku-api -n gaku --tail=100
kubectl logs deployment/gaku-web -n gaku --tail=100
```

- Logs contain **exceptions, stack traces, or unhandled errors** → **Application layer** — go to Phase 4 › Application.
- Logs are clean → continue to Step 3.

### Step 3 — Check dependency health

```bash
# Is the database accepting connections?
kubectl exec -n gaku deploy/postgres -- psql -U <user> -d <db> -c "SELECT 1;"

# Is the API reachable from the web pod?
kubectl exec -n gaku deployment/gaku-web -- \
  curl -s -o /dev/null -w "%{http_code}" http://gaku-api:8080/health
```

- DB refusing connections, returning errors, or API unreachable → **Dependency layer** — go to Phase 4 › Dependency.
- Dependencies respond normally → continue to Step 4.

### Step 4 — Check network and routing

```bash
# DNS resolution from inside pod
kubectl exec -n gaku deployment/gaku-web -- getent ahosts <hostname>

# Ingress routing and error codes
kubectl logs <ingress-pod> -n ingress-nginx --tail=100 | grep -E " 40[0-9] | 50[0-9] "
kubectl get ingress -n gaku -o yaml | grep -A5 "path:"
```

- DNS fails, ingress shows unexpected 4xx/5xx, routing points to wrong service → **Network layer** — go to Phase 4 › Network.

### Layer decision summary

Commit to exactly one layer before opening Phase 4:

| Layer                         | Signal that confirms it                                                 |
| ----------------------------- | ----------------------------------------------------------------------- |
| **Application**               | Exceptions, stack traces, logic errors, wrong behaviour in code         |
| **Dependency**                | DB down/slow, external API failing, internal RPC errors                 |
| **Platform / Infrastructure** | Pod crashes, OOM, CPU throttling, stale image, scheduling failure       |
| **Network**                   | DNS failures, TLS errors, timeouts between services, ingress misrouting |

If Phase 3 checks return no clear signal, open broader logs:

```bash
kubectl logs <pod-name> -n gaku --previous     # last crashed instance
kubectl describe pod <pod-name> -n gaku        # events, probe failures, resource limits
```

---

## Phase 4 — Deep investigation

Run the detailed investigation for the confirmed layer. If sub-investigation refutes the layer,
return to Phase 3 with the new evidence.

---

### Application layer

#### Exception in .NET code

1. Read the full stack trace — the innermost frame is the one to follow.
2. Locate the file and line: `grep -rn "MethodName\|ClassName" src/ --include="*.cs"`
3. Read that file at the indicated line.
4. Common root causes:
   - **Null reference** → is the dependency registered in DI? Check `Extensions/ServiceCollectionExtensions.cs`
   - **Missing config value** → check `appsettings.json` and the k8s secret / configmap
   - **Wrong type cast** → check the DTO / entity mapping in the service or repository layer
   - **Interface not implemented** → check if the implementation is in Infrastructure and registered

#### Static resources missing (page partially renders — HTML loads, JS/CSS features dead)

When server-side output works (navbar, SSR text) but client-side features do not (interactive
components, maps, styles), check whether the browser can fetch the static resources it needs.

```bash
# Look for 4xx on paths the browser requests automatically
kubectl logs <ingress-pod> -n ingress-nginx --tail=100 \
  | grep " 404 \| 403 " | grep -v "favicon"

# Port-forward and probe the missing path directly from the host
kubectl port-forward svc/gaku-web -n gaku 18081:8080 &
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:18081/<missing-path>

# Check what the container actually published
kubectl exec -n gaku deployment/gaku-web -- ls -la /app/wwwroot/
```

If a directory or file that should exist is absent, the Dockerfile build step did not produce it —
continue to **Platform › Docker** below.

#### Unexpected runtime behaviour (wrong data, missing results)

1. Curl the API endpoint directly — isolates frontend vs backend.
2. If API returns wrong/empty data: trace `Endpoint → Service → Repository → SQL query`
3. If API returns 500: find the exception in pod logs, then trace to source code
4. If only the Web renders incorrectly: check gaku-web pod logs for Blazor component errors; look at the relevant Page or Component file

---

### Dependency layer

#### EF Core / db-migrate failure

```bash
kubectl get pod -n gaku -l job-name=db-migrate
kubectl logs <migrator-pod> -n gaku
kubectl describe job db-migrate -n gaku

dotnet ef migrations list \
  --project src/Gaku.Infrastructure \
  --startup-project src/Gaku.Api
```

- `relation does not exist` → a table the migration expects is missing; compare applied vs pending
- `already exists` → migration partially applied; check what the failed migration creates vs what already exists in the schema
- Read the failing migration file in `src/Gaku.Infrastructure/Migrations/`
- For PostGIS errors: confirm `CREATE EXTENSION IF NOT EXISTS postgis` ran first (check earlier migrations)

#### PostgreSQL / spatial query failure

1. Get the raw SQL — EF Core logs it at Debug level, or find it in the stack trace
2. Run the query manually in psql to reproduce:

```bash
kubectl exec -n gaku deploy/postgres -- psql -U <user> -d <db> -c "<query>"
```

3. Check: table name casing, column name, spatial type (`geography` vs `geometry`), SRID mismatch, missing index
4. `TrailRepository.GetNearbyAsync` uses `ST_DWithin` with `geography(Point,4326)` — verify the parameter type matches

---

### Platform / Infrastructure layer

#### Pod CrashLoopBackOff

```bash
kubectl describe pod <pod-name> -n gaku     # Events: OOM, probe failures, image pull errors
kubectl logs <pod-name> -n gaku --previous  # Last log lines before the crash
```

- **Image pull error** → compare the image name in the k8s deployment manifest vs `minikube image ls`
- **OOMKilled** → check `resources.limits.memory` in the deployment manifest
- **Non-zero exit on startup** → follow the app startup exception into source code

#### Docker build failure

```bash
docker build -f docker/Dockerfile.Gaku.Api . 2>&1 | tail -60
docker build -f docker/Dockerfile.Gaku.Web . 2>&1 | tail -60
docker build -f docker/Dockerfile.Migrator  . 2>&1 | tail -60
```

1. Find the failing `RUN` step in the build output
2. For `dotnet restore` failures: check the `.csproj` for bad `<PackageReference>` or broken `<ProjectReference>` paths
3. For file-not-found during `COPY`: verify the path in the Dockerfile matches what exists in the repo

#### Works locally, broken in container — deployment level trace

Narrow down which level introduced the problem. Stop at the first level where the symptom appears.
Do not read application code until Step 1 confirms the problem is there.

**Step 1 — dotnet directly (no Docker, no k8s)**

```bash
dotnet publish src/Gaku.Web/Gaku.Web.csproj -c Release -o /tmp/local-publish
dotnet /tmp/local-publish/Gaku.Web.dll
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8080/<failing-path>
```

- **Problem here** → issue is in application code or build configuration (`.csproj`, SDK version). Investigate source.
- **Works here** → app is correct; Docker or k8s introduced it. Continue to Step 2.

**Step 2 — Docker image directly (no k8s)**

```bash
docker build -f docker/Dockerfile.Gaku.Web . -t gaku-web-test
docker run --rm -p 8082:8080 gaku-web-test &
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8082/<failing-path>
```

- **Problem here** → the Dockerfile produces a different artifact than `dotnet publish`. Check:
  - Build flags that silently skip targets: `--no-restore` skips static web asset resolution in Blazor (drops `wwwroot/_framework/` and `*.styles.css`)
  - `.dockerignore` excluding files the build step needs
  - Multi-stage `COPY --from=build` path not matching the actual publish output directory
- **Works here** → Docker image is correct; problem is in Kubernetes. Continue to Step 3.

**Step 3 — Kubernetes infrastructure**

```bash
# Is the correct image actually running?
kubectl get deployment gaku-web -n gaku -o jsonpath='{.spec.template.spec.containers[0].image}'
minikube image ls | grep gaku-web

# Does the pod filesystem match the Docker image?
kubectl exec -n gaku deployment/gaku-web -- ls /app/wwwroot/

# Is the ingress routing the path to the right service?
kubectl get ingress -n gaku -o yaml | grep -A5 "path:"
```

Common k8s causes: stale cached image in minikube (pod running old image), wrong image tag in the manifest, ingress path rule sending traffic to the wrong service.

---

### Network layer

```bash
# DNS resolution from inside pod
kubectl exec -n gaku deployment/<pod> -- getent ahosts <hostname>

# Direct connectivity and TLS handshake
kubectl exec -n gaku deployment/<pod> -- curl -v https://<external-host>/

# Ingress logs for routing and TLS errors
kubectl logs <ingress-pod> -n ingress-nginx --tail=200 | grep -E "50[0-9]|40[0-9]|TLS|ssl"
```

Common causes: CNI dropping IPv6 SYN packets (causing ~50 s TCP retransmit timeout before IPv4
fallback); DNS resolution inside pod differs from node; ingress path rules misrouting traffic.

---

### Jenkins pipeline failure

1. Identify the failing stage:
   - `mcp__jenkins__jenkins_get_pipeline_stages` — which stage failed
   - `mcp__jenkins__jenkins_get_console_log` — full console output
2. Read `jenkins/Jenkinsfile` for what that stage executes
3. Check associated Makefile targets: `Makefile`, `infra/k8s/k8s.mk`, `jenkins/jenkins.mk`
4. Common causes: docker build failure, kubectl targeting wrong namespace, image name mismatch, test failure

#### .NET build / MSBuild failures

```bash
dotnet build src/Gaku.sln 2>&1
dotnet build src/<Project>/<Project>.csproj 2>&1
```

---

## Phase 5 — Reproduce and confirm

Before reporting, verify the diagnosis is reproducible.

**For regressions** (worked before, broke after a change):

- Does rollback resolve the issue? If yes, the change introduced it — identify exactly what in the change triggers the symptom.
- Can you reproduce in a clean environment (local `dotnet run`, fresh docker build) without the change?

**For platform-level problems** — use the deployment level trace in Phase 4 (Step 1 → 2 → 3) to
pinpoint which artifact (executable / Docker image / k8s config) introduced the defect.

**Source code confirmation** (verify exception origin is where you think it is):

```bash
grep -rn "ExceptionClassName" src/ --include="*.cs"
grep -rn "error message fragment" src/ --include="*.cs" -l
```

---

## Phase 6 — Report

Always produce this structured report. Be specific — "the exception is at TrailService.cs:47" is
useful; "there might be an issue in the service layer" is not.

```
## Problem Source Report

### Symptom
[Restate what was reported, one sentence]

### Layer
[.NET code | Docker build | Kubernetes infra | EF Core / migration | PostgreSQL | Jenkins CI | Network]

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
