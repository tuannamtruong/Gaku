variable "name" {
  description = "Cluster name."
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes minor version."
  type        = string
  default     = "1.34"
}

variable "private_subnet_ids" {
  description = "Private subnets ids for the control plane ENIs and the node group instances."
  type        = list(string)
}

variable "endpoint_public_access" {
  description = "Expose the Kubernetes API to the internet. Required for kubectl from a laptop."
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "CIDRs allowed to reach the public API endpoint. Narrow this from the default."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enabled_cluster_log_types" {
  description = "Control plane logs shipped to CloudWatch. 'audit' is the expensive one."
  type        = list(string)
  default     = ["api", "authenticator"]
}

variable "node_instance_types" {
  description = "Instance types for the managed node group."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_capacity_type" {
  description = "ON_DEMAND or SPOT."
  type        = string
  default     = "ON_DEMAND"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.node_capacity_type)
    error_message = "node_capacity_type must be ON_DEMAND or SPOT."
  }
}

variable "node_desired_size" {
  description = "Starting node count."
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum node count."
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum node count."
  type        = number
  default     = 4
}

variable "node_disk_size" {
  description = "Root volume size in GiB per node."
  type        = number
  default     = 20
}

variable "admin_principal_arns" {
  description = <<-EOT
    IAM principals granted cluster-admin through EKS access entries. The Jenkins
    instance role belongs here so the deploy stage can run kubectl.
  EOT
  type        = list(string)
  default     = []
}
