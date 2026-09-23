variable "iam_name_prefix" {
  description = "Prefix for the IAM role and managed policy names for in-cluster controller."
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster to which the created IAM identities are associated."
  type        = string
}

# ---------------------------------------------------------------------------
# AWS Load Balancer Controller
# ---------------------------------------------------------------------------

variable "enable_load_balancer_controller" {
  description = "Whether to create the IAM role and Pod Identity association that let the AWS Load Balancer Controller create ALBs for Ingress objects."
  type        = bool
  default     = true
}

variable "load_balancer_controller_namespace" {
  description = "Namespace the controller runs in. The Helm chart defaults to kube-system."
  type        = string
  default     = "kube-system"
}

variable "load_balancer_controller_service_account" {
  description = <<-EOT
    Service account the controller runs as. Must match the name the Helm release
    creates: Pod Identity binds the role to this exact name, and a pod running
    under any other service account falls back to node credentials silently.
  EOT
  type        = string
  default     = "aws-load-balancer-controller"
}

# ---------------------------------------------------------------------------
# External Secrets Operator
# ---------------------------------------------------------------------------

variable "enable_external_secrets" {
  description = "Whether to create the IAM role and Pod Identity association that let the External Secrets Operator read the specified secrets."
  type        = bool
  default     = true
}

variable "external_secrets_secret_arns" {
  description = <<-EOT
    ARNs of Secrets Manager secrets the External Secrets Operator may read.
    Required when enable_external_secrets is true; an IAM policy with an empty Resource list is invalid.
  EOT
  type        = list(string)
  default     = []
}

variable "external_secrets_namespace" {
  description = "Namespace the External Secrets Operator runs in."
  type        = string
  default     = "external-secrets"
}

variable "external_secrets_service_account" {
  description = <<-EOT
    Service account the External Secrets Operator runs as.
    Pod Identity binds the role to this name.
  EOT
  type        = string
  default     = "external-secrets"
}
