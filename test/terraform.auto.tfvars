aws_region = "us-east-1"

vpc_name = "test-prod-vpc"
vpc_cidr = "10.10.0.0/16"
azs      = ["us-east-1a", "us-east-1b"]

public_subnets  = ["10.10.1.0/24", "10.10.2.0/24"]
private_subnets = ["10.10.11.0/24", "10.10.12.0/24"]
database_subnets = ["10.10.21.0/24", "10.10.22.0/24"]

eks_cluster_name    = "test-prod-eks"
eks_cluster_version = "1.29"

tags = {
  Environment = "production"
  Project     = "test"
}

allowed_ssh_cidrs = ["0.0.0.0/0"] # Consider limiting this for security
