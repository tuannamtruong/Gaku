JENKINS_FOLDER := ./infra/jenkins/local
JENKINS_AWS_TF := infra/terraform/environments/staging
JENKINS_JOB    ?= gaku
JENKINS_USER   ?= admin

# Create a Jenkins job from a config.xml through the REST API.
JENKINS_CREATE_JOB = create_job() { \
	  printf 'Password for Jenkins user $(JENKINS_USER): '; stty -echo 2>/dev/null; read -r P; stty echo 2>/dev/null; echo; \
	  AUTH="user = \"$(JENKINS_USER):$$P\""; \
	  JAR=$$(mktemp); trap 'rm -f "$$JAR"' EXIT; \
	  CRUMB=$$(printf '%s\n' "$$AUTH" | curl -sf -K- -c "$$JAR" "$$1/crumbIssuer/api/json" \
	    | jq -r '.crumbRequestField + ":" + .crumb' 2>/dev/null); \
	  case "$$CRUMB" in *?:?*) ;; *) \
	    echo "[FAIL] Could not log in to $$1 as $(JENKINS_USER)"; return 1;; esac; \
	  printf '%s\n' "$$AUTH" | curl -sSf -K- -b "$$JAR" -H "$$CRUMB" -H 'Content-Type: application/xml' \
	    --data-binary "@$$3" "$$1/createItem?name=$$2" \
	    || { echo "[FAIL] Job $$2 not created; a 400 usually means it already exists"; return 1; }; \
	  echo "[OK] $$1/job/$$2/"; \
	}

# -------------------------------------------------------------------------------------------------
# Local Jenkins (docker compose, http://localhost:8090)
# -------------------------------------------------------------------------------------------------
jenkins_up:
	cd $(JENKINS_FOLDER) && docker compose up -d

jenkins_down:
	cd $(JENKINS_FOLDER) && docker compose down

jenkins_restart:
	cd $(JENKINS_FOLDER) && docker compose restart

jenkins_rebuild:
	cd $(JENKINS_FOLDER) && docker compose up -d --build

# -------------------------------------------------------------------------------------------------
# AWS Jenkins (EC2 controller in staging)
# -------------------------------------------------------------------------------------------------

# Prints the setup wizard's unlock password through SSM Run Command.
jenkins_aws_password:
	@ID=$$(cd $(JENKINS_AWS_TF) && terraform output -raw jenkins_instance_id 2>/dev/null); \
	case "$$ID" in i-*) ;; *) \
	  echo "[FAIL] No Jenkins instance - set enable_jenkins = true and apply staging first"; exit 1;; esac; \
	CMD=$$(aws ssm send-command --instance-ids "$$ID" --document-name AWS-RunShellScript \
	  --parameters 'commands=["cat /var/lib/jenkins/secrets/initialAdminPassword"]' \
	  --query Command.CommandId --output text) || exit 1; \
	if aws ssm wait command-executed --command-id "$$CMD" --instance-id "$$ID" 2>/dev/null; then \
	  aws ssm get-command-invocation --command-id "$$CMD" --instance-id "$$ID" \
	    --query StandardOutputContent --output text; \
	else \
	  echo "[FAIL] No unlock password - Jenkins is still installing, or the wizard is already done"; \
	  aws ssm get-command-invocation --command-id "$$CMD" --instance-id "$$ID" \
	    --query StandardErrorContent --output text; \
	  exit 1; \
	fi

# Creates the pipeline job from aws/job-config.xml on the staging controller. 
# Run after the setup wizard.
jenkins_aws_job:
	@URL=$$(cd $(JENKINS_AWS_TF) && terraform output -raw jenkins_url 2>/dev/null); \
	case "$$URL" in http*) ;; *) \
	  echo "[FAIL] No Jenkins URL - set enable_jenkins = true and apply staging first"; exit 1;; esac; \
	$(JENKINS_CREATE_JOB); create_job "$$URL" $(JENKINS_JOB) ./infra/jenkins/aws/job-config.xml
