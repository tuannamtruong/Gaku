locals {
  name = "${var.project}-${var.environment}"
}

module "ecr" {
  source = "../../modules/ecr"

  create = var.create_ecr_repositories
}

module "vpc" {
  source = "../../modules/vpc"

  name               = local.name
  cidr_block         = var.vpc_cidr
  availability_zones = var.availability_zones
  single_nat_gateway = true
  enable_flow_logs   = false
}

module "eks" {
  source = "../../modules/eks"

  name               = local.name
  cluster_version    = var.cluster_version
  private_subnet_ids = module.vpc.private_subnet_ids

  endpoint_public_access = true
  public_access_cidrs    = var.cluster_public_access_cidrs

  node_instance_types = ["t3.medium"]
  node_desired_size   = 2
  node_min_size       = 1
  node_max_size       = 3

  admin_principal_arns = var.external_deploy_role_arns
}

module "rds" {
  source = "../../modules/rds"

  name               = local.name
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  # Pods reach Postgres through the security group EKS attaches to every node.
  allowed_security_group_ids = { eks-nodes = module.eks.cluster_security_group_id }

  instance_class          = "db.t4g.micro"
  allocated_storage       = 20
  max_allocated_storage   = 50
  multi_az                = false
  backup_retention_period = 1
  deletion_protection     = false
  skip_final_snapshot     = true
}

module "in_cluster_controller_identity" {
  source = "../../modules/in-cluster-controller-identity"

  iam_name_prefix = local.name
  cluster_name    = module.eks.cluster_name
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

# The Jenkins role ARN is unknown at plan time, and the EKS module keys its access
# entries with for_each, whose keys must be known then. Granting from the root is
# what avoids that, not any dependency cycle between the two modules.
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
