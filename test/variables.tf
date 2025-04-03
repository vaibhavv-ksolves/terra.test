variable "aws_region" {
  type        = string
  description = "AWS region to deploy resources"
  default     = "us-east-1" # You can add a default value
}

variable "vpc_name" {
  type        = string
  description = "Name of the VPC"
  default     = "my-vpc"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "azs" {
  type        = list(string)
  description = "Availability Zones"
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "public_subnets" {
  type        = list(string)
  description = "Public Subnets CIDR"
  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnets" {
  type        = list(string)
  description = "Private Subnets CIDR"
  default = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "database_subnets" {
  type = list(string)
  description = "Database Subnets CIDR"
  default = ["10.0.111.0/24", "10.0.112.0/24", "10.0.113.0/24"]
}

variable "redshift_subnets" {
  type = list(string)
  description = "Redshift subnets CIDR"
  default = ["10.0.121.0/24", "10.0.122.0/24", "10.0.123.0/24"]
}

variable "elasticache_subnets" {
  type = list(string)
  description = "Elasticache subnets CIDR"
  default = ["10.0.131.0/24", "10.0.132.0/24", "10.0.133.0/24"]
}

variable "intra_subnets" {
  type = list(string)
  description = "Intra Subnets CIDR"
  default = ["10.0.141.0/24", "10.0.142.0/24", "10.0.143.0/24"]
}

variable "enable_ipv6" {
  type = bool
  description = "Enable IPv6"
  default = false
}

variable "public_subnet_ipv6_prefixes" {
  type = list(number)
  description = "Public Subnet IPv6 Prefixes"
  default = [0, 1, 2]
}

variable "private_subnet_ipv6_prefixes" {
  type = list(number)
  description = "Private Subnet IPv6 Prefixes"
  default = [3, 4, 5]
}

variable "database_subnet_ipv6_prefixes" {
  type = list(number)
  description = "Database Subnet IPv6 Prefixes"
  default = [6, 7, 8]
}

variable "redshift_subnet_ipv6_prefixes" {
  type = list(number)
  description = "Redshift Subnet IPv6 Prefixes"
  default = [9, 10, 11]
}

variable "elasticache_subnet_ipv6_prefixes" {
  type = list(number)
  description = "Elasticache Subnet IPv6 Prefixes"
  default = [12, 13, 14]
}

variable "intra_subnet_ipv6_prefixes" {
  type = list(number)
  description = "Intra Subnet IPv6 Prefixes"
  default = [15, 16, 17]
}

variable "enable_dhcp_options" {
  type = bool
  description = "Enable DHCP Options"
  default = false
}

variable "dhcp_options_domain_name" {
  type = string
  description = "DHCP Options Domain Name"
  default = "example.com"
}

variable "dhcp_options_domain_name_servers" {
  type = list(string)
  description = "DHCP Options Domain Name Servers"
  default = ["8.8.8.8", "8.8.4.4"]
}

variable "public_dedicated_network_acl" {
  type = bool
  description = "Enable Public Dedicated Network ACL"
  default = false
}

variable "private_dedicated_network_acl" {
  type = bool
  description = "Enable Private Dedicated Network ACL"
  default = false
}

variable "database_dedicated_network_acl" {
  type = bool
  description = "Enable Database Dedicated Network ACL"
  default = false
}

variable "redshift_dedicated_network_acl" {
  type = bool
  description = "Enable Redshift Dedicated Network ACL"
  default = false
}

variable "elasticache_dedicated_network_acl" {
  type = bool
  description = "Enable Elasticache Dedicated Network ACL"
  default = false
}

variable "intra_dedicated_network_acl" {
  type = bool
  description = "Enable Intra Dedicated Network ACL"
  default = false
}

variable "create_igw" {
  type = bool
  description = "Create IGW"
  default = true
}

variable "enable_nat_gateway" {
  type = bool
  description = "Enable NAT Gateway"
  default = true
}

variable "single_nat_gateway" {
  type = bool
  description = "Enable Single NAT Gateway"
  default = false
}

variable "create_egress_only_igw" {
  type = bool
  description = "Create Egress Only IGW"
  default = false
}

variable "create_database_subnet_route_table" {
  type = bool
  description = "Create Database Subnet Route Table"
  default = true
}

variable "create_database_internet_gateway_route" {
  type = bool
  description = "Create Database Internet Gateway Route"
  default = true
}

variable "create_database_nat_gateway_route" {
  type = bool
  description = "Create Database NAT Gateway Route"
  default = true
}

variable "create_redshift_subnet_route_table" {
  type = bool
  description = "Create Redshift Subnet Route Table"
  default = true
}

variable "enable_public_redshift" {
  type = bool
  description = "Enable Public Redshift"
  default = false
}

variable "create_elasticache_subnet_route_table" {
  type = bool
  description = "Create Elasticache Subnet Route Table"
  default = true
}

variable "create_multiple_intra_route_tables" {
  type = bool
  description = "Create Multiple Intra Route Tables"
  default = false
}

variable "enable_flow_log" {
  type = bool
  description = "Enable Flow Log"
  default = false
}

variable "flow_log_destination_type" {
  type = string
  description = "Flow Log Destination Type"
  default = "cloud-watch-logs"
}

variable "create_flow_log_cloudwatch_log_group" {
  type = bool
  description = "Create Flow Log Cloudwatch Log Group"
  default = true
}

variable "create_flow_log_cloudwatch_iam_role" {
  type = bool
  description = "Create Flow Log Cloudwatch IAM Role"
  default = true
}

variable "tags" {
  type = map(string)
  description = "Tags"
  default = {
    Environment = "dev"
    Project     = "my-project"
  }
}

variable "eks_cluster_name" {
    type = string
    description = "EKS cluster name"
    default = "my-eks-cluster"
}

variable "eks_instance_type" {
    type = string
    description = "EKS node instance type"
    default = "t3.medium"
}

variable "eks_desired_capacity" {
    type = number
    description = "EKS desired capacity"
    default = 2
}

variable "eks_min_size" {
    type = number
    description = "EKS min size"
    default = 1
}

variable "eks_max_size" {
    type = number
    description = "EKS max size"
    default = 3
}

variable "eks_tags" {
    type = map(string)
    description = "EKS tags"
    default = {
      Environment = "dev"
      Project     = "my-project-eks"
    }
}
