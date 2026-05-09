include .env
export
.PHONY: jenkins

jenkins_folder := ./jenkins/local

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

#Pass git diff to host system
gph:
	git diff > $(HOST_SYSTEM_REPO)/my-changes.patch

#Apply git diff in host system
gap:
	git apply .\my-changes.patch
	rm  .\my-changes.patch