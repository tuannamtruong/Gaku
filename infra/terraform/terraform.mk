TF_BOOTSTRAP := infra/terraform/bootstrap
TF_ENV_DIR   := infra/terraform/environments/$(ENV)
TF_MODULES   := ecr vpc rds eks jenkins-controller in-cluster-controller-identity

# Read a Terraform output value from the bootstrap directory, allow only safe characters, and print it.
#
# 'terraform output -raw' prints its "No outputs found" warning on stdout when
# the bootstrap state is empty
TF_READ_BOOTSTRAP_OUTPUT = tf_out() { \
	  V=$$(cd $(TF_BOOTSTRAP) && terraform output -raw "$$1" 2>/dev/null); \
	  case "$$V" in ''|*[!A-Za-z0-9._-]*) return 1;; esac; \
	  printf '%s' "$$V"; \
	}

tf_fmt:
	terraform fmt -recursive infra/terraform

# Syntax check all module and environment without talking to remote backend.
tf_validate_all:
	@RC=0; \
	for d in $(addprefix infra/terraform/modules/,$(TF_MODULES)) \
	         infra/terraform/bootstrap \
	         infra/terraform/environments/staging \
	         infra/terraform/environments/production; do \
	  printf '%-56s' "$$d"; \
	  if (cd $$d && terraform init -backend=false -input=false >/dev/null 2>&1 \
	      && terraform validate >/dev/null 2>&1); then \
	    echo "[OK]"; \
	  else \
	    echo "[FAIL]"; RC=1; \
	    (cd $$d && terraform validate 2>&1 | sed 's/^/    /'); \
	  fi; \
	done; \
	exit $$RC

# -------------------------------------------------------------------------------------------------
# Bootstrap commands
# -------------------------------------------------------------------------------------------------
tf_bootstrap_init:
	cd $(TF_BOOTSTRAP) && terraform init -input=false

tf_bootstrap_validate:
	cd $(TF_BOOTSTRAP) && terraform validate

tf_bootstrap_plan:
	cd $(TF_BOOTSTRAP) && terraform plan -input=false -out=bootstrap.tfplan

tf_bootstrap_apply:
	cd $(TF_BOOTSTRAP) && terraform apply -input=false "bootstrap.tfplan"

tf_bootstrap_output:
	cd $(TF_BOOTSTRAP) && terraform output

# Prints the Terraform backend block
tf_backend_config:
	@cd $(TF_BOOTSTRAP) && terraform output -raw backend_config

tf_bootstrap_test:
	@echo "=== Gaku Terraform Bootstrap Report ==="
	@$(TF_READ_BOOTSTRAP_OUTPUT); \
	BUCKET=$$(tf_out state_bucket) || { \
	  echo "[FAIL] No state_bucket output - run 'make tf_bootstrap_apply' first"; exit 1; }; \
	REGION=$$(tf_out region) || { \
	  echo "[FAIL] No region output - run 'make tf_bootstrap_apply' first"; exit 1; }; \
	TABLE=$$(tf_out lock_table || true); \
	echo "  Bucket: $$BUCKET"; \
	echo "  Region: $$REGION"; \
	echo "  Table : $${TABLE:-(none - S3 native locking)}"; \
	echo ""; \
	VERSIONING=$$(aws s3api get-bucket-versioning --bucket "$$BUCKET" \
	  --query 'Status' --output text 2>/dev/null); \
	ENCRYPTION=$$(aws s3api get-bucket-encryption --bucket "$$BUCKET" \
	  --query 'ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm' \
	  --output text 2>/dev/null); \
	PUBLIC=$$(aws s3api get-public-access-block --bucket "$$BUCKET" \
	  --query 'PublicAccessBlockConfiguration.RestrictPublicBuckets' --output text 2>/dev/null); \
	LIFECYCLE=$$(aws s3api get-bucket-lifecycle-configuration --bucket "$$BUCKET" \
	  --query 'Rules[?Status==`Enabled`] | length(@)' --output text 2>/dev/null); \
	echo "=== Checklist ==="; \
	[ "$$VERSIONING" = "Enabled" ] \
	  && echo "[OK]   Versioning enabled" \
	  || echo "[FAIL] Versioning is '$$VERSIONING' (expected Enabled)"; \
	[ "$$ENCRYPTION" = "AES256" ] \
	  && echo "[OK]   Default encryption AES256" \
	  || echo "[FAIL] Default encryption is '$$ENCRYPTION' (expected AES256)"; \
	[ "$$PUBLIC" = "True" ] \
	  && echo "[OK]   Public access blocked" \
	  || echo "[FAIL] Public access block is '$$PUBLIC' (expected True)"; \
	[ -n "$$LIFECYCLE" ] && [ "$$LIFECYCLE" != "0" ] \
	  && echo "[OK]   Lifecycle rules active: $$LIFECYCLE" \
	  || echo "[FAIL] No enabled lifecycle rules"; \
	if [ -n "$$TABLE" ]; then \
	  TSTATUS=$$(aws dynamodb describe-table --table-name "$$TABLE" --region "$$REGION" \
	    --query 'Table.TableStatus' --output text 2>/dev/null); \
	  THASH=$$(aws dynamodb describe-table --table-name "$$TABLE" --region "$$REGION" \
	    --query 'Table.KeySchema[0].AttributeName' --output text 2>/dev/null); \
	  [ "$$TSTATUS" = "ACTIVE" ] \
	    && echo "[OK]   Lock table ACTIVE" \
	    || echo "[FAIL] Lock table status is '$$TSTATUS' (expected ACTIVE)"; \
	  [ "$$THASH" = "LockID" ] \
	    && echo "[OK]   Lock table hash key LockID" \
	    || echo "[FAIL] Lock table hash key is '$$THASH' (expected LockID)"; \
	fi

# ---------------------------------------------------------------------------
# Environment commands
# ---------------------------------------------------------------------------

# guard target:
# - env parameter is in the command
# - env folder for this parameter is also exist
_tf_require_env:
	@if [ -z "$(ENV)" ]; then \
	  echo "ENV is required, e.g. make tf_env_plan ENV=staging"; exit 1; fi
	@if [ ! -d "$(TF_ENV_DIR)" ]; then \
	  echo "No such environment: $(TF_ENV_DIR)"; exit 1; fi

# Bucket and region come from the bootstrap outputs, so the account id stays
# out of source control. Requires 'make tf_bootstrap_apply' to have run.
tf_env_init: _tf_require_env
	@$(TF_READ_BOOTSTRAP_OUTPUT); \
	BUCKET=$$(tf_out state_bucket) || { \
	  echo "[FAIL] Bootstrap not applied - run 'make tf_bootstrap_apply' first"; exit 1; }; \
	REGION=$$(tf_out region) || { \
	  echo "[FAIL] Bootstrap not applied - run 'make tf_bootstrap_apply' first"; exit 1; }; \
	echo "Backend: s3://$$BUCKET ($$REGION)"; \
	cd $(TF_ENV_DIR) && terraform init -input=false -reconfigure \
	  -backend-config="bucket=$$BUCKET" \
	  -backend-config="region=$$REGION"

tf_env_plan: _tf_require_env
	cd $(TF_ENV_DIR) && terraform plan -input=false

tf_env_apply: _tf_require_env
	cd $(TF_ENV_DIR) && terraform apply -input=false

tf_env_destroy: _tf_require_env
	cd $(TF_ENV_DIR) && terraform destroy -input=false

tf_env_output: _tf_require_env
	cd $(TF_ENV_DIR) && terraform output

# Points kubectl at an environment's cluster.
# 	kubeconfig_command: EKS output
tf_env_kubeconfig: _tf_require_env
	@CMD=$$(cd $(TF_ENV_DIR) && terraform output -raw kubeconfig_command 2>/dev/null); \
	case "$$CMD" in "aws "*) ;; *) \
	  echo "[FAIL] No cluster yet - apply this environment first"; exit 1;; esac; \
	echo "$$CMD"; eval "$$CMD"