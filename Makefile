.PHONY: jenkins

jenkins_folder := ./jenkins

jenkins:
	cd $(jenkins_folder) && docker compose up -d