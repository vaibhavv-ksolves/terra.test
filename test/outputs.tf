output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnet_ids" {
  value = module.vpc.private_subnets
}

output "eks_cluster_id" {
  value = module.eks.cluster_id
}


output "eks_cluster_security_group_id" {
  value = module.eks.cluster_security_group_id
}

