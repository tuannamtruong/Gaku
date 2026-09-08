variable "name" {
  description = "Name prefix for every resource, e.g. gaku-staging."
  type        = string
}

variable "cidr_block" {
  description = "Base CIDR."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "AZs to spread subnets across. One public and one private subnet per AZ."
  type        = list(string)
  default     = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "EKS requires subnets in at least two availability zones."
  }
}

variable "single_nat_gateway" {
  description = "If all private subnets routed through one NAT gateway."
  type        = bool
  default     = false
}

variable "enable_flow_logs" {
  description = "If VPC flow logs is sent to CloudWatch."
  type        = bool
  default     = false
}

variable "flow_log_retention_days" {
  description = "CloudWatch retention for flow logs."
  type        = number
  default     = 14
}
