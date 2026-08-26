variable "region" {
  description = "AWS region holding the state bucket and lock table."
  type        = string
  default     = "eu-central-1"
}

variable "project" {
  description = "Project slug, used as the prefix for every resource name."
  type        = string
  default     = "gaku"
}

variable "state_bucket_name" {
  description = <<-EOT
    Explicit name for the state bucket. Leave empty to derive
    "<project>-tfstate-<account-id>-<region>", which is globally unique without
    hardcoding the account into source control.
  EOT
  type        = string
  default     = ""
}

variable "noncurrent_version_expiration_days" {
  description = "Days to keep superseded state versions before S3 expires them."
  type        = number
  default     = 90

  validation {
    condition     = var.noncurrent_version_expiration_days >= 30
    error_message = "Keep at least 30 days of history - older versions are the only way back from a corrupted state file."
  }
}
