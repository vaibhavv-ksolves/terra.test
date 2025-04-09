terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }

  required_version = ">= 1.3.0"
}

provider "aws" {
  region = var.aws_region
}

# -----------------------------------------------------------------------------
# VPC MODULE
# -----------------------------------------------------------------------------

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.1.1"

  name = var.vpc_name
  cidr = var.vpc_cidr
  azs  = var.azs

  public_subnets   = var.public_subnets
  private_subnets  = var.private_subnets
  database_subnets = var.database_subnets

  enable_dns_support   = true
  enable_dns_hostnames = true

  create_igw            = true
  enable_nat_gateway    = true
  single_nat_gateway    = false
  one_nat_gateway_per_az = true

  manage_default_security_group = false
  manage_default_network_acl    = false

  enable_flow_log                       = true
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role  = true
  flow_log_destination_type             = "cloud-watch-logs"

  tags = var.tags
}

# -----------------------------------------------------------------------------
# VPC ENDPOINTS MODULE
# -----------------------------------------------------------------------------

module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "~> 5.1.1"

  vpc_id = module.vpc.vpc_id

  endpoints = {
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = module.vpc.private_route_table_ids
      tags = {
        Name = "s3-endpoint"
      }
    }

    dynamodb = {
      service         = "dynamodb"
      service_type    = "Gateway"
      route_table_ids = module.vpc.private_route_table_ids
      tags = {
        Name = "dynamodb-endpoint"
      }
    }
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# IAM ROLE FOR EKS CLUSTER
# -----------------------------------------------------------------------------

resource "aws_iam_role" "eks_cluster_role" {
  name = "${var.eks_cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })

  tags = var.tags
}

resource "aws_iam_policy_attachment" "eks_cluster_policy_attachment" {
  name       = "eks-cluster-policy-attachment"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  roles      = [aws_iam_role.eks_cluster_role.name]
}

resource "aws_iam_policy_attachment" "eks_vpc_cni_policy_attachment" {
  name       = "eks-vpc-cni-policy-attachment"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  roles      = [aws_iam_role.eks_cluster_role.name]
}

# -----------------------------------------------------------------------------
# IAM ROLE FOR EKS NODE GROUP
# -----------------------------------------------------------------------------

resource "aws_iam_role" "eks_node_group_role" {
  name = "${var.eks_cluster_name}-nodegroup-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })

  tags = var.tags
}

resource "aws_iam_policy_attachment" "eks_node_group_policy_attachment" {
  name       = "eks-node-group-policy-attachment"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  roles      = [aws_iam_role.eks_node_group_role.name]
}

resource "aws_iam_policy_attachment" "eks_node_group_cni_policy_attachment" {
  name       = "eks-node-group-cni-policy-attachment"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  roles      = [aws_iam_role.eks_node_group_role.name]
}

resource "aws_iam_policy_attachment" "eks_node_group_ecr_readonly_policy_attachment" {
  name       = "eks-node-group-ecr-readonly-policy-attachment"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  roles      = [aws_iam_role.eks_node_group_role.name]
}

# -----------------------------------------------------------------------------
# EKS SECURITY GROUP
# -----------------------------------------------------------------------------

resource "aws_security_group" "eks_cluster_sg" {
  name_prefix = "${var.eks_cluster_name}-cluster-sg-"
  vpc_id      = module.vpc.vpc_id

  tags = var.tags
}

resource "aws_security_group_rule" "eks_cluster_sg_allow_https_from_public" {
  type             = "ingress"
  protocol         = "tcp"
  from_port        = 443
  to_port          = 443
  cidr_blocks      = ["0.0.0.0/0"]
  security_group_id = aws_security_group.eks_cluster_sg.id
}

resource "aws_security_group_rule" "eks_cluster_sg_allow_kubelet_from_nodes" {
  type             = "ingress"
  protocol         = "tcp"
  from_port        = 10250
  to_port          = 10250
  security_group_id = aws_security_group.eks_cluster_sg.id
  source_security_group_id = aws_security_group.eks_node_group_sg.id
}

resource "aws_security_group_rule" "eks_cluster_sg_allow_control_plane_to_nodes" {
  type             = "ingress"
  protocol         = "tcp"
  from_port        = 1025-65535
  to_port          = 65535
  security_group_id = aws_security_group.eks_cluster_sg.id
  source_security_group_id = aws_security_group.eks_node_group_sg.id
}

resource "aws_security_group_rule" "eks_cluster_sg_allow_all_outbound" {
  type             = "egress"
  protocol         = "-1"
  from_port        = 0
  to_port          = 0
  cidr_blocks      = ["0.0.0.0/0"]
  security_group_id = aws_security_group.eks_cluster_sg.id
}

# -----------------------------------------------------------------------------
# EKS NODE GROUP SECURITY GROUP
# -----------------------------------------------------------------------------

resource "aws_security_group" "eks_node_group_sg" {
  name_prefix = "${var.eks_cluster_name}-nodegroup-sg-"
  vpc_id      = module.vpc.vpc_id

  tags = var.tags
}

resource "aws_security_group_rule" "eks_node_group_sg_allow_kubelet_from_control_plane" {
  type             = "ingress"
  protocol         = "tcp"
  from_port        = 1025-65535
  to_port          = 65535
  security_group_id = aws_security_group.eks_node_group_sg.id
  source_security_group_id = aws_security_group.eks_cluster_sg.id
}

resource "aws_security_group_rule" "eks_node_group_sg_allow_ssh" {
  type        = "ingress"
  protocol    = "tcp"
  from_port   = 22
  to_port     = 22
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.eks_node_group_sg.id
}

resource "aws_security_group_rule" "eks_node_group_sg_allow_all_outbound" {
  type             = "egress"
  protocol         = "-1"
  from_port        = 0
  to_port          = 0
  cidr_blocks      = ["0.0.0.0/0"]
  security_group_id = aws_security_group.eks_node_group_sg.id
}

# -----------------------------------------------------------------------------
# EKS MODULE
# -----------------------------------------------------------------------------

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.eks_cluster_name
  cluster_version = var.eks_cluster_version
  cluster_endpoint_public_access = true

  vpc_id    = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_security_group_id = aws_security_group.eks_cluster_sg.id

  eks_managed_node_groups = {
    ng1 = {
      name           = "default-node-group"
      instance_types = ["t3.medium"]
      desired_size   = 2
      min_size       = 1
      max_size       = 3

      subnet_ids = module.vpc.private_subnets

      node_group_role_arn = aws_iam_role.eks_node_group_role.arn
      node_security_group_ids = [aws_security_group.eks_node_group_sg.id]

      tags = var.tags
    }
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# KUBECONFIG OUTPUT
# -----------------------------------------------------------------------------

output "kubeconfig" {
  value = yamlencode({
    apiVersion = "v1"
    kind       = "Config"
    clusters = [{
      name = var.eks_cluster_name
      cluster = {
        server                   = module.eks.cluster_endpoint
        certificate-authority-data = module.eks.cluster_certificate_authority_data
      }
    }]
    users = [{
      name = "aws"
      user = {
        exec = {
          apiVersion = "client.authentication.k8s.io/v1beta1"
          command    = "aws"
          args = [
            "eks", "get-token",
            "--cluster-name", var.eks_cluster_name
          ]
        }
      }
    }]
    contexts = [{
      name    = "aws"
      context = {
        cluster = var.eks_cluster_name
        user    = "aws"
      }
    }]
    current-context = "aws"
  })
}

# -----------------------------------------------------------------------------
# PROVIDER CONFIGURATION FOR HELM & K8S
# -----------------------------------------------------------------------------

provider "kubernetes" {
  alias                  = "eks"
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec = {
    apiVersion = "client.authentication.k8s.io/v1beta1"
    command    = "aws"
    args = [
      "eks", "get-token",
      "--cluster-name", var.eks_cluster_name
    ]
  }
}

provider "helm" {
  alias = "eks"

  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks", "get-token",
        "--cluster-name", var.eks_cluster_name
      ]
    }
  }
}

# -----------------------------------------------------------------------------
# NGINX INGRESS CONTROLLER INSTALLATION
# -----------------------------------------------------------------------------

resource "helm_release" "nginx_ingress" {
  provider    = helm.eks
  name        = "nginx-ingress"
  namespace   = "kube-system"
  repository  = "https://kubernetes.github.io/ingress-nginx"
  chart       = "ingress-nginx"
  version     = "4.10.0"

  values = [
    yamlencode({
      controller = {
        replicaCount = 2
        service = {
          type = "LoadBalancer"
          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
          }
        }
      }
    })
  ]

  depends_on = [module.eks]
}
