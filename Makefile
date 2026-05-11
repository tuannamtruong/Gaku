include .env
export
.PHONY: jenkins

jenkins_folder := ./jenkins/local
K8S_FOLDER=infra/k8s/local/

j_up:
	cd $(jenkins_folder) && docker compose up -d

j_down:
	cd $(jenkins_folder) && docker compose down

j_restart:
	cd $(jenkins_folder) && docker compose restart

j_rebuild:
	cd $(jenkins_folder) && docker compose up -d --build

pg_up:
	docker compose up -d postgres

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