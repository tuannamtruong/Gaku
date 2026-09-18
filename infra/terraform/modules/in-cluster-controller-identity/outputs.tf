output "load_balancer_controller_role_arn" {
  description = "Role the AWS Load Balancer Controller assumes. Null when disabled."
  value       = one(aws_iam_role.load_balancer_controller[*].arn)
}
output "controller_service_accounts" {
  description = "Namespace/name of the Kubernetes ServiceAccount associated with each enabled controller's AWS IAM role through EKS Pod Identity. The controller's pods must use the specified ServiceAccount to receive AWS credentials."
  value = merge(
    var.enable_load_balancer_controller ? {
      load-balancer-controller = "${var.load_balancer_controller_namespace}/${var.load_balancer_controller_service_account}"
    } : {},
  )
}
