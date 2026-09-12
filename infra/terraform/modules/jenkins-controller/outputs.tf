output "public_ip" {
  description = "Elastic IP of the controller."
  value       = aws_eip.this.public_ip
}

output "url" {
  description = "Jenkins UI address."
  value       = "http://${aws_eip.this.public_ip}:8080"
}

output "instance_id" {
  description = "Instance id, for aws ssm start-session."
  value       = aws_instance.this.id
}

output "iam_role_arn" {
  description = "Instance role. Pass it to the EKS module as an admin principal so kubectl works."
  value       = aws_iam_role.this.arn
}

output "security_group_id" {
  description = "Controller security group, for rules that need to allow Jenkins in."
  value       = aws_security_group.this.id
}

output "unlock_command" {
  description = "Retrieves the initial admin password without opening SSH."
  value       = "aws ssm start-session --target ${aws_instance.this.id}   # then: sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
}
