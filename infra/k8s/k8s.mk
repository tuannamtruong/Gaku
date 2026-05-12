K8S_FOLDER=infra/k8s/local/

minikube_up:
	minikube start

k8s_apply:
	cp .env.k8s $(K8S_FOLDER).env.k8s
	kubectl apply -k $(K8S_FOLDER)
	rm -f $(K8S_FOLDER).env.k8s

k8s_postgres:
	kubectl exec -it -n gaku statefulset/postgres -- psql -U $(POSTGRES_USER) -d $(POSTGRES_DB)
