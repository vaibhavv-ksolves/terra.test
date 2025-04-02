terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Or your preferred version
    }
  }
}

provider "aws" {
  region = "ap-south-1" # Or your AWS region
}

module "test_vpc" {
  source = "/home/ubuntu/terraform/vpc_module"

  name = "comprehensive-test-vpc"
  cidr = "10.10.0.0/16"
  azs  = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]

  public_subnets  = ["10.10.1.0/24", "10.10.2.0/24", "10.10.3.0/24"]
  private_subnets = ["10.10.11.0/24", "10.10.12.0/24", "10.10.13.0/24"]
  database_subnets = ["10.10.21.0/24", "10.10.22.0/24", "10.10.23.0/24"]
  redshift_subnets = ["10.10.31.0/24", "10.10.32.0/24", "10.10.33.0/24"]
  elasticache_subnets = ["10.10.41.0/24", "10.10.42.0/24", "10.10.43.0/24"]
  intra_subnets = ["10.10.51.0/24", "10.10.52.0/24", "10.10.53.0/24"]

  enable_ipv6 = true
  public_subnet_ipv6_prefixes = ["0", "1", "2"]
  private_subnet_ipv6_prefixes = ["10", "11", "12"]
  database_subnet_ipv6_prefixes = ["20", "21", "22"]
  redshift_subnet_ipv6_prefixes = ["30", "31", "32"]
  elasticache_subnet_ipv6_prefixes = ["40", "41", "42"]
  intra_subnet_ipv6_prefixes = ["50", "51", "52"]

  enable_dhcp_options = true
  dhcp_options_domain_name = "test.local"
  dhcp_options_domain_name_servers = ["10.10.0.2", "10.10.0.3"]

  public_dedicated_network_acl = true
  private_dedicated_network_acl = true
  database_dedicated_network_acl = true
  redshift_dedicated_network_acl = true
  elasticache_dedicated_network_acl = true
  intra_dedicated_network_acl = true

  create_igw = true
  enable_nat_gateway = true
  single_nat_gateway = false
  create_egress_only_igw = true

  create_database_subnet_route_table = true
  create_database_internet_gateway_route = false
  create_database_nat_gateway_route = true

  create_redshift_subnet_route_table = true
  enable_public_redshift = false

  create_elasticache_subnet_route_table = true

  create_multiple_intra_route_tables = true

  enable_flow_log = true # Enable flow logs for testing
  flow_log_destination_type = "cloud-watch-logs"
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role = true

  tags = {
    Environment = "ComprehensiveTest"
  }
}

# Outputs for verification
output "test_vpc_id" {
  value = module.test_vpc.vpc_id
}

output "test_public_subnets" {
  value = module.test_vpc.public_subnets
}

output "test_private_subnets" {
  value = module.test_vpc.private_subnets
}

output "test_database_subnets" {
  value = module.test_vpc.database_subnets
}

output "test_redshift_subnets" {
  value = module.test_vpc.redshift_subnets
}

output "test_elasticache_subnets" {
  value = module.test_vpc.elasticache_subnets
}

output "test_intra_subnets" {
  value = module.test_vpc.intra_subnets
}

output "test_public_route_table_ids" {
  value = module.test_vpc.public_route_table_ids
}

output "test_private_route_table_ids" {
  value = module.test_vpc.private_route_table_ids
}

output "test_database_route_table_ids" {
  value = module.test_vpc.database_route_table_ids
}

output "test_nat_gateway_ids" {
  value = module.test_vpc.natgw_ids
}

output "test_egress_only_internet_gateway_id" {
  value = module.test_vpc.egress_only_internet_gateway_id
}

output "test_dhcp_options_id" {
  value = module.test_vpc.dhcp_options_id
}

# Flow Log Verification Outputs
output "test_enable_flow_log" {
  value = module.test_vpc.enable_flow_log
}

output "test_flow_log_destination_type" {
  value = module.test_vpc.flow_log_destination_type
}

output "test_flow_log_destination_arn" {
  value = module.test_vpc.flow_log_destination_arn
  sensitive = true # Important: These might contain sensitive data
}

output "test_create_flow_log_cloudwatch_log_group" {
  value = module.test_vpc.create_flow_log_cloudwatch_log_group
}

output "test_create_flow_log_cloudwatch_iam_role" {
  value = module.test_vpc.create_flow_log_cloudwatch_iam_role
}

# Verification (Example - Adapt as needed)
resource "null_resource" "verify_flow_logs" {
  depends_on = [module.test_vpc]

  provisioner "local-exec" {
    command = <<EOF
      #!/bin/bash
      set -e # Exit immediately if a command exits with a non-zero status.

      if [[ "${module.test_vpc.enable_flow_log}" != "true" ]]; then
        echo "Flow logs should be enabled!"
        exit 1
      fi

      if [[ "${module.test_vpc.flow_log_destination_type}" != "cloud-watch-logs" ]]; then
        echo "Flow log destination type should be cloud-watch-logs!"
        exit 1
      fi

      if [[ "${module.test_vpc.create_flow_log_cloudwatch_log_group}" != "true" ]]; then
        echo "CloudWatch Log Group creation should be enabled!"
        exit 1
      fi

      if [[ "${module.test_vpc.create_flow_log_cloudwatch_iam_role}" != "true" ]]; then
        echo "IAM Role creation for CloudWatch should be enabled!"
        exit 1
      fi

      echo "Flow log settings verified!"
    EOF
  }
}
