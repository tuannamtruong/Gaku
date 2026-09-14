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
