K8S_FOLDER=infra/k8s/local/

minikube_up:
	minikube start

k8s_apply:
	cp .env.k8s $(K8S_FOLDER).env.k8s
	kubectl apply -k $(K8S_FOLDER)
	rm -f $(K8S_FOLDER).env.k8s

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
	echo "$$RAW" | grep -q "postgres-pvc"             && echo -n "[OK] PVC:         postgres-pvc" || echo -n "[MISSING] PVC:         postgres-pvc"; \
	echo "$$RAW" | grep "postgres-pvc" | grep -q "Bound" && echo " (Bound)" || echo " (NOT Bound)"; \
	echo "$$RAW" | grep -q "statefulset.apps/postgres" && echo "[OK] StatefulSet: postgres"          || echo "[MISSING] StatefulSet: postgres"; \
	echo "$$RAW" | grep -q "deployment.apps/gaku-api" && echo "[OK] Deployment:  gaku-api"           || echo "[MISSING] Deployment:  gaku-api"; \
	echo "$$RAW" | grep -q "deployment.apps/gaku-web" && echo "[OK] Deployment:  gaku-web"           || echo "[MISSING] Deployment:  gaku-web"; \
	echo "$$RAW" | grep -q "job.batch/db-migrate"     && echo "[OK] Job:         db-migrate"         || echo "[MISSING] Job:         db-migrate"; \
	echo "$$RAW" | grep -q "ingress.networking.k8s.io/gaku-ingress" && echo "[OK] Ingress:     gaku-ingress" || echo "[MISSING] Ingress:     gaku-ingress"; \
	echo "$$RAW" | grep -q "service/"                 && echo "[OK] Services:    present"            || echo "[MISSING] Services:    none found"

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
	@echo "=== Test: API/WEB/DB pods' reachability from inside the cluster via its internal DNS name ==="
	@echo "=== No error -> functional ==="
	kubectl run curl-test --rm -i --restart=Never --image=curlimages/curl -n gaku \
	-- curl -s http://gaku-api.gaku.svc.cluster.local:8080/health

	kubectl run web-test --rm -i --restart=Never --image=curlimages/curl -n gaku \
	-- curl -s http://gaku-web.gaku.svc.cluster.local:8080/health

	kubectl run pg-test --rm -i --restart=Never --image=postgres:16 -n gaku \
	-- pg_isready -h postgres.gaku.svc.cluster.local -p 5432

k8s_test: k8s_test_layer1 k8s_test_layer2 k8s_test_layer3
