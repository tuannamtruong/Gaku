include .env
export
.PHONY: jenkins

JENKINS_FOLDER := ./jenkins/local
K8S_FOLDER=infra/k8s/local/

jenkins_up:
	cd $(JENKINS_FOLDER) && docker compose up -d

jenkins_down:
	cd $(JENKINS_FOLDER) && docker compose down

jenkins_restart:
	cd $(JENKINS_FOLDER) && docker compose restart

jenkins_rebuild:
	cd $(JENKINS_FOLDER) && docker compose up -d --build

minikube_up:
	minikube start

pg_up:
	docker compose up -d postgres

local_up: jenkins_up minikube_up pg_up

k8s_apply:
	cp .env $(K8S_FOLDER).env
	kubectl apply -k $(K8S_FOLDER)
	rm -f $(K8S_FOLDER).env

#Pass git diff to host system
gph:
	git diff > $(HOST_SYSTEM_REPO)/my-changes.patch

#Apply git diff in host system
gap:
	git apply .\my-changes.patch
	rm  .\my-changes.patch