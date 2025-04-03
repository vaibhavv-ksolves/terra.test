data "aws_partition" "current" {
  count = local.create ? 1 : 0
}
data "aws_caller_identity" "current" {
  count = local.create ? 1 : 0
}

data "aws_iam_session_context" "current" {
  count = local.create ? 1 : 0

  # This data source provides information on the IAM source role of an STS assumed role
  # For non-role ARNs, this data source simply passes the ARN through issuer ARN
  # Ref https://github.com/terraform-aws-modules/terraform-aws-eks/issues/2327#issuecomment-1355581682
  # Ref https://github.com/hashicorp/terraform-provider-aws/issues/28381
  arn = try(data.aws_caller_identity.current[0].arn, "")
}

locals {
  create = var.create && var.putin_khuylo

  partition = try(data.aws_partition.current[0].partition, "")

  cluster_role = try(aws_iam_role.this[0].arn, var.iam_role_arn)

  create_outposts_local_cluster    = length(var.outpost_config) > 0
  enable_cluster_encryption_config = length(var.cluster_encryption_config) > 0 && !local.create_outposts_local_cluster

  auto_mode_enabled = try(var.cluster_compute_config.enabled, false)
}

################################################################################
# Cluster
################################################################################

resource "aws_eks_cluster" "this" {
  count = local.create ? 1 : 0

  name                          = var.cluster_name
  role_arn                      = local.cluster_role
  version                       = var.cluster_version
  enabled_cluster_log_types     = var.cluster_enabled_log_types
  bootstrap_self_managed_addons = local.auto_mode_enabled ? coalesce(var.bootstrap_self_managed_addons, false) : var.bootstrap_self_managed_addons

  access_config {
    authentication_mode                       = var.authentication_mode

    # See access entries below - this is a one time operation from the EKS API.
    # Instead, we are hardcoding this to false and if users wish to achieve this
    # same functionality, we will do that through an access entry which can be
    # enabled or disabled at any time of their choosing using the variable
    # var.enable_cluster_creator_admin_permissions
    bootstrap_cluster_creator_admin_permissions = false
  }

  dynamic "compute_config" {
    for_each = length(var.cluster_compute_config) > 0 ? [var.cluster_compute_config] : []

    content {
      enabled     = local.auto_mode_enabled
      node_pools  = local.auto_mode_enabled ? try(compute_config.value.node_pools, []) : null
      node_role_arn = local.auto_mode_enabled && length(try(compute_config.value.node_pools, [])) > 0 ? try(compute_config.value.node_role_arn, aws_iam_role.eks_auto[0].arn, null) : null
    }
  }

  vpc_config {
    security_group_ids   = compact(distinct(concat(var.cluster_additional_security_group_ids, [local.cluster_security_group_id])))
    subnet_ids             = coalescelist(var.control_plane_subnet_ids, var.subnet_ids)
    endpoint_private_access = var.cluster_endpoint_private_access
    endpoint_public_access  = var.cluster_endpoint_public_access
    public_access_cidrs    = var.cluster_endpoint_public_access_cidrs
  }

  dynamic "kubernetes_network_config" {
    # Not valid on Outposts
    for_each = local.create_outposts_local_cluster ? [] : [1]

    content {
      dynamic "elastic_load_balancing" {
        for_each = local.auto_mode_enabled ? [1] : []

        content {
          enabled = local.auto_mode_enabled
        }
      }

      ip_family       = var.cluster_ip_family
      service_ipv4_cidr = var.cluster_service_ipv4_cidr
      service_ipv6_cidr = var.cluster_service_ipv6_cidr
    }
  }

  dynamic "outpost_config" {
    for_each = local.create_outposts_local_cluster ? [var.outpost_config] : []

    content {
      control_plane_instance_type = outpost_config.value.control_plane_instance_type
      outpost_arns                  = outpost_config.value.outpost_arns
    }
  }

  dynamic "encryption_config" {
    # Not available on Outposts
    for_each = local.enable_cluster_encryption_config ? [var.cluster_encryption_config] : []

    content {
      provider {
        key_arn = var.create_kms_key ? module.kms.key_arn : encryption_config.value.provider_key_arn
      }
      resources = encryption_config.value.resources
    }
  }

  dynamic "remote_network_config" {
    # Not valid on Outposts
    for_each = length(var.cluster_remote_network_config) > 0 && !local.create_outposts_local_cluster ? [var.cluster_remote_network_config] : []

    content {
      dynamic "remote_node_networks" {
        for_each = [remote_network_config.value.remote_node_networks]

        content {
          cidrs = remote_node_networks.value.cidrs
        }
      }

      dynamic "remote_pod_networks" {
        for_each = try([remote_network_config.value.remote_pod_networks], [])

        content {
          cidrs = remote_pod_networks.value.cidrs
        }
      }
    }
  }

  dynamic "storage_config" {
    for_each = local.auto_mode_enabled ? [1] : []

    content {
      block_storage {
        enabled = local.auto_mode_enabled
      }
    }
  }

  dynamic "upgrade_policy" {
    for_each = length(var.cluster_upgrade_policy) > 0 ? [var.cluster_upgrade_policy] : []

    content {
      support_type = try(upgrade_policy.value.support_type, null)
    }
  }

  dynamic "zonal_shift_config" {
    for_each = length(var.cluster_zonal_shift_config) > 0 ? [var.cluster_zonal_shift_config] : []

    content {
      enabled = try(zonal_shift_config.value.enabled, null)
    }
  }

  tags = merge(
    { terraform-aws-modules = "eks" },
    var.tags,
    var.cluster_tags,
  )

  timeouts {
    create = try(var.cluster_timeouts.create, null)
    update = try(var.cluster_timeouts.update, null)
    delete = try(var.cluster_timeouts.delete, null)
  }

  depends_on = [
    aws_iam_role_policy_attachment.this,
    aws_security_group_rule.cluster,
    aws_security_group_rule.node,
    aws_cloudwatch_log_group.this,
    aws_iam_policy.cni_ipv6_policy,
  ]

  lifecycle {
    ignore_changes = [
      access_config[0].bootstrap_cluster_creator_admin_permissions
    ]
  }
}

resource "aws_ec2_tag" "cluster_primary_security_group" {
  # This should not affect the name of the cluster primary security group
  # Ref: https://github.com/terraform-aws-modules/terraform-aws-eks/pull/2006
  # Ref: https://github.com/terraform-aws-modules/terraform-aws-eks/pull/2008
  for_each = { for k, v in merge(var.tags, var.cluster_tags) :
    k => v if local.create && k != "Name" && var.create_cluster_primary_security_group_tags
  }

  resource_id = aws_eks_cluster.this[0].vpc_config[0].cluster_security_group_id
  key         = each.key
  value       = each.value
}

resource "aws_cloudwatch_log_group" "this" {
  count = local.create && var.create_cloudwatch_log_group ? 1 : 0

  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.cloudwatch_log_group_retention_in_days
  kms_key_id        = var.cloudwatch_log_group_kms_key_id
  log_group_class   = var.cloudwatch_log_group_class

  tags = merge(
    var.tags,
    var.cloudwatch_log_group_tags,
    { Name = "/aws/eks/${var.cluster_name}/cluster" }
  )
}

################################################################################
# Access Entry
################################################################################

locals {
  # This replaces the one time logic from the EKS API with something that can be
  # better controlled by users through Terraform
  bootstrap_cluster_creator_admin_permissions = {
    cluster_creator = {
      principal_arn   = try(data.aws_iam_session_context.current[0].issuer_arn, "")
      type            = "STANDARD"

      policy_associations = {
        admin = {
          policy_arn = "arn:${local.partition}:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  # Merge the bootstrap behavior with the entries that users provide
  merged_access_entries = merge(
    { for k, v in local.bootstrap_cluster_creator_admin_permissions : k => v if var.enable_cluster_creator_admin_permissions },
    var.access_entries,
  )

  # Flatten out entries and policy associations so users can specify the policy
  # associations within a single entry
  flattened_access_entries = flatten([
    for entry_key, entry_val in local.merged_access_entries : [
      for pol_key, pol_val in lookup(entry_val, "policy_associations", {}) :
      merge(
        {
          principal_arn = entry_val.principal_arn
          entry_key     = entry_key
          pol_key       = pol_key
        },
        { for k, v in {
          association_policy_arn            = pol_val.policy_arn
          association_access_scope_type     = pol_val.access_scope.type
          association_access_scope_namespaces = lookup(pol_val.access_scope, "namespaces", [])
        } : k => v if !contains(["EC2_LINUX", "EC2_WINDOWS", "FARGATE_LINUX", "HYBRID_LINUX"], lookup(entry_val, "type", "STANDARD")) },
      )
    ]
  ])
}

resource "aws_eks_access_entry" "this" {
  for_each = { for k, v in local.merged_access_entries : k => v if local.create }

  cluster_name    = aws_eks_cluster.this[0].id
  kubernetes_groups = try(each.value.kubernetes_groups, null)
  principal_arn   = each.value.principal_arn
  type            = try(each.value.type, "STANDARD")
  user_name       = try(each.value.user_name, null)

  tags = merge(var.tags, try(each.value.tags, {}))
}

resource "aws_eks_access_policy_association" "this" {
  for_each = { for k, v in local.flattened_access_entries : "${v.entry_key}_${v.pol_key}" => v if local.create }

  access_scope {
    namespaces = try(each.value.association_access_scope_namespaces, [])
    type       = each.value.association_access_scope_type
  }

  cluster_name  = aws_eks_cluster.this[0].id

  policy_arn    = each.value.association_policy_arn
  principal_arn = each.value.principal_arn

  depends_on = [
    aws_eks_access_entry.this,
  ]
}

################################################################################
# KMS Key
################################################################################

module "kms" {
  source  = "terraform-aws-modules/kms/aws"
  version = "2.1.0" # Note - be mindful of Terraform/provider version compatibility between modules

  create = local.create && var.create_kms_key && local.enable_cluster_encryption_config # not valid on Outposts

  description             = coalesce(var.kms_key_description, "${var.cluster_name} cluster encryption key")
  key_usage               = "ENCRYPT_DECRYPT"
  deletion_window_in_days = var.kms_key_deletion_window_in_days
  enable_key_rotation     = var.enable_kms_key_rotation

  # Policy
  enable_default_policy   = var.kms_key_enable_default_policy
  key_owners              = var.kms_key_owners
  key_administrators      = coalescelist(var.kms_key_administrators, [try(data.aws_iam_session_context.current[0].issuer_arn, "")])
  key_users               = concat([local.cluster_role], var.kms_key_users)
  key_service_users       = var.kms_key_service_users
  source_policy_documents   = var.kms_key_source_policy_documents
  override_policy_documents = var.kms_key_override_policy_documents

  # Aliases
  aliases         = var.kms_key_aliases
  computed_aliases = {
    # Computed since users can pass in computed values for cluster name such as random provider resources
    cluster = { name = "eks/${var.cluster_name}" }
  }

  tags = merge(
    { terraform-aws-modules = "eks" },
    var.tags,
  )
}

################################################################################
# Cluster Security Group
# Defaults follow https://docs.aws.amazon.com/eks/latest/userguide/sec-group-reqs.html
################################################################################

locals {
  cluster_sg_name          = coalesce(var.cluster_security_group_name, "${var.cluster_name}-cluster")
  create_cluster_sg        = local.create && var.create_cluster_security_group

  cluster_security_group_id = local.create_cluster_sg ? aws_security_group.cluster[0].id : var.cluster_security_group_id

  # Do not add rules to node security group if the module is not creating it
  cluster_security_group_rules = { for k, v in {
    ingress_nodes_443 = {
      description          = "Node groups to cluster API"
      protocol             = "tcp"
      from_port            = 443
      to_port              = 443
      type                 = "ingress"
      source_node_security_group = true
    }
  } : k => v if local.create_node_sg }
}

resource "aws_security_group" "cluster" {
  count = local.create_cluster_sg ? 1 : 0

  name        = var.cluster_security_group_use_name_prefix ? null : local.cluster_sg_name
  name_prefix = var.cluster_security_group_use_name_prefix ? "${local.cluster_sg_name}${var.prefix_separator}" : null
  description = var.cluster_security_group_description
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    { "Name" = local.cluster_sg_name },
    var.cluster_security_group_tags
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "cluster" {
  for_each = { for k, v in merge(
    local.cluster_security_group_rules,
    var.cluster_security_group_additional_rules
  ) : k => v if local.create_cluster_sg }

  # Required
  security_group_id = aws_security_group.cluster[0].id
  protocol          = each.value.protocol
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  type              = each.value.type

  # Optional
  description             = lookup(each.value, "description", null)
  cidr_blocks             = lookup(each.value, "cidr_blocks", null)
  ipv6_cidr_blocks        = lookup(each.value, "ipv6_cidr_blocks", null)
  prefix_list_ids         = lookup(each.value, "prefix_list_ids", null)
  self                    = lookup(each.value, "self", null)
  source_security_group_id = try(each.value.source_node_security_group, false) ? local.node_security_group_id : lookup(each.value, "source_security_group_id", null)
}

################################################################################
# EKS Auto Node IAM Role
################################################################################

locals {
  create_node_iam_role = local.create && var.create_node_iam_role && local.auto_mode_enabled
  node_iam_role_name   = coalesce(var.node_iam_role_name, "${var.cluster_name}-eks-auto")
}

data "aws_iam_policy_document" "node_assume_role_policy" {
  count = local.create_node_iam_role ? 1 : 0

  statement {
    sid    = "EKSAutoNodeAssumeRole"
    actions = [
      "sts:AssumeRole",
      "sts:TagSession",
    ]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_auto" {
  count = local.create_node_iam_role ? 1 : 0

  name        = var.node_iam_role_use_name_prefix ? null : local.node_iam_role_name
  name_prefix = var.node_iam_role_use_name_prefix ? "${local.node_iam_role_name}-" : null
  path        = var.node_iam_role_path
  description = var.node_iam_role_description

  assume_role_policy   = data.aws_iam_policy_document.node_assume_role_policy[0].json
  permissions_boundary = var.node_iam_role_permissions_boundary
  force_detach_policies = true

  tags = merge(var.tags, var.node_iam_role_tags)
}

# Policies attached ref https://docs.aws.amazon.com/eks/latest/userguide/service_IAM_role.html
resource "aws_iam_role_policy_attachment" "eks_auto" {
  for_each = { for k, v in {
    AmazonEKSWorkerNodeMinimalPolicy     = "${local.iam_role_policy_prefix}/AmazonEKSWorkerNodeMinimalPolicy",
    AmazonEC2ContainerRegistryPullOnly = "${local.iam_role_policy_prefix}/AmazonEC2ContainerRegistryPullOnly",
  } : k => v if local.create_node_iam_role }

  policy_arn = each.value
  role       = aws_iam_role.eks_auto[0].name
}

resource "aws_iam_role_policy_attachment" "eks_auto_additional" {
  for_each = { for k, v in var.node_iam_role_additional_policies : k => v if local.create_node_iam_role }

  policy_arn = each.value
  role       = aws_iam_role.eks_auto[0].name
}

################################################################################
# EKS Managed Node Group
################################################################################

module "eks_managed_node_group" {
  source  = "./modules/eks-managed-node-group"
  version = "19.6.0"

  create = local.create && var.create_eks_managed_node_group

  cluster_name    = aws_eks_cluster.this[0].name
  cluster_version = aws_eks_cluster.this[0].version
  name            = var.eks_managed_node_group_name
  node_group_name_prefix = var.eks_managed_node_group_name_prefix
  node_role_arn   = aws_iam_role.eks_auto[0].arn
  subnet_ids      = var.subnet_ids

  launch_template = var.eks_managed_node_group_launch_template

  autoscaling_group_tags = var.eks_managed_node_group_autoscaling_group_tags
  capacity_type          = var.eks_managed_node_group_capacity_type
  disk_size              = var.eks_managed_node_group_disk_size
  force_update_version   = var.eks_managed_node_group_force_update_version
  instance_types         = var.eks_managed_node_group_instance_types
  labels                 = var.eks_managed_node_group_labels
  release_version        = var.eks_managed_node_group_release_version
  scaling_config         = var.eks_managed_node_group_scaling_config
  scheduling_config      = var.eks_managed_node_group_scheduling_config
  taints                 = var.eks_managed_node_group_taints

  update_config = var.eks_managed_node_group_update_config

  remote_access = var.eks_managed_node_group_remote_access

  tags = merge(
    { terraform-aws-modules = "eks" },
    var.tags,
    var.eks_managed_node_group_tags,
  )

  depends_on = [
    aws_eks_cluster.this,
    aws_iam_role.eks_auto,
    aws_iam_role_policy_attachment.eks_auto,
  ]

  timeouts = var.eks_managed_node_group_timeouts
}

################################################################################
# Self Managed Node Group
################################################################################

module "self_managed_node_group" {
  source  = "./modules/self-managed-node-group"
  version = "5.1.0"

  create = local.create && var.create_self_managed_node_group

  cluster_name    = aws_eks_cluster.this[0].name
  cluster_version = aws_eks_cluster.this[0].version
  name            = var.self_managed_node_group_name
  name_prefix     = var.self_managed_node_group_name_prefix
  node_role_arn   = aws_iam_role.eks_auto[0].arn
  subnet_ids      = var.subnet_ids

  ami_type                = var.self_managed_node_group_ami_type
  ami_release_version     = var.self_managed_node_group_ami_release_version
  capacity_type           = var.self_managed_node_group_capacity_type
  disk_size               = var.self_managed_node_group_disk_size
  force_update            = var.self_managed_node_group_force_update
  instance_initiated_shutdown_behavior = var.self_managed_node_group_instance_initiated_shutdown_behavior
  instance_type           = var.self_managed_node_group_instance_type
  key_name                = var.self_managed_node_group_key_name
  launch_template_name_prefix = var.self_managed_node_group_launch_template_name_prefix
  max_size                = var.self_managed_node_group_max_size
  min_size                = var.self_managed_node_group_min_size
  node_labels             = var.self_managed_node_group_node_labels
  node_security_group_ids = var.self_managed_node_group_node_security_group_ids
  node_taints             = var.self_managed_node_group_node_taints
  scaling_policy           = var.self_managed_node_group_scaling_policy
  security_group_rules    = var.self_managed_node_group_security_group_rules
  security_group_tags     = var.self_managed_node_group_security_group_tags
  security_group_use_name_prefix = var.self_managed_node_group_security_group_use_name_prefix
  security_groups_max_count = var.self_managed_node_group_security_groups_max_count
  security_groups_per_interface = var.self_managed_node_group_security_groups_per_interface
  security_groups_use_separate_rule = var.self_managed_node_group_security_group_use_name_rule
  source_ami_filters      = var.self_managed_node_group_source_ami_filters
  source_ami_owners       = var.self_managed_node_group_source_ami_owners
  source_ami_name_regex   = var.self_managed_node_group_source_ami_name_regex
  source_ami_most_recent  = var.self_managed_node_group_source_ami_most_recent
  source_ami_id           = var.self_managed_node_group_source_ami_id
  spot_instance_pools     = var.self_managed_node_group_spot_instance_pools
  spot_price              = var.self_managed_node_group_spot_price
  tags                    = merge(
    { terraform-aws-modules = "eks" },
    var.tags,
    var.self_managed_node_group_tags,
  )
  update_default_version  = var.self_managed_node_group_update_default_version
  use_name_prefix         = var.self_managed_node_group_use_name_prefix

  depends_on = [
    aws_eks_cluster.this,
    aws_iam_role.eks_auto,
    aws_iam_role_policy_attachment.eks_auto,
  ]

  timeouts = var.self_managed_node_group_timeouts
}

################################################################################
# Fargate Profile
################################################################################

module "fargate_profile" {
  source  = "./modules/fargate-profile"
  version = "1.0.0"

  create = local.create && var.create_fargate_profile

  cluster_name    = aws_eks_cluster.this[0].name
  name            = var.fargate_profile_name
  name_prefix     = var.fargate_profile_name_prefix
  pod_execution_role_arn = var.fargate_profile_pod_execution_role_arn
  selectors       = var.fargate_profile_selectors
  subnet_ids      = var.subnet_ids

  tags = merge(
    { terraform-aws-modules = "eks" },
    var.tags,
    var.fargate_profile_tags,
  )

  depends_on = [
    aws_eks_cluster.this,
  ]

  timeouts = var.fargate_profile_timeouts
}
