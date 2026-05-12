JENKINS_FOLDER := ./jenkins/local

jenkins_up:
	cd $(JENKINS_FOLDER) && docker compose up -d

jenkins_down:
	cd $(JENKINS_FOLDER) && docker compose down

jenkins_restart:
	cd $(JENKINS_FOLDER) && docker compose restart

jenkins_rebuild:
	cd $(JENKINS_FOLDER) && docker compose up -d --build
