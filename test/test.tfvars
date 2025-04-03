aws_region = "ap-south-1"

vpc_name = "comprehensive-test-vpc"
vpc_cidr = "10.10.0.0/16"
azs = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]

public_subnets = ["10.10.1.0/24", "10.10.2.0/24", "10.10.3.0/24"]
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

enable_flow_log = true
flow_log_destination_type = "cloud-watch-logs"
create_flow_log_cloudwatch_log_group = true
create_flow_log_cloudwatch_iam_role = true

tags = {
  Environment = "ComprehensiveTest"
}

eks_environment = "comprehensive-test"
eks_cluster_name = "comprehensive-test-eks"
eks_enable_flow_log = false # Or true, as needed
eks_flow_log_destination_type = "cloud-watch-logs"
eks_tags = {
  Name = "comprehensive-test-eks"
}
