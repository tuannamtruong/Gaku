#!/usr/bin/env bash
set -euo pipefail

log()  { echo "[$(date +%H:%M:%S)] $*"; }
ok()   { echo "  [OK]   $*"; }
fail() { echo "  [FAIL] $*"; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="gaku-web"
NAMESPACE="gaku"
DEPLOYMENT="gaku-web"
DRY_RUN=0

for arg in "$@"; do
  [[ "$arg" == "--dry-run" ]] && DRY_RUN=1
done

run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "  [dry-run] $*"
  else
    "$@" || { echo "ERROR: command failed: $*"; exit 1; }
  fi
}

cd "$REPO_ROOT"

log "Step 1: Exporting OCI build args (GIT_COMMIT, BUILD_TIMESTAMP)"
source scripts/export-oci-env.sh

log "Step 2: Building Docker image '${IMAGE}:latest' (Gaku.Web + Infrastructure + Application + Domain)"
run docker build \
  -f docker/Dockerfile.Gaku.Web \
  --build-arg GIT_COMMIT="$GIT_COMMIT" \
  --build-arg BUILD_TIMESTAMP="$BUILD_TIMESTAMP" \
  -t "${IMAGE}:latest" \
  .

log "Step 3: Loading image into minikube"
run minikube image load "${IMAGE}:latest"

log "Step 4: Restarting deployment '${DEPLOYMENT}' in namespace '${NAMESPACE}'"
run kubectl rollout restart deployment/"${DEPLOYMENT}" -n "${NAMESPACE}"

log "Step 5: Waiting for rollout to complete (timeout 90s)"
run kubectl rollout status deployment/"${DEPLOYMENT}" -n "${NAMESPACE}" --timeout=90s

echo ""
echo "=== Result ==="

if [[ $DRY_RUN -eq 1 ]]; then
  ok "Dry-run complete — no actual changes made"
else
  if docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^${IMAGE}:latest$"; then
    ok "Docker image '${IMAGE}:latest' exists locally"
  else
    fail "Docker image '${IMAGE}:latest' not found locally"
  fi

  if minikube image ls 2>/dev/null | grep -q "${IMAGE}"; then
    ok "Image '${IMAGE}' present in minikube"
  else
    fail "Image '${IMAGE}' not found in minikube image list"
  fi

  WEB_POD=$(kubectl get pod -n "${NAMESPACE}" -l app="${DEPLOYMENT}" --no-headers 2>&1)
  if echo "$WEB_POD" | grep -q "1/1.*Running"; then
    ok "Deployment '${DEPLOYMENT}': Running 1/1"
  else
    fail "Deployment '${DEPLOYMENT}': not Running 1/1 (current: $WEB_POD)"
  fi
fi

echo ""
log "Done."
