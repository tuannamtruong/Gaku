#!/usr/bin/env bash
# redeploy-migrator.sh
# Rebuilds the gaku-migrator Docker image, loads it into minikube,
# deletes the old db-migrate Job, and re-applies the full k8s manifests.
# Run from the repo root: ./scripts/redeploy-migrator.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_NAME="gaku-migrator"
IMAGE_TAG="latest"
DOCKERFILE="docker/Dockerfile.Migrator"
K8S_DIR="infra/k8s/local"
JOB_NAME="db-migrate"
NAMESPACE="gaku"

cd "$REPO_ROOT"

# ── 1. Build the migrator image ───────────────────────────────────────────────
echo "==> Building ${IMAGE_NAME}:${IMAGE_TAG} ..."
docker build \
  --file "$DOCKERFILE" \
  --tag "${IMAGE_NAME}:${IMAGE_TAG}" \
  .

# ── 2. Load the image into minikube ──────────────────────────────────────────
echo "==> Loading image into minikube ..."
minikube image load "${IMAGE_NAME}:${IMAGE_TAG}"

# ── 3. Delete the existing db-migrate Job (if present) ───────────────────────
echo "==> Deleting old Job '${JOB_NAME}' in namespace '${NAMESPACE}' (if it exists) ..."
kubectl delete job "$JOB_NAME" -n "$NAMESPACE" --ignore-not-found

# ── 4. Apply the full k8s manifests via Kustomize ────────────────────────────
echo "==> Applying k8s manifests from ${K8S_DIR} ..."
kubectl apply -k "$K8S_DIR"

# ── 5. Wait for the Job to complete ──────────────────────────────────────────
echo "==> Waiting for Job '${JOB_NAME}' to complete (timeout 120s) ..."
kubectl wait job/"$JOB_NAME" \
  -n "$NAMESPACE" \
  --for=condition=complete \
  --timeout=120s \
  && echo "[OK] db-migrate Job completed successfully." \
  || {
    echo "[FAIL] db-migrate Job did not complete within timeout."
    echo "       Pod logs:"
    kubectl logs -n "$NAMESPACE" -l "job-name=${JOB_NAME}" --tail=50 || true
    exit 1
  }
