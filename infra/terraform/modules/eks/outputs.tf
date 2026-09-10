output "cluster_name" {
  description = "Cluster name, argument for aws eks update-kubeconfig."
  value       = aws_eks_cluster.this.name
}

output "cluster_arn" {
  description = "Cluster ARN."
  value       = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority" {
  description = "Base64 CA bundle for the API server."
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_security_group_id" {
  description = <<-EOT
    The security group EKS attaches to the control plane and to every managed
    node. Reference it from the RDS module to let pods reach Postgres.
  EOT
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "node_role_arn" {
  description = "IAM role assumed by the worker nodes."
  value       = aws_iam_role.node.arn
}

output "kubeconfig_command" {
  description = "Command that points kubectl at this cluster."
  value       = "aws eks update-kubeconfig --name ${aws_eks_cluster.this.name} --region ${data.aws_region.current.region}"
}

data "aws_region" "current" {}
