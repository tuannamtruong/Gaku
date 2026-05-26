#!/usr/bin/env bash
set -euo pipefail

# Rebuilds the gaku-api Docker image, loads it into minikube, and restarts the deployment.
#
# Usage:
#   ./script.sh [IMAGE_NAME]
#
# Defaults:
#   IMAGE_NAME = gaku-api

# --- helpers ---
log()  { echo "[$(date +%H:%M:%S)] $*"; }
ok()   { echo "  [OK]   $*"; }
fail() { echo "  [FAIL] $*"; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="${1:-gaku-api}"
NAMESPACE="gaku"
DEPLOYMENT="gaku-api"

# --- pre-flight checks ---
for cmd in docker minikube kubectl git; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: '$cmd' is not installed or not on PATH"
    exit 1
  fi
done

if ! minikube status --format='{{.Host}}' 2>/dev/null | grep -q "Running"; then
  echo "ERROR: minikube is not running — start it with 'minikube start'"
  exit 1
fi

# --- main steps ---
log "Step 1: Exporting OCI build args (GIT_COMMIT, BUILD_TIMESTAMP)"
GIT_COMMIT="$(git -C "$REPO_ROOT" rev-parse HEAD)"
BUILD_TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
export GIT_COMMIT BUILD_TIMESTAMP
log "  GIT_COMMIT=$GIT_COMMIT"
log "  BUILD_TIMESTAMP=$BUILD_TIMESTAMP"

log "Step 2: Building Docker image '${IMAGE}:latest'"
docker build \
  -f "$REPO_ROOT/docker/Dockerfile.Gaku.Api" \
  --build-arg GIT_COMMIT="$GIT_COMMIT" \
  --build-arg BUILD_TIMESTAMP="$BUILD_TIMESTAMP" \
  -t "${IMAGE}:latest" \
  "$REPO_ROOT" \
  || { echo "ERROR: docker build failed"; exit 1; }

log "Step 3: Loading image into minikube"
minikube image load "${IMAGE}:latest" \
  || { echo "ERROR: minikube image load failed"; exit 1; }

log "Step 4: Restarting deployment '${DEPLOYMENT}' in namespace '${NAMESPACE}'"
kubectl rollout restart "deployment/${DEPLOYMENT}" -n "$NAMESPACE" \
  || { echo "ERROR: kubectl rollout restart failed — is the cluster reachable?"; exit 1; }

log "Step 5: Waiting for rollout to complete (timeout 90s)"
kubectl rollout status "deployment/${DEPLOYMENT}" -n "$NAMESPACE" --timeout=90s \
  || { echo "ERROR: rollout did not complete within 90s — check pod logs with:"; \
       echo "  kubectl logs -n ${NAMESPACE} -l app=${DEPLOYMENT} --tail=50"; exit 1; }

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

API_POD="$(kubectl get pod -n "$NAMESPACE" -l "app=${DEPLOYMENT}" --no-headers 2>&1)"
if echo "$API_POD" | grep -q "1/1.*Running"; then
  ok "Deployment '${DEPLOYMENT}': Running 1/1"
else
  fail "Deployment '${DEPLOYMENT}': not Running 1/1 (current: ${API_POD})"
fi

echo ""
log "Done."
