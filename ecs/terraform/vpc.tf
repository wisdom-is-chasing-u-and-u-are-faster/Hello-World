##############################################
# VPC for the ECS demo
#
# Public subnets only, no NAT Gateway. Fargate
# tasks run with a public IP (assign_public_ip
# = true in ecs.tf), which is enough to pull
# the public images and call the S3 API. This
# keeps the demo's networking cost at ~$0
# (a NAT Gateway alone runs ~$32+/month).
##############################################
data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.8"

  name = "${var.project_name}-vpc"
  cidr = var.vpc_cidr

  azs            = slice(data.aws_availability_zones.available.names, 0, 2)
  public_subnets = [cidrsubnet(var.vpc_cidr, 8, 0), cidrsubnet(var.vpc_cidr, 8, 1)]

  enable_nat_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Project  = "aws-to-gcp-migration-demo"
    Workload = var.project_name
  }
}
