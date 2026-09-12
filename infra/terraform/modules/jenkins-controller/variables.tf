variable "name" {
  description = "Name prefix for every resource."
  type        = string
}

variable "vpc_id" {
  description = "VPC to place the instance in."
  type        = string
}

variable "subnet_id" {
  description = "Public subnet id - the instance needs a routable address for GitHub webhooks."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.medium"
}

variable "root_volume_size" {
  description = "Root volume in GiB. Jenkins workspaces and Docker layers live here."
  type        = number
  default     = 30
}

variable "allowed_web_cidrs" {
  description = <<-EOT
    CIDRs allowed to reach the Jenkins UI on port 8080. Defaults to nothing -
    set your own address explicitly rather than opening it to the internet.
  EOT
  type        = list(string)
  default     = []
}

variable "allowed_ssh_cidrs" {
  description = "CIDRs allowed to reach port 22. Leave empty and use Session Manager instead."
  type        = list(string)
  default     = []
}

variable "key_name" {
  description = "EC2 key pair for SSH. Null when relying on Session Manager."
  type        = string
  default     = null
}

variable "ecr_repository_arns" {
  description = "Repositories the build is allowed to push to."
  type        = list(string)
  default     = []
}

variable "enable_eks_access" {
  description = <<-EOT
    Attach the EKS policy and write a kubeconfig at boot. A plain bool rather
    than a null check on eks_cluster_arn, because that ARN is unknown at plan
    time and count cannot depend on an unknown value.
  EOT
  type        = bool
  default     = true
}

variable "eks_cluster_arn" {
  description = "Cluster the deploy stage targets. Required when enable_eks_access is true."
  type        = string
  default     = null
}

variable "eks_cluster_name" {
  description = "Cluster name written into the instance's kubeconfig at boot."
  type        = string
  default     = null
}

variable "jenkins_version" {
  description = "Jenkins package channel: stable or latest."
  type        = string
  default     = "stable"
}
