#!/usr/bin/env bash
set -euo pipefail

# --- helpers ---
log()  { echo "[$(date +%H:%M:%S)] $*"; }
ok()   { echo "  [OK]   $*"; }
fail() { echo "  [FAIL] $*"; }

IMAGE=${1:-gaku-migrator}
K8S_FOLDER=infra/k8s/local/
NAMESPACE=gaku
JOB_NAME=db-migrate

log "Step 1: Export OCI build args"
source scripts/export-oci-env.sh

log "Step 2: Build Docker image ($IMAGE:latest)"
docker build \
  -f docker/Dockerfile.Migrator \
  --build-arg GIT_COMMIT="$GIT_COMMIT" \
  --build-arg BUILD_TIMESTAMP="$BUILD_TIMESTAMP" \
  -t "$IMAGE:latest" \
  . || { echo "ERROR: docker build failed"; exit 1; }

log "Step 3: Load image into minikube"
minikube image load "$IMAGE:latest" || { echo "ERROR: minikube image load failed"; exit 1; }

log "Step 4: Delete existing db-migrate job (jobs are immutable)"
kubectl delete job "$JOB_NAME" -n "$NAMESPACE" --ignore-not-found

log "Step 5: Apply k8s manifests ($K8S_FOLDER)"
kubectl apply -k "$K8S_FOLDER" || { echo "ERROR: kubectl apply failed"; exit 1; }

log "Step 6: Wait for db-migrate job to complete (timeout 120s)"
kubectl wait --for=condition=complete job/"$JOB_NAME" \
  -n "$NAMESPACE" \
  --timeout=120s || { echo "ERROR: db-migrate job did not complete within 120s"; exit 1; }

# --- verification ---
echo ""
echo "=== Result ==="

# Check image exists in Docker
if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${IMAGE}:latest$"; then
  ok "Docker image $IMAGE:latest built"
else
  fail "Docker image $IMAGE:latest not found"
fi

# Check image exists in minikube
if minikube image ls 2>/dev/null | grep -q "$IMAGE"; then
  ok "Image loaded in minikube"
else
  fail "Image not found in minikube"
fi

# Check job exists in k8s
if kubectl get job "$JOB_NAME" -n "$NAMESPACE" &>/dev/null; then
  ok "Job $JOB_NAME exists in namespace $NAMESPACE"
else
  fail "Job $JOB_NAME not found in namespace $NAMESPACE"
fi

# Check job pod completed
DB_LAST=$(kubectl get pod -n "$NAMESPACE" -l job-name="$JOB_NAME" --no-headers 2>&1)
if echo "$DB_LAST" | grep -q "Completed"; then
  ok "db-migrate pod: Completed"
else
  fail "db-migrate pod: expected Completed, got: $DB_LAST"
fi
