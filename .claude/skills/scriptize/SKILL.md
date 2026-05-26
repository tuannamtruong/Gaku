---
name: scriptize
description: >
  Turns a described development process into a reusable, self-verifying script (Python, Bash, or
  Go) and saves it to scripts/. Invoke this skill whenever the user wants to automate a repeatable
  dev workflow — for example: running EF Core database migrations, rebuilding a .NET Docker image
  and reloading it into minikube, redeploying a specific service, or any multi-step process they
  describe. Trigger on phrases like "make a script for", "write a script that", "scriptize",
  "automate", or when the user walks through a multi-step process and says "I want to be able to
  run this easily". Default to Python for quick one-off scripts; use Bash for DevOps/pipeline
  command chains; use Go for scripts that run often, run at scale, need concurrency, or must ship
  as a single cross-platform binary.
---

## Goal

Turn a multi-step process into a single, reusable script that:

- Runs the process end-to-end with clear progress output
- Handles errors cleanly (exits early on failure with a helpful message)
- Prints a verification checklist at the end so the user can see at a glance whether everything succeeded

## Language choice

If the user hasn't specified a language, pick based on these signals:

| Language   | Use when                                                                                                                                                                                                                                                                                                    |
| ---------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Python** | Default for quick one-off scripts, data wrangling, anything that benefits from a rich stdlib or third-party packages                                                                                                                                                                                        |
| **Bash**   | File operations, pipelines, DevOps/CI scripts, chaining CLI commands — when the script is mostly just running other programs                                                                                                                                                                                |
| **Go**     | Automation that runs often or at scale (cron jobs, data movers, log processors); scripts that need to ship as a single cross-platform binary; performance-sensitive work (parsing large files, many parallel network calls); anything that will live long, run frequently, or be shared across environments |

If it's ambiguous, briefly explain your choice and give the user a chance to redirect.

**Output paths:**

- Python: `scripts/<verb>-<target>.py`
- Bash: `scripts/<verb>-<target>.sh`
- Go: `scripts/<verb>-<target>/main.go` (run with `go run scripts/<verb>-<target>/main.go`)

## Step 1: Understand the process

If the user gave you a description, extract:

1. **What** service or component is targeted (e.g., `gaku-api`, `gaku-migrator`, a migration name)
2. **What steps** are involved — research the relevant project files to confirm the exact commands
3. **What success looks like** — what should be true when the script finishes?

Read what's needed to ground the script in the project's actual setup:

- `Makefile`, `infra/k8s/k8s.mk`, `jenkins/jenkins.mk` — existing targets you can model from
- `docker-compose.yml` and `docker/Dockerfile.*` — image names, build args, compose service names
- `infra/k8s/local/` — k8s manifests (deployments, jobs, statefulsets, namespaces)
- `scripts/export-oci-env.sh` — OCI build-arg exports (GIT_COMMIT, BUILD_TIMESTAMP)

Only read the files that are relevant to the requested process.

## Step 2: Write the script

Use the path from the Language choice section. The skeletons below all share the same structural rules:

- Timestamped progress output before each step
- Immediate exit with a clear error message on failure
- A `=== Result ===` checklist at the end that queries actual system state — don't just trust the commands ran

### Python skeleton (default)

```python
#!/usr/bin/env python3
import subprocess, sys
from datetime import datetime

def log(msg):  print(f"[{datetime.now():%H:%M:%S}] {msg}", flush=True)
def ok(msg):   print(f"  [OK]   {msg}")
def fail(msg): print(f"  [FAIL] {msg}")

def run(*cmd, **kwargs):
    result = subprocess.run(cmd, **kwargs)
    if result.returncode != 0:
        print(f"ERROR: {' '.join(cmd)} exited {result.returncode}", file=sys.stderr)
        sys.exit(result.returncode)

image = sys.argv[1] if len(sys.argv) > 1 else "gaku-api"

log("Step 1: ...")
run("docker", "build", ...)

log("Step 2: ...")
run("kubectl", "rollout", "restart", ...)

print("\n=== Result ===")
result = subprocess.run(["kubectl", "get", "pod", ...], capture_output=True, text=True)
if "Running" in result.stdout:
    ok("pod is Running")
else:
    fail(f"pod not Running: {result.stdout.strip()}")
```

Make executable: `chmod +x scripts/<name>.py`

### Bash skeleton (DevOps/pipeline tasks)

```bash
#!/usr/bin/env bash
set -euo pipefail

log()  { echo "[$(date +%H:%M:%S)] $*"; }
ok()   { echo "  [OK]   $*"; }
fail() { echo "  [FAIL] $*"; }

IMAGE=${1:-gaku-api}

log "Step 1: ..."
<command> || { echo "ERROR: what went wrong"; exit 1; }

log "Step 2: ..."
<command>

echo ""
echo "=== Result ==="
<check and print [OK]/[FAIL] for each expected outcome>
```

Make executable: `chmod +x scripts/<name>.sh`

**Bash-specific patterns for this project:**

Rebuild a Docker image and load into minikube:

```bash
source scripts/export-oci-env.sh
docker build -f docker/Dockerfile.<Service> \
  --build-arg GIT_COMMIT="$GIT_COMMIT" \
  --build-arg BUILD_TIMESTAMP="$BUILD_TIMESTAMP" \
  -t <image-name>:latest .
minikube image load <image-name>:latest
kubectl rollout restart deployment/<name> -n gaku
kubectl rollout status deployment/<name> -n gaku --timeout=60s
```

Re-run the db-migrate Job (jobs are immutable — delete then re-apply):

```bash
kubectl delete job db-migrate -n gaku --ignore-not-found
kubectl apply -k infra/k8s/local/
kubectl wait --for=condition=complete job/db-migrate -n gaku --timeout=120s
```

Run EF migrations via dotnet ef:

```bash
dotnet ef database update \
  --project src/Gaku.Infrastructure \
  --startup-project src/Gaku.Api
```

**Verification checks:**

- Docker image: `docker images --format '{{.Repository}}:{{.Tag}}' | grep <name>`
- Minikube image: `minikube image ls | grep <name>`
- k8s deployment: `kubectl get pod -n gaku -l app=<name> --no-headers` → check `1/1.*Running`
- k8s job: `kubectl get pod -n gaku -l job-name=db-migrate --no-headers` → check `Completed`

### Go skeleton (long-lived, high-frequency, or cross-platform)

```go
package main

import (
	"fmt"
	"os"
	"os/exec"
	"time"
)

func log(msg string)  { fmt.Printf("[%s] %s\n", time.Now().Format("15:04:05"), msg) }
func ok(msg string)   { fmt.Printf("  [OK]   %s\n", msg) }
func fail(msg string) { fmt.Printf("  [FAIL] %s\n", msg) }

func run(name string, args ...string) error {
	cmd := exec.Command(name, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func main() {
	image := "gaku-api"
	if len(os.Args) > 1 {
		image = os.Args[1]
	}

	log("Step 1: ...")
	if err := run("docker", "build", "-t", image+":latest", "."); err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: docker build failed: %v\n", err)
		os.Exit(1)
	}

	// ... more steps ...

	fmt.Println("\n=== Result ===")
	// check and print [OK]/[FAIL]
}
```

Run with: `go run scripts/<verb>-<target>/main.go`

## Step 3: Report to the user

Tell the user:

1. The path to the script and how to run it
2. Why you chose that language (one sentence), unless it was explicit
3. What the verification section checks

If the script takes arguments, explain them.
