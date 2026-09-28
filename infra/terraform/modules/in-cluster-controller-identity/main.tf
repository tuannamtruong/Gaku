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

# ---------------------------------------------------------------------------
# External Secrets Operator
# ---------------------------------------------------------------------------

resource "aws_iam_role" "external_secrets" {
  count = var.enable_external_secrets ? 1 : 0

  name               = "${var.iam_name_prefix}-external-secrets"
  description        = "Allows External Secrets Operator to read specified Secrets Manager secrets."
  assume_role_policy = local.assume_role_policy

  lifecycle {
    precondition {
      condition     = length(var.external_secrets_secret_arns) > 0
      error_message = "external_secrets_secret_arns must list at least one secret when enable_external_secrets is true."
    }
  }
}

resource "aws_iam_role_policy" "external_secrets" {
  count = var.enable_external_secrets ? 1 : 0

  name = "read-secrets"
  role = aws_iam_role.external_secrets[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
      ]
      # Named ARNs, not a wildcard: the operator can read only the secrets listed here.
      Resource = var.external_secrets_secret_arns
    }]
  })
}

resource "aws_eks_pod_identity_association" "external_secrets" {
  count = var.enable_external_secrets ? 1 : 0

  cluster_name    = var.cluster_name
  namespace       = var.external_secrets_namespace
  service_account = var.external_secrets_service_account
  role_arn        = aws_iam_role.external_secrets[0].arn
}

# ---------------------------------------------------------------------------
# Cluster Autoscaler
# ---------------------------------------------------------------------------

resource "aws_iam_role" "cluster_autoscaler" {
  count = var.enable_cluster_autoscaler ? 1 : 0

  name               = "${var.iam_name_prefix}-cluster-autoscaler"
  description        = "Resizes the node group's Auto Scaling group for ${var.cluster_name}."
  assume_role_policy = local.assume_role_policy
}

resource "aws_iam_role_policy" "cluster_autoscaler" {
  count = var.enable_cluster_autoscaler ? 1 : 0

  name = "autoscale-node-group"
  role = aws_iam_role.cluster_autoscaler[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Discovery requires unscoped read-only access because the autoscaler lists resources across the account before filtering by its discovery tags.
      {
        Sid    = "Discover"
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeScalingActivities",
          "autoscaling:DescribeTags",
          "ec2:DescribeImages",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:GetInstanceTypesFromInstanceRequirements",
          "eks:DescribeNodegroup",
        ]
        Resource = "*"
      },
      # Scaling is restricted to resources tagged with this cluster's ownership tag. The same tag is used for node-group discovery.
      {
        Sid    = "Scale"
        Effect = "Allow"
        Action = [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
          }
        }
      },
    ]
  })
}

resource "aws_eks_pod_identity_association" "cluster_autoscaler" {
  count = var.enable_cluster_autoscaler ? 1 : 0

  cluster_name    = var.cluster_name
  namespace       = var.cluster_autoscaler_namespace
  service_account = var.cluster_autoscaler_service_account
  role_arn        = aws_iam_role.cluster_autoscaler[0].arn
}
