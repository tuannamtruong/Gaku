output "repository_urls" {
  description = "Repository name to push URL, e.g. gaku-api => <account>.dkr.ecr.<region>.amazonaws.com/gaku-api."
  value       = { for name, repo in local.repositories : name => repo.url }
}

output "repository_arns" {
  description = "Repository ARNs, for the IAM policy that lets Jenkins push."
  value       = [for repo in local.repositories : repo.arn]
}

output "registry_url" {
  description = "Registry host, the argument to docker login."
  value       = length(local.repositories) > 0 ? split("/", values(local.repositories)[0].url)[0] : null
}
