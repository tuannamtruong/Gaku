variable "name" {
  description = "Name prefix for every resource."
  type        = string
}

variable "vpc_id" {
  description = "VPC to place the instance and its security group in."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet ids for the DB subnet group. At least two AZs."
  type        = list(string)
}

variable "allowed_security_group_ids" {
  description = "Security group ids allowed to reach the DB (port 5432). A map because the ids are only known after apply."
  type        = map(string)
  default     = {}
}

variable "engine_version" {
  description = "PostgreSQL version."
  type        = string
  default     = "16"
}

variable "instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  description = "Initial storage in GiB."
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Ceiling for storage autoscaling. Set equal to allocated_storage to disable."
  type        = number
  default     = 100
}

variable "db_name" {
  description = "Initial database name. Must match the Database= value the app connects with."
  type        = string
  default     = "gaku"
}

variable "username" {
  description = "Master username. Gets rds_superuser, which is what CREATE EXTENSION postgis needs."
  type        = string
  default     = "gaku"
}

variable "multi_az" {
  description = "Run a standby in a second AZ. Doubles the instance cost."
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Days of automated backups. 0 to disable."
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "Deletion protection."
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Skip the snapshot taken on delete."
  type        = bool
  default     = false
}

variable "performance_insights_enabled" {
  description = "Enable Performance Insights."
  type        = bool
  default     = false
}

variable "force_ssl" {
  description = "Reject non-TLS connections."
  type        = bool
  default     = true
}
