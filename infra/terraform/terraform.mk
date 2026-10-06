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

# State key the version and encryption checks read. Any environment's state works.
TF_STATE_KEY             ?= environments/staging/terraform.tfstate
# Must match noncurrent_version_expiration_days in the bootstrap apply.
TF_STATE_NONCURRENT_DAYS ?= 90

# Read-only checks of the state bucket.
# Each variable below (WRITTEN, VERSIONED, SSE, ...) is set only when its check passes.
# check() prints [OK] for a set variable and [FAIL] for an empty one; any [FAIL] makes the target exit non-zero.
tf_bootstrap_test:
	@echo "=== Gaku Terraform Bootstrap Report ==="
	@$(TF_READ_BOOTSTRAP_OUTPUT); \
	BUCKET=$$(tf_out state_bucket) || { \
	  echo "[FAIL] No state_bucket output - run 'make tf_bootstrap_apply' first"; exit 1; }; \
	REGION=$$(tf_out region) || { \
	  echo "[FAIL] No region output - run 'make tf_bootstrap_apply' first"; exit 1; }; \
	KEY=$(TF_STATE_KEY); \
	echo "  Bucket: $$BUCKET"; \
	echo "  Region: $$REGION"; \
	echo "  Key   : $$KEY"; \
	echo ""; \
	s3() { aws s3api "$$@" --bucket "$$BUCKET" --region "$$REGION" 2>/dev/null; }; \
	check() { [ -n "$$2" ] && printf '[OK]   %-20s %s\n' "$$1" "$$3" \
	                       || { printf '[FAIL] %-20s %s\n' "$$1" "$$4"; FAILED=1; }; }; \
	EXISTS=$$(s3 head-bucket >/dev/null && echo yes); \
	LATEST=$$(s3 list-object-versions --prefix "$$KEY" \
	  --query "Versions[?Key=='$$KEY' && IsLatest].LastModified | [0]" --output text | grep -v '^None$$'); \
	WRITTEN=$$([ -n "$$EXISTS" ] && echo "$$LATEST"); \
	OLD=$$(s3 list-object-versions --prefix "$$KEY" \
	  --query "Versions[?Key=='$$KEY' && IsLatest==\`false\`] | [0].VersionId" --output text | grep -v '^None$$'); \
	TMP=$$(mktemp); \
	OLD_SERIAL=$$([ -n "$$OLD" ] && s3 get-object --key "$$KEY" --version-id "$$OLD" "$$TMP" >/dev/null \
	  && jq -r .serial "$$TMP"); \
	rm -f "$$TMP"; \
	CUR_SERIAL=$$(aws s3 cp "s3://$$BUCKET/$$KEY" - --region "$$REGION" 2>/dev/null | jq -r .serial); \
	VERSIONED=$$([ "$$OLD_SERIAL" -lt "$$CUR_SERIAL" ] 2>/dev/null && echo yes); \
	SSE=$$(s3 head-object --key "$$KEY" --query ServerSideEncryption --output text | grep -x AES256); \
	PAB=$$(s3 get-public-access-block --output text --query \
	  'PublicAccessBlockConfiguration.[BlockPublicAcls,IgnorePublicAcls,BlockPublicPolicy,RestrictPublicBuckets]' \
	  | xargs | grep -x 'True True True True'); \
	OWNERSHIP=$$(s3 get-bucket-ownership-controls --output text \
	  --query 'OwnershipControls.Rules[0].ObjectOwnership' | grep -x BucketOwnerEnforced); \
	EXPIRE=$$(s3 get-bucket-lifecycle-configuration --output text --query \
	  "Rules[?ID=='expire-noncurrent-state-versions' && Status=='Enabled'] | [0].NoncurrentVersionExpiration.NoncurrentDays" \
	  | grep -x '$(TF_STATE_NONCURRENT_DAYS)'); \
	ABORT=$$(s3 get-bucket-lifecycle-configuration --output text --query \
	  "Rules[?ID=='abort-incomplete-uploads' && Status=='Enabled'] | [0].AbortIncompleteMultipartUpload.DaysAfterInitiation" \
	  | grep -x 7); \
	POLICY=$$(s3 get-bucket-policy --query Policy --output text | jq -e \
	  '.Statement[] | select(.Effect == "Deny" and .Condition.Bool["aws:SecureTransport"] == "false")' \
	  >/dev/null && echo yes); \
	HTTP=$$(aws s3api head-object --bucket "$$BUCKET" --key "$$KEY" --region "$$REGION" \
	  --endpoint-url "http://s3.$$REGION.amazonaws.com" 2>&1 | grep -o '(403)'); \
	echo "=== Checklist ==="; \
	check "Bucket + write:"   "$$WRITTEN"   "exists, $$KEY last written $$LATEST" \
	                                        "bucket missing, or no state at $$KEY - apply an environment first"; \
	check "Versioning:"       "$$VERSIONED" "older version $$OLD retrievable, serial $$OLD_SERIAL < $$CUR_SERIAL" \
	                                        "no older version of $$KEY could be read"; \
	check "Encryption:"       "$$SSE"       "$$KEY reports AES256" \
	                                        "$$KEY does not report AES256"; \
	check "Public access:"    "$$PAB"       "all four block settings on" \
	                                        "not all four block settings are on"; \
	check "Ownership:"        "$$OWNERSHIP" "BucketOwnerEnforced, ACLs disabled" \
	                                        "object ownership is not BucketOwnerEnforced"; \
	check "Lifecycle expiry:" "$$EXPIRE"    "noncurrent versions expire after $(TF_STATE_NONCURRENT_DAYS) days" \
	                                        "expire-noncurrent-state-versions not enabled at $(TF_STATE_NONCURRENT_DAYS) days"; \
	check "Lifecycle abort:"  "$$ABORT"     "incomplete uploads aborted after 7 days" \
	                                        "abort-incomplete-uploads not enabled at 7 days"; \
	check "TLS-only policy:"  "$$POLICY"    "Deny on aws:SecureTransport = false" \
	                                        "no Deny statement on aws:SecureTransport"; \
	check "Plain HTTP:"       "$$HTTP"      "signed HTTP request denied with 403" \
	                                        "signed HTTP request was not denied"; \
	[ -z "$$FAILED" ]

# ---------------------------------------------------------------------------
# Environment-specific commands
# ---------------------------------------------------------------------------

# guard target:
# - env parameter is in the command
# - env folder for this parameter is also exist
_tf_require_env:
	@if [ -z "$(ENV)" ]; then \
	  echo "ENV is required, e.g. make tf_env_plan ENV=staging"; exit 1; fi
	@if [ ! -d "$(TF_ENV_DIR)" ]; then \
	  echo "No such environment: $(TF_ENV_DIR)"; exit 1; fi

tf_env_init: _tf_require_env
	cd $(TF_ENV_DIR) && terraform init -input=false -reconfigure

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