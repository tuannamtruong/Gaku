#!/usr/bin/env python3
import re
import subprocess
import sys
import os
from datetime import datetime, timezone

def log(msg):  print(f"[{datetime.now():%H:%M:%S}] {msg}", flush=True)
def ok(msg):   print(f"  [OK]   {msg}")
def fail(msg): print(f"  [FAIL] {msg}")

DRY_RUN = "--dry-run" in sys.argv
IMAGE      = "gaku-web"
NAMESPACE  = "gaku"
DEPLOYMENT = "gaku-web"

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(REPO_ROOT)

def run(*cmd):
    if DRY_RUN:
        print(f"  [dry-run] {' '.join(cmd)}")
        return
    result = subprocess.run(cmd, cwd=REPO_ROOT)
    if result.returncode != 0:
        print(f"ERROR: {' '.join(cmd)} exited {result.returncode}", file=sys.stderr)
        sys.exit(result.returncode)

def capture(*cmd):
    return subprocess.run(cmd, capture_output=True, text=True).stdout

log("Step 1: Exporting OCI build args (GIT_COMMIT, BUILD_TIMESTAMP)")
git_commit = capture("git", "rev-parse", "HEAD").strip()
build_timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
log(f"  GIT_COMMIT={git_commit[:12]}  BUILD_TIMESTAMP={build_timestamp}")

log(f"Step 2: Building Docker image '{IMAGE}:latest' (Gaku.Web + Infrastructure + Application + Domain)")
run("docker", "build",
    "-f", "docker/Dockerfile.Gaku.Web",
    "--build-arg", f"GIT_COMMIT={git_commit}",
    "--build-arg", f"BUILD_TIMESTAMP={build_timestamp}",
    "-t", f"{IMAGE}:latest",
    ".")

log("Step 3: Loading image into minikube")
run("minikube", "image", "load", f"{IMAGE}:latest")

log(f"Step 4: Restarting deployment '{DEPLOYMENT}' in namespace '{NAMESPACE}'")
run("kubectl", "rollout", "restart", f"deployment/{DEPLOYMENT}", "-n", NAMESPACE)

log("Step 5: Waiting for rollout to complete (timeout 90s)")
run("kubectl", "rollout", "status", f"deployment/{DEPLOYMENT}", "-n", NAMESPACE, "--timeout=90s")

print("\n=== Result ===")

if DRY_RUN:
    ok("Dry-run complete — no actual changes made")
else:
    if f"{IMAGE}:latest" in capture("docker", "images", "--format", "{{.Repository}}:{{.Tag}}"):
        ok(f"Docker image '{IMAGE}:latest' exists locally")
    else:
        fail(f"Docker image '{IMAGE}:latest' not found locally")

    if IMAGE in capture("minikube", "image", "ls"):
        ok(f"Image '{IMAGE}' present in minikube")
    else:
        fail(f"Image '{IMAGE}' not found in minikube image list")

    pods = capture("kubectl", "get", "pod", "-n", NAMESPACE, "-l", f"app={DEPLOYMENT}", "--no-headers")
    if re.search(r"1/1\s+Running", pods):
        ok(f"Deployment '{DEPLOYMENT}': Running 1/1")
    else:
        fail(f"Deployment '{DEPLOYMENT}': not Running 1/1 (current: {pods.strip()})")

print()
log("Done.")
