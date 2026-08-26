output "state_bucket" {
  description = "Name of the S3 bucket holding remote state."
  value       = aws_s3_bucket.state.id
}

output "state_bucket_arn" {
  description = "ARN of the state bucket, for IAM policies granting Terraform access."
  value       = aws_s3_bucket.state.arn
}

output "region" {
  description = "Region the bootstrap resources live in."
  value       = var.region
}

# Paste this into environments/<env>/versions.tf, changing only the key.
output "backend_config" {
  description = "Ready-to-use backend block for every downstream root module."
  value       = <<-EOT
    terraform {
      backend "s3" {
        bucket       = "${aws_s3_bucket.state.id}"
        key          = "environments/<env>/terraform.tfstate"
        region       = "${var.region}"
        encrypt      = true
        use_lockfile = true
      }
    }
  EOT
}
