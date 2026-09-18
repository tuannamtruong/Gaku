# ---------------------------------------------------------------------------
# Grant each in-cluster controller an AWS identity with least privilege access.
#
# ---------------------------------------------------------------------------

locals {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      # TagSession lets EKS add pod identity context (cluster, namespace, and service account) to the STS session for CloudTrail attribution.
      Action = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })
}

# ---------------------------------------------------------------------------
# AWS Load Balancer Controller
# ---------------------------------------------------------------------------

resource "aws_iam_role" "load_balancer_controller" {
  count = var.enable_load_balancer_controller ? 1 : 0

  name               = "${var.iam_name_prefix}-aws-load-balancer-controller"
  description        = "Creates and manages ALBs for Ingress objects in ${var.cluster_name}."
  assume_role_policy = local.assume_role_policy
}

resource "aws_iam_policy" "load_balancer_controller" {
  count = var.enable_load_balancer_controller ? 1 : 0

  name        = "${var.iam_name_prefix}-aws-load-balancer-controller"
  description = "Upstream policy from the aws-load-balancer-controller release."
  # Verbatim from the controller's own iam_policy.json. It is broad by
  # necessity: the mutating statements are fenced off by a condition on the
  # elbv2.k8s.aws/cluster tag the controller stamps on everything it creates,
  # so it cannot touch a load balancer it did not build.
  policy = file("${path.module}/policies/aws-load-balancer-controller.json")
}

resource "aws_iam_role_policy_attachment" "load_balancer_controller" {
  count = var.enable_load_balancer_controller ? 1 : 0

  role       = aws_iam_role.load_balancer_controller[0].name
  policy_arn = aws_iam_policy.load_balancer_controller[0].arn
}

resource "aws_eks_pod_identity_association" "load_balancer_controller" {
  count = var.enable_load_balancer_controller ? 1 : 0

  cluster_name    = var.cluster_name
  namespace       = var.load_balancer_controller_namespace
  service_account = var.load_balancer_controller_service_account
  role_arn        = aws_iam_role.load_balancer_controller[0].arn
}
