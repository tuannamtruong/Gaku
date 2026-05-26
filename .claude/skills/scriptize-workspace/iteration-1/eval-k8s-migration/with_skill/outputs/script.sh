#!/usr/bin/env bash
set -euo pipefail

# --- helpers ---
log()  { echo "[$(date +%H:%M:%S)] $*"; }
ok()   { echo "  [OK]   $*"; }
fail() { echo "  [FAIL] $*"; }

NAMESPACE=${1:-gaku}
K8S_FOLDER="infra/k8s/local/"

log "Step 1: Delete existing db-migrate job (if present)"
kubectl delete job db-migrate -n "$NAMESPACE" --ignore-not-found

log "Step 2: Re-apply k8s manifests (creates db-migrate job)"
kubectl apply -k "$K8S_FOLDER"

log "Step 3: Wait for db-migrate job to complete (timeout 120s)"
kubectl wait --for=condition=complete job/db-migrate -n "$NAMESPACE" --timeout=120s \
  || { echo "ERROR: db-migrate job did not complete within 120s — check pod logs:"; \
       echo "  kubectl logs -n $NAMESPACE -l job-name=db-migrate --tail=50"; \
       exit 1; }

# --- verification ---
echo ""
echo "=== Result ==="

JOB_STATUS=$(kubectl get pod -n "$NAMESPACE" -l job-name=db-migrate --no-headers 2>&1)

if echo "$JOB_STATUS" | grep -q "Completed"; then
  ok "db-migrate pod: Completed"
else
  fail "db-migrate pod: expected Completed — got: $JOB_STATUS"
fi

JOB_EXISTS=$(kubectl get job db-migrate -n "$NAMESPACE" --no-headers 2>&1)
if echo "$JOB_EXISTS" | grep -q "db-migrate"; then
  ok "db-migrate job: exists in namespace $NAMESPACE"
else
  fail "db-migrate job: not found in namespace $NAMESPACE"
fi
