output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "kubeconfig_command" {
  description = "Points kubectl at this environment."
  value       = module.eks.kubeconfig_command
}

output "ecr_repository_urls" {
  description = "Push targets, keyed by image name. Same registry staging pushes to."
  value       = module.ecr.repository_urls
}

output "db_address" {
  description = "RDS hostname."
  value       = module.rds.address
}
  
output "db_secret_name" {
  description = "Secrets Manager entry holding the connection string."
  value       = module.rds.secret_name
}

output "jenkins_url" {
  description = "Jenkins UI, when enabled in this environment."
  value       = one(module.jenkins[*].url)
}

output "nat_public_ips" {
  description = "Egress addresses seen by Nominatim and Overpass."
  value       = module.vpc.nat_public_ips
}

output "controller_role_arns" {
  description = "Pod Identity roles for the in-cluster controllers."
  value = {
    load_balancer_controller = module.in_cluster_controller_identity.load_balancer_controller_role_arn
    external_secrets         = module.in_cluster_controller_identity.external_secrets_role_arn
    cluster_autoscaler       = module.in_cluster_controller_identity.cluster_autoscaler_role_arn
  }
}

output "controller_service_accounts" {
  description = "Namespace/name of the Kubernetes ServiceAccount associated with each enabled controller's AWS IAM role through EKS Pod Identity. The controller's pods must use the specified ServiceAccount to receive AWS credentials."
  value       = module.in_cluster_controller_identity.controller_service_accounts
}
