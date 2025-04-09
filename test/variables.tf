variable "aws_region" {
  type        = string
  description = "The AWS region to deploy resources in"
}

variable "vpc_name" {
  type        = string
  description = "Name of the VPC"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
}

variable "azs" {
  type        = list(string)
  description = "List of availability zones"
}

variable "public_subnets" {
  type        = list(string)
  description = "List of public subnet CIDRs"
}

variable "private_subnets" {
  type        = list(string)
  description = "List of private subnet CIDRs"
}

variable "database_subnets" {
  type        = list(string)
  description = "List of database subnet CIDRs"
}

variable "eks_cluster_name" {
  type        = string
  description = "Name of the EKS cluster"
}

variable "eks_cluster_version" {
  type        = string
  description = "EKS cluster version"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
}

variable "allowed_ssh_cidrs" {
  description = "List of allowed CIDR blocks for SSH access"
  type        = list(string)
  default     = []
}
