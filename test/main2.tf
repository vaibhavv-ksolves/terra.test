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

module "simple_vpc" {
  source = "../vpc_module" # Adjust the path if needed

  name = "simple-vpc"
  cidr = "10.0.0.0/16"
  azs  = ["ap-south-1a"] # Using only one AZ for simplicity

  public_subnets = ["10.0.1.0/24"]
  private_subnets = ["10.0.10.0/24"]

  create_igw = true
  enable_nat_gateway = false # Crucially, disable NAT

  tags = {
    Purpose = "Simple VPC Test"
  }
}

# Outputs for verification
output "vpc_id" {
  value = module.simple_vpc.vpc_id
}

output "public_subnet_id" {
  value = module.simple_vpc.public_subnets[0]
}

output "private_subnet_id" {
  value = module.simple_vpc.private_subnets[0]
}

output "igw_id" {
  value = module.simple_vpc.igw_id
}

output "public_route_table_id" {
  value = module.simple_vpc.public_route_table_ids[0]
}

# Verification (Example - Adapt as needed)
resource "null_resource" "verify_connectivity" {
  depends_on = [module.simple_vpc]

  provisioner "local-exec" {
    command = <<EOF
      #!/bin/bash
      set -e

      if [[ "${length(module.simple_vpc.public_subnets)}" != "1" ]]; then
        echo "Should have one public subnet"
        exit 1
      fi

      if [[ "${module.simple_vpc.enable_nat_gateway}" == "true" ]]; then
        echo "NAT Gateway should be disabled"
        exit 1
      fi

      echo "Simple VPC setup verified"
    EOF
  }
}
