include .env
include infra/k8s/k8s.mk
include infra/terraform/terraform.mk
include jenkins/jenkins.mk
include docker/docker.mk
export

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
