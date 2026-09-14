variable "repository_names" {
  description = "Image repositories to manage. Matches the image names built by docker/docker.mk."
  type        = list(string)
  default     = ["gaku-api", "gaku-web", "gaku-migrator"]
}

variable "create" {
  description = <<-EOT
    Create the repositories, or look up ones another environment already created.
    A single registry shared across environments is what makes promote-by-digest
    possible, so exactly one environment should set this true.
  EOT
  type        = bool
  default     = true
}

variable "image_tag_mutability" {
  description = "MUTABLE or IMMUTABLE. IMMUTABLE forbids overwriting a pushed tag."
  type        = string
  default     = "MUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be MUTABLE or IMMUTABLE."
  }
}

variable "scan_on_push" {
  description = "Run a CVE scan when an image is pushed."
  type        = bool
  default     = true
}

variable "force_delete" {
  description = "Allow terraform destroy to delete repositories that still hold images."
  type        = bool
  default     = false
}

variable "keep_last_images" {
  description = "How many tagged images to retain per repository before the lifecycle policy expires them."
  type        = number
  default     = 30
}

variable "untagged_expiry_days" {
  description = "Days before an untagged layer is expired."
  type        = number
  default     = 7
}
