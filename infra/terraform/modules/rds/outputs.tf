output "address" {
  description = "Hostname of the instance, without the port."
  value       = aws_db_instance.this.address
}

output "port" {
  description = "Listening port."
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "Initial database name."
  value       = var.db_name
}

output "security_group_id" {
  description = "Security group for port 5432."
  value       = aws_security_group.this.id
}

output "secret_arn" {
  description = "Secrets Manager ARN holding the credentials and connection string."
  value       = aws_secretsmanager_secret.db.arn
}

output "secret_name" {
  description = "Secrets Manager name."
  value       = aws_secretsmanager_secret.db.name
}

output "connection_string" {
  description = <<-EOT
  "Npgsql connection string for non AWS consumer. 
  For AWS consumer, use Secrets Manager."
  EOT
  value       = local.connection_string
  sensitive   = true
}
