#!/usr/bin/env bash
# re-run-k8s-migrations.sh
# Deletes the db-migrate Job from the gaku namespace and re-creates it via
# kubectl apply, then waits for it to complete.

set -euo pipefail

NAMESPACE="gaku"
JOB_NAME="db-migrate"
JOB_MANIFEST="$(git -C "$(dirname "$0")" rev-parse --show-toplevel 2>/dev/null || echo .)/infra/k8s/local/db-migration/job.yaml"

# Allow the caller to override the manifest path
JOB_MANIFEST="${K8S_JOB_MANIFEST:-$JOB_MANIFEST}"

echo "=== Re-running EF Core database migrations in Kubernetes ==="
echo "  Namespace : $NAMESPACE"
echo "  Job name  : $JOB_NAME"
echo "  Manifest  : $JOB_MANIFEST"
echo ""

# --- 1. Delete existing job (if present) ----------------------------------
if kubectl get job "$JOB_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
  echo "[1/3] Deleting existing job '$JOB_NAME'..."
  kubectl delete job "$JOB_NAME" -n "$NAMESPACE"
  echo "      Job deleted."
else
  echo "[1/3] Job '$JOB_NAME' does not exist — skipping delete."
fi

# --- 2. Re-create the job -------------------------------------------------
echo "[2/3] Creating job '$JOB_NAME' from $JOB_MANIFEST ..."
kubectl apply -f "$JOB_MANIFEST"
echo "      Job created."

# --- 3. Wait for completion -----------------------------------------------
echo "[3/3] Waiting for job '$JOB_NAME' to complete (timeout: 120s)..."
if kubectl wait job/"$JOB_NAME" \
     --for=condition=complete \
     --timeout=120s \
     -n "$NAMESPACE"; then
  echo ""
  echo "[OK] Migrations completed successfully."
else
  echo ""
  echo "[FAIL] Job did not complete within the timeout. Showing pod logs:"
  POD=$(kubectl get pod -n "$NAMESPACE" -l "job-name=$JOB_NAME" \
        --no-headers -o custom-columns=":metadata.name" | head -1)
  if [ -n "$POD" ]; then
    kubectl logs -n "$NAMESPACE" "$POD" || true
  fi
  exit 1
fi
