output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "vpc_id" {
  description = "VPC the cluster runs in. The load balancer controller needs it explicitly."
  value       = module.vpc.vpc_id
}

output "kubeconfig_command" {
  description = "Points kubectl at this environment."
  value       = module.eks.kubeconfig_command
}

output "ecr_repository_urls" {
  description = "Push targets, keyed by image name."
  value       = module.ecr.repository_urls
}

output "registry_url" {
  description = "Registry host for docker login."
  value       = module.ecr.registry_url
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

output "jenkins_role_arn" {
  description = "Pass this to production as external_deploy_role_arns so one controller deploys to both."
  value       = one(module.jenkins[*].iam_role_arn)
}

output "jenkins_instance_id" {
  description = "Controller instance, for aws ssm start-session."
  value       = one(module.jenkins[*].instance_id)
}

output "jenkins_unlock_command" {
  description = "Retrieves the initial admin password without opening SSH."
  value       = one(module.jenkins[*].unlock_command)
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
  }
}

output "controller_service_accounts" {
  description = "Namespace/name of the Kubernetes ServiceAccount associated with each enabled controller's AWS IAM role through EKS Pod Identity. The controller's pods must use the specified ServiceAccount to receive AWS credentials."
  value       = module.in_cluster_controller_identity.controller_service_accounts
}
