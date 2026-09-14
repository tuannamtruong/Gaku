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
  default     = "staging"
}

variable "vpc_cidr" {
  description = "VPC CIDR. Kept distinct from production so the two can be peered later."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "AZs to spread across."
  type        = list(string)
  default     = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
}

variable "cluster_version" {
  description = "EKS Kubernetes version."
  type        = string
  default     = "1.34"
}

variable "create_ecr_repositories" {
  description = <<-EOT
    Staging owns the registry; production reads the same repositories so an image
    can be promoted by digest instead of rebuilt. Apply staging first.
  EOT
  type        = bool
  default     = true
}

variable "cluster_public_access_cidrs" {
  description = "CIDRs allowed to reach the Kubernetes API. Narrow this to your own address."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_jenkins" {
  description = "Run the Jenkins controller in this environment. One controller deploys to both."
  type        = bool
  default     = true
}

variable "jenkins_allowed_cidrs" {
  description = "CIDRs allowed to reach the Jenkins UI. Empty means nobody, which is the safe default."
  type        = list(string)
  default     = []
}

variable "external_deploy_role_arns" {
  description = "Extra IAM roles granted cluster-admin, e.g. a controller living in another environment."
  type        = list(string)
  default     = []
}
