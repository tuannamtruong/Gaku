.PHONY: jenkins

jenkins_folder := ./jenkins

j_up:
	cd $(jenkins_folder) && docker compose up -d

j_down:
	cd $(jenkins_folder) && docker compose down

j_restart:
	cd $(jenkins_folder) && docker compose restart

j_rebuild:
	cd $(jenkins_folder) && docker compose up -d --build