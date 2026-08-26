# AWS Terraforming Bootstrap

Terraform bootstrap using native state locking.

## 1. Deploy Bootstrap

```bash
make tf_bootstrap_init      
make tf_bootstrap_plan       
make tf_bootstrap_apply      
make tf_bootstrap_test      
```

## 2. Wiring downstream modules

After the apply, `backend_config` prints a ready-to-paste block:

```bash
make tf_backend_config
```

Each downstream root module (`environments/staging`, `environments/production`) takes this block and changes only the `key`, so the environments share one bucket while their state files stay separate:

```hcl
terraform {
  backend "s3" {
    bucket       = "gaku-tfstate-<account-id>-eu-central-1"
    key          = "environments/staging/terraform.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true
  }
}
```

## 3. Teardown

`prevent_destroy` makes `terraform destroy` fail by design.

For teardown:
1. Destroy `environments/*` first, while their state is still readable.
2. Delete the `lifecycle { prevent_destroy = true }` block in `main.tf`.
3. Empty the bucket.`aws s3 rm s3://<bucket> --recursive` skips noncurrent versions, so remove those explicitly.
4. `terraform destroy`.
