include .env
include infra/k8s/k8s.mk
export
.PHONY: jenkins

JENKINS_FOLDER := ./jenkins/local

jenkins_up:
	cd $(JENKINS_FOLDER) && docker compose up -d

jenkins_down:
	cd $(JENKINS_FOLDER) && docker compose down

jenkins_restart:
	cd $(JENKINS_FOLDER) && docker compose restart

jenkins_rebuild:
	cd $(JENKINS_FOLDER) && docker compose up -d --build

pg_up:
	docker compose up -d postgres

local_up: jenkins_up minikube_up pg_up

#Pass git diff to host system
gph:
	git diff > $(HOST_SYSTEM_REPO)/my-changes.patch

#Apply git diff in host system
gap:
	git apply .\my-changes.patch
	rm  .\my-changes.patch
