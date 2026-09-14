variable "region" {
  description = "AWS region."
  type        = string
  default     = "eu-central-1"
}

variable "project" {
  description = "Project slug."
  type        = string
  default     = "gaku"
}

variable "environment" {
  description = "Environment name, used in every resource name."
  type        = string
  default     = "production"
}

variable "vpc_cidr" {
  description = "VPC CIDR. Distinct from staging's 10.0.0.0/16 so the two can be peered later."
  type        = string
  default     = "10.1.0.0/16"
}

variable "availability_zones" {
  description = "AZs to spread across."
  type        = list(string)
  default     = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
}

variable "cluster_version" {
  description = "EKS Kubernetes version. Upgrade staging first."
  type        = string
  default     = "1.34"
}

variable "create_ecr_repositories" {
  description = <<-EOT
    False: staging owns the registry and production reads the same repositories,
    so a tested image is promoted by digest rather than rebuilt. Apply staging first.
  EOT
  type        = bool
  default     = false
}

variable "cluster_public_access_cidrs" {
  description = "CIDRs allowed to reach the Kubernetes API. Narrow this to your own address."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_jenkins" {
  description = "Run a Jenkins controller here too. Off by default - the staging controller deploys to both."
  type        = bool
  default     = false
}

variable "jenkins_allowed_cidrs" {
  description = "CIDRs allowed to reach the Jenkins UI, when enable_jenkins is true."
  type        = list(string)
  default     = []
}

variable "external_deploy_role_arns" {
  description = <<-EOT
    IAM roles granted cluster-admin on this cluster. Set this to the staging
    stack's jenkins_role_arn output so the deploy stage can reach production.
  EOT
  type        = list(string)
  default     = []
}
