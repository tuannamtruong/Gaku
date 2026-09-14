locals {
  name = "${var.project}-${var.environment}"
}

module "ecr" {
  source = "../../modules/ecr"

  # Reads the repositories staging created rather than making a second set.
  create = var.create_ecr_repositories
}

module "vpc" {
  source = "../../modules/vpc"

  name               = local.name
  cidr_block         = var.vpc_cidr
  availability_zones = var.availability_zones

  # One NAT per AZ: an AZ failure must not cut egress for the other two.
  single_nat_gateway = false
  enable_flow_logs   = true
}

module "eks" {
  source = "../../modules/eks"

  name               = local.name
  cluster_version    = var.cluster_version
  private_subnet_ids = module.vpc.private_subnet_ids

  endpoint_public_access = true
  public_access_cidrs    = var.cluster_public_access_cidrs

  # Audit logging costs money and is the log you want after an incident.
  enabled_cluster_log_types = ["api", "audit", "authenticator"]

  node_instance_types = ["t3.medium"]
  node_desired_size   = 3
  node_min_size       = 2
  node_max_size       = 6

  admin_principal_arns = var.external_deploy_role_arns
}

module "rds" {
  source = "../../modules/rds"

  name               = local.name
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  allowed_security_group_ids = { eks-nodes = module.eks.cluster_security_group_id }

  instance_class               = "db.t4g.small"
  allocated_storage            = 50
  max_allocated_storage        = 200
  multi_az                     = true
  backup_retention_period      = 14
  deletion_protection          = true
  skip_final_snapshot          = false
  performance_insights_enabled = true
}

module "jenkins" {
  count  = var.enable_jenkins ? 1 : 0
  source = "../../modules/jenkins-controller"

  name      = "${local.name}-jenkins"
  vpc_id    = module.vpc.vpc_id
  subnet_id = module.vpc.public_subnet_ids[0]

  instance_type     = "t3.medium"
  allowed_web_cidrs = var.jenkins_allowed_cidrs

  ecr_repository_arns = module.ecr.repository_arns
  eks_cluster_arn     = module.eks.cluster_arn
  eks_cluster_name    = module.eks.cluster_name
}

# See the same block in environments/staging - the Jenkins role ARN is unknown at
# plan time, which the EKS module's for_each-keyed access entries cannot accept.
resource "aws_eks_access_entry" "jenkins" {
  count = var.enable_jenkins ? 1 : 0

  cluster_name  = module.eks.cluster_name
  principal_arn = module.jenkins[0].iam_role_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "jenkins" {
  count = var.enable_jenkins ? 1 : 0

  cluster_name  = module.eks.cluster_name
  principal_arn = module.jenkins[0].iam_role_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.jenkins]
}
