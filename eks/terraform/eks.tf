##############################################
# EKS cluster + managed node group
# Uses the official AWS EKS module.
##############################################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.24"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  # Public endpoint so you can run kubectl from your laptop for the demo.
  cluster_endpoint_public_access = true

  # Give the identity that runs terraform admin access on the cluster,
  # so kubectl works immediately after apply.
  enable_cluster_creator_admin_permissions = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    default = {
      instance_types = [var.instance_type]
      min_size       = var.min_size
      max_size       = var.max_size
      desired_size   = var.desired_size
    }
  }

  tags = {
    Project = "aws-to-gcp-migration-demo"
    Workload = "hello-eks"
  }
}
