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
  source = "../vpc_module"

  name = var.vpc_name
  cidr = var.vpc_cidr
  azs  = var.azs

  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
  database_subnets = var.database_subnets
  redshift_subnets = var.redshift_subnets
  elasticache_subnets = var.elasticache_subnets
  intra_subnets = var.intra_subnets

  enable_ipv6 = var.enable_ipv6
  public_subnet_ipv6_prefixes = var.public_subnet_ipv6_prefixes
  private_subnet_ipv6_prefixes = var.private_subnet_ipv6_prefixes
  database_subnet_ipv6_prefixes = var.database_subnet_ipv6_prefixes
  redshift_subnet_ipv6_prefixes = var.redshift_subnet_ipv6_prefixes
  elasticache_subnet_ipv6_prefixes = var.elasticache_subnet_ipv6_prefixes
  intra_subnet_ipv6_prefixes = var.intra_subnet_ipv6_prefixes

  enable_dhcp_options = var.enable_dhcp_options
  dhcp_options_domain_name = var.dhcp_options_domain_name
  dhcp_options_domain_name_servers = var.dhcp_options_domain_name_servers

  public_dedicated_network_acl = var.public_dedicated_network_acl
  private_dedicated_network_acl = var.private_dedicated_network_acl
  database_dedicated_network_acl = var.database_dedicated_network_acl
  redshift_dedicated_network_acl = var.redshift_dedicated_network_acl
  elasticache_dedicated_network_acl = var.elasticache_dedicated_network_acl
  intra_dedicated_network_acl = var.intra_dedicated_network_acl

  create_igw = var.create_igw
  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway
  create_egress_only_igw = var.create_egress_only_igw

  create_database_subnet_route_table = var.create_database_subnet_route_table
  create_database_internet_gateway_route = var.create_database_internet_gateway_route
  create_database_nat_gateway_route = var.create_database_nat_gateway_route

  create_redshift_subnet_route_table = var.create_redshift_subnet_route_table
  enable_public_redshift = var.enable_public_redshift

  create_elasticache_subnet_route_table = var.create_elasticache_subnet_route_table

  create_multiple_intra_route_tables = var.create_multiple_intra_route_tables

  enable_flow_log = var.enable_flow_log
  flow_log_destination_type = var.flow_log_destination_type
  create_flow_log_cloudwatch_log_group = var.create_flow_log_cloudwatch_log_group
  create_flow_log_cloudwatch_iam_role = var.create_flow_log_cloudwatch_iam_role

  tags = var.tags
}

# -----------------------------------------------------------------------------
# EKS Module
# -----------------------------------------------------------------------------

module "eks" {
  source = "../eks_module"

  environment = var.eks_environment
  vpc_id      = module.vpc.vpc_id
  cluster_name = var.eks_cluster_name
  subnet_ids  = module.vpc.private_subnets

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
