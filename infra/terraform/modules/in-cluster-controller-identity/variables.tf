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
  description = "Grant the AWS Load Balancer Controller its IAM role. Without it an Ingress gets no ALB."
  type        = bool
  default     = true
}

variable "load_balancer_controller_namespace" {
  description = "Namespace the controller runs in. The Helm chart defaults to kube-system."
  type        = string
  default     = "kube-system"
}

variable "load_balancer_controller_service_account" {
  description = "Service account the controller runs as."
  type        = string
  default     = "aws-load-balancer-controller"
}

