include .env
include infra/k8s/k8s.mk
include jenkins/jenkins.mk
export

docker_compose_build:
	GIT_COMMIT=$(shell git rev-parse HEAD) \
	BUILD_TIMESTAMP=$(shell date -u +%Y-%m-%dT%H:%M:%SZ) \
	docker compose up --build


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
