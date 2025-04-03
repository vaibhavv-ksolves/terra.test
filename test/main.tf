terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0" # Or a suitable version
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0" # Or a suitable version
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "kubernetes" {
  host                  = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                 = data.aws_eks_auth.this.token
}

provider "helm" {
  kubernetes {
    host                  = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                 = data.aws_eks_auth.this.token
  }
}

data "aws_eks_auth" "this" {
  name = module.eks.cluster_name
}

# -----------------------------------------------------------------------------
# VPC Module
# -----------------------------------------------------------------------------

module "vpc" {
  source = "../vpc_module" # Adjust path if needed

  name = var.vpc_name
  cidr = var.vpc_cidr
  azs  = var.vpc_azs

  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets

  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway

  tags = var.vpc_tags
}

# -----------------------------------------------------------------------------
# EKS Module
# -----------------------------------------------------------------------------

module "eks" {
  source = "../eks_module" # Adjust path if needed

  environment = var.eks_environment
  vpc_id      = module.vpc.vpc_id # Crucial: Use VPC ID from VPC module
  cluster_name = var.eks_cluster_name
  subnet_ids  = module.vpc.private_subnets # Crucial: Use private subnets from VPC module

  enable_flow_log = var.eks_enable_flow_log
  flow_log_destination_type = var.eks_flow_log_destination_type

  tags = merge(
    var.tags,
    var.eks_tags,
  )
}

# -----------------------------------------------------------------------------
# Outputs for Verification
# -----------------------------------------------------------------------------

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_vpc_id" {
  value = module.vpc.vpc_id
}

output "eks_private_subnets" {
  value = module.vpc.private_subnets
}
