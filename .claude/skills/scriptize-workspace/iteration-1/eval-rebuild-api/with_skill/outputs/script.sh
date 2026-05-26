#!/usr/bin/env bash
set -euo pipefail

# --- helpers ---
log()  { echo "[$(date +%H:%M:%S)] $*"; }
ok()   { echo "  [OK]   $*"; }
fail() { echo "  [FAIL] $*"; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE=${1:-gaku-api}
NAMESPACE=gaku
DEPLOYMENT=gaku-api

cd "$REPO_ROOT"

# --- main steps ---
log "Step 1: Exporting OCI build args (GIT_COMMIT, BUILD_TIMESTAMP)"
source scripts/export-oci-env.sh

log "Step 2: Building Docker image '$IMAGE:latest'"
docker build \
  -f docker/Dockerfile.Gaku.Api \
  --build-arg GIT_COMMIT="$GIT_COMMIT" \
  --build-arg BUILD_TIMESTAMP="$BUILD_TIMESTAMP" \
  -t "${IMAGE}:latest" \
  . || { echo "ERROR: docker build failed"; exit 1; }

log "Step 3: Loading image into minikube"
minikube image load "${IMAGE}:latest" \
  || { echo "ERROR: minikube image load failed — is minikube running?"; exit 1; }

log "Step 4: Restarting deployment '$DEPLOYMENT' in namespace '$NAMESPACE'"
kubectl rollout restart deployment/"$DEPLOYMENT" -n "$NAMESPACE" \
  || { echo "ERROR: kubectl rollout restart failed — is the cluster reachable?"; exit 1; }

log "Step 5: Waiting for rollout to complete (timeout 90s)"
kubectl rollout status deployment/"$DEPLOYMENT" -n "$NAMESPACE" --timeout=90s \
  || { echo "ERROR: rollout did not complete within 90s"; exit 1; }

# --- verification ---
echo ""
echo "=== Result ==="

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

API_POD=$(kubectl get pod -n "$NAMESPACE" -l app="$DEPLOYMENT" --no-headers 2>&1)
if echo "$API_POD" | grep -q "1/1.*Running"; then
  ok "Deployment '$DEPLOYMENT': Running 1/1"
else
  fail "Deployment '$DEPLOYMENT': not Running 1/1 (current: $API_POD)"
fi

echo ""
log "Done. Run 'make k8s_test_layer3' to verify in-cluster HTTP reachability."
