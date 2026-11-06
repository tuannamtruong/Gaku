include .env
include infra/k8s/k8s.mk
include infra/terraform/terraform.mk
include infra/jenkins/jenkins.mk
include docker/docker.mk
export

pg_up:
	docker compose up -d postgres

local_up: jenkins_up minikube_up pg_up


#############################################################################
# Repo syncing between Windows and WSL
#############################################################################

BRANCH ?= $(shell git branch --show-current)

# Can only be executed in WSL.
# Windows clone runs git.exe: Linux git there ignores core.autocrlf
wsl_to_win:
	cd $(HOST_SYSTEM_REPO) && git.exe fetch wsl && git.exe merge --ff-only wsl/$(BRANCH)

# Can only be executed in WSL.
win_to_wsl:
	git fetch win && git merge win/$(BRANCH)
