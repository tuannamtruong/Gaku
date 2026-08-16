K8S_FOLDER=infra/k8s/local/

minikube_up:
	minikube start

k8s_apply:
	kubectl apply -k $(K8S_FOLDER)

k8s_postgres:
	kubectl exec -it -n gaku statefulset/postgres -- psql -U $(POSTGRES_USER) -d $(POSTGRES_DB)

k8s_test_layer1:
	@echo "=== Gaku Kubernetes Resource Report ==="
	@RAW=$$(kubectl get all,ingress,pvc,secret,configmap -n gaku 2>&1); \
	echo "$$RAW"; \
	echo ""; \
	echo "=== Checklist ==="; \
	echo "$$RAW" | grep -q "secret/gaku-secret"       && echo "[OK] Secret:      gaku-secret"       || echo "[MISSING] Secret:      gaku-secret"; \
	echo "$$RAW" | grep -q "configmap/gaku-config"    && echo "[OK] ConfigMap:   gaku-config"        || echo "[MISSING] ConfigMap:   gaku-config"; \
	echo "$$RAW" | grep "postgres-pvc" | grep -q "Bound" && echo "[OK] PVC:         postgres-pvc (Bound)" || echo "[MISSING] PVC:         postgres-pvc (not Bound)"; \
	echo "$$RAW" | grep -q "statefulset.apps/postgres" && echo "[OK] StatefulSet: postgres"          || echo "[MISSING] StatefulSet: postgres"; \
	echo "$$RAW" | grep -q "deployment.apps/gaku-api" && echo "[OK] Deployment:  gaku-api"           || echo "[MISSING] Deployment:  gaku-api"; \
	echo "$$RAW" | grep -q "deployment.apps/gaku-web" && echo "[OK] Deployment:  gaku-web"           || echo "[MISSING] Deployment:  gaku-web"; \
	echo "$$RAW" | grep -q "job.batch/db-migrate"     && echo "[OK] Job:         db-migrate"         || echo "[MISSING] Job:         db-migrate"; \
	echo "$$RAW" | grep -q "ingress.networking.k8s.io/gaku-ingress" && echo "[OK] Ingress:     gaku-ingress" || echo "[MISSING] Ingress:     gaku-ingress"; \
	echo "$$RAW" | grep -q "service/gaku-api"          && echo "[OK] Service:     gaku-api"           || echo "[MISSING] Service:     gaku-api"; \
	echo "$$RAW" | grep -q "service/gaku-web"          && echo "[OK] Service:     gaku-web"           || echo "[MISSING] Service:     gaku-web"; \
	echo "$$RAW" | grep -q "service/postgres"          && echo "[OK] Service:     postgres"           || echo "[MISSING] Service:     postgres"

k8s_test_layer2:
	@echo "=== Gaku Kubernetes Pod Rollout Report ==="
	@echo ""
	@echo "--- kubectl get pod -n gaku -l app=postgres ---"
	@kubectl get pod -n gaku -l app=postgres 2>&1 || true
	@echo ""
	@echo "--- kubectl get pod -n gaku -l job-name=db-migrate ---"
	@kubectl get pod -n gaku -l job-name=db-migrate 2>&1 || true
	@echo ""
	@echo "--- kubectl get pod -n gaku -l app=gaku-api ---"
	@kubectl get pod -n gaku -l app=gaku-api 2>&1 || true
	@echo ""
	@echo "--- kubectl get pod -n gaku -l app=gaku-web ---"
	@kubectl get pod -n gaku -l app=gaku-web 2>&1 || true
	@echo ""
	@echo "=== Checklist ==="
	@POSTGRES=$$(kubectl get pod -n gaku -l app=postgres --no-headers 2>&1); \
	DB_LAST=$$(kubectl get pod -n gaku -l job-name=db-migrate --no-headers 2>&1); \
	API=$$(kubectl get pod -n gaku -l app=gaku-api --no-headers 2>&1); \
	WEB=$$(kubectl get pod -n gaku -l app=gaku-web --no-headers 2>&1); \
	echo "$$POSTGRES" | grep -q "1/1.*Running" && echo "[OK] postgres:   Running 1/1"       || echo "[FAIL] postgres:   expected Running 1/1"; \
	echo "$$DB_LAST"  | grep -q "Completed"    && echo "[OK] db-migrate: Completed"         || echo "[FAIL] db-migrate: expected Completed"; \
	echo "$$API"      | grep -q "1/1.*Running" && echo "[OK] gaku-api:   Running 1/1"       || echo "[FAIL] gaku-api:   expected Running 1/1"; \
	echo "$$WEB"      | grep -q "1/1.*Running" && echo "[OK] gaku-web:   Running 1/1"       || echo "[FAIL] gaku-web:   expected Running 1/1"


k8s_test_layer3:
	@echo "=== Test: In-cluster DNS reachability ==="
	@API_RC=1; WEB_RC=1; DB_RC=1; \
	kubectl delete pod curl-api curl-web curl-pg -n gaku --ignore-not-found >/dev/null 2>&1; \
	kubectl run curl-api --rm -i --restart=Never --image=curlimages/curl -n gaku \
	  -- curl -sf http://gaku-api.gaku.svc.cluster.local:8080/api/health >/dev/null 2>&1 \
	  && API_RC=0 || true; \
	kubectl run curl-web --rm -i --restart=Never --image=curlimages/curl -n gaku \
	  -- curl -sf http://gaku-web.gaku.svc.cluster.local:8080/health >/dev/null 2>&1 \
	  && WEB_RC=0 || true; \
	kubectl run curl-pg --rm -i --restart=Never --image=postgres:16 -n gaku \
	  -- pg_isready -h postgres.gaku.svc.cluster.local -p 5432 >/dev/null 2>&1 \
	  && DB_RC=0 || true; \
	echo "=== Checklist ==="; \
	[ $$API_RC -eq 0 ] && echo "[OK]   gaku-api  DNS + /health reachable"   || echo "[FAIL] gaku-api  DNS or /health unreachable"; \
	[ $$WEB_RC -eq 0 ] && echo "[OK]   gaku-web  DNS + /health reachable"   || echo "[FAIL] gaku-web  DNS or /health unreachable"; \
	[ $$DB_RC  -eq 0 ] && echo "[OK]   postgres  DNS + pg_isready passed"   || echo "[FAIL] postgres  DNS or pg_isready failed"

k8s_test_layer4:
	@echo "=== Test: In-cluster TCP routing to postgres ==="
	@API_RC=1; WEB_RC=1; \
	kubectl delete pod nc-api nc-web -n gaku --ignore-not-found >/dev/null 2>&1; \
	kubectl run nc-api --rm -i --restart=Never --image=busybox -n gaku \
	  -- sh -c 'nc -zw3 postgres.gaku.svc.cluster.local 5432' >/dev/null 2>&1 \
	  && API_RC=0 || true; \
	kubectl run nc-web --rm -i --restart=Never --image=busybox -n gaku \
	  -- sh -c 'nc -zw3 postgres.gaku.svc.cluster.local 5432' >/dev/null 2>&1 \
	  && WEB_RC=0 || true; \
	echo "=== Checklist ==="; \
	[ $$API_RC -eq 0 ] && echo "[OK]   gaku-api → postgres:5432 reachable" || echo "[FAIL] gaku-api → postgres:5432 not reachable"; \
	[ $$WEB_RC -eq 0 ] && echo "[OK]   gaku-web → postgres:5432 reachable" || echo "[FAIL] gaku-web → postgres:5432 not reachable"

k8s_test_layer5:
	@echo "=== Test: Ingress External Routing ==="
	@MINIKUBE_IP=$$(minikube ip 2>/dev/null); \
	INGRESS_IP=$$(kubectl get ingress gaku-ingress -n gaku \
	  -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null); \
	TARGET_IP=$${INGRESS_IP:-$$MINIKUBE_IP}; \
	if [ -z "$$TARGET_IP" ]; then echo "[ERROR] Could not determine target IP (minikube running?)"; exit 1; fi; \
	echo "  Ingress IP : $${INGRESS_IP:-(none assigned)}"; \
	echo "  Minikube IP: $$MINIKUBE_IP"; \
	echo "  Testing via: $$TARGET_IP"; \
	echo ""; \
	RESOLVE="gaku.local:80:$$TARGET_IP"; \
	WEB_CODE=$$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 --resolve "$$RESOLVE" \
	  "http://gaku.local/health" 2>&1); \
	API_CODE=$$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 --resolve "$$RESOLVE" \
	  "http://gaku.local/api/health" 2>&1); \
	echo "=== Checklist ==="; \
	[ "$$WEB_CODE" = "200" ] \
	  && echo "[OK]   Web  gaku.local/health     → gaku-web  : HTTP $$WEB_CODE" \
	  || echo "[FAIL] Web  gaku.local/health     → gaku-web  : HTTP $$WEB_CODE (expected 200, HTTP 000 = no response)"; \
	[ "$$API_CODE" = "200" ] \
	  && echo "[OK]   API  gaku.local/api/health → gaku-api  : HTTP $$API_CODE" \
	  || echo "[FAIL] API  gaku.local/api/health → gaku-api  : HTTP $$API_CODE (expected 200)"

k8s_test: k8s_test_layer1 k8s_test_layer2 k8s_test_layer3 k8s_test_layer4 k8s_test_layer5
