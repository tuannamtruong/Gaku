TF_BOOTSTRAP := infra/terraform/bootstrap

tf_fmt:
	terraform fmt -recursive infra/terraform


# -------------------------------------------------------------------------------------------------
# Bootstrap Makefile
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

# Prints the backend block downstream root modules should use.
tf_backend_config:
	@cd $(TF_BOOTSTRAP) && terraform output -raw backend_config

tf_bootstrap_test:
	@echo "=== Gaku Terraform Bootstrap Report ==="
	@BUCKET=$$(cd $(TF_BOOTSTRAP) && terraform output -raw state_bucket 2>/dev/null); \
	REGION=$$(cd $(TF_BOOTSTRAP) && terraform output -raw region 2>/dev/null); \
	TABLE=$$(cd $(TF_BOOTSTRAP) && terraform output -raw lock_table 2>/dev/null); \
	if [ -z "$$BUCKET" ]; then \
	  echo "[FAIL] No state_bucket output - run 'make tf_bootstrap_apply' first"; exit 1; \
	fi; \
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
