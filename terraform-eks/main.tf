# ========================================
# ROOT MODULE - MODULAR STRUCTURE
# ========================================
# Enterprise-level structure with separate modules

# ========================================
# PROVIDER CONFIGURATION
# ========================================
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.common_tags
  }
}

# ========================================
# VPC MODULE
# ========================================
module "vpc" {
  source = "./modules/vpc"

  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
  nat_gateway_count    = var.nat_gateway_count
  cluster_name         = var.cluster_name
  common_tags          = var.common_tags
}

# ========================================
# IAM MODULE
# ========================================
module "iam" {
  source = "./modules/iam"
  
  cluster_name = var.cluster_name
  common_tags  = var.common_tags
}

# ========================================
# SECURITY GROUPS MODULE
# ========================================
module "security_groups" {
  source = "./modules/security-groups"
  
  cluster_name            = var.cluster_name
  vpc_id                  = module.vpc.vpc_id
  enable_node_ssh_access  = var.enable_node_ssh_access
  ssh_allowed_cidr_blocks = var.ssh_allowed_cidr_blocks
  common_tags             = var.common_tags
}

# ========================================
# EKS MODULE
# ========================================
module "eks" {
  source = "./modules/eks"
  
  cluster_name                         = var.cluster_name
  cluster_version                      = var.cluster_version
  cluster_role_arn                     = module.iam.cluster_role_arn
  subnet_ids                           = concat(module.vpc.private_subnet_ids, module.vpc.public_subnet_ids)
  cluster_security_group_id            = module.security_groups.cluster_security_group_id
  cluster_endpoint_public_access       = var.cluster_endpoint_public_access
  cluster_endpoint_private_access      = var.cluster_endpoint_private_access
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs
  cluster_enabled_log_types            = var.cluster_enabled_log_types
  cluster_log_retention_days           = var.cluster_log_retention_days
  vpc_cni_version                      = var.vpc_cni_version
  coredns_version                      = var.coredns_version
  kube_proxy_version                   = var.kube_proxy_version
  enable_cluster_addons                = var.enable_cluster_addons
  common_tags                          = var.common_tags
  
  depends_on = [module.iam, module.security_groups]
}

# ========================================
# NODE GROUPS MODULE
# ========================================
module "node_groups" {
  source = "./modules/node-groups"
  
  cluster_name              = var.cluster_name
  cluster_version           = var.cluster_version
  node_group_name           = var.node_group_name
  node_role_arn             = module.iam.node_role_arn
  subnet_ids                = module.vpc.private_subnet_ids
  node_group_desired_size   = var.node_group_desired_size
  node_group_min_size       = var.node_group_min_size
  node_group_max_size       = var.node_group_max_size
  node_group_instance_types = var.node_group_instance_types
  node_group_capacity_type  = var.node_group_capacity_type
  node_group_disk_size      = var.node_group_disk_size
  node_group_ami_type       = var.node_group_ami_type
  node_group_labels         = var.node_group_labels
  node_group_taints         = var.node_group_taints
  enable_node_ssh_access    = var.enable_node_ssh_access
  node_ssh_key_name         = var.node_ssh_key_name
  common_tags               = var.common_tags
  
  depends_on = [module.eks]
}

# ========================================
# EKS ADDONS MODULE
# ========================================
module "eks_addons" {
  source = "./modules/eks-addons"

  cluster_name              = var.cluster_name
  enable_cluster_addons     = var.enable_cluster_addons
  vpc_cni_version           = var.vpc_cni_version
  coredns_version           = var.coredns_version
  kube_proxy_version        = var.kube_proxy_version
  ebs_csi_driver_version    = var.ebs_csi_driver_version
  ebs_csi_driver_role_arn   = aws_iam_role.ebs_csi_driver.arn
  common_tags               = var.common_tags

  depends_on = [module.eks, module.node_groups, aws_iam_role.ebs_csi_driver]
}

# ========================================
# EBS CSI DRIVER IAM ROLE (IRSA)
# ========================================
data "aws_iam_policy_document" "ebs_csi_driver_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_provider_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_provider_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi_driver" {
  name               = "${var.cluster_name}-ebs-csi-driver-role"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_driver_assume_role.json

  tags = var.common_tags
  
  depends_on = [module.eks]
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_driver.name
}

# ========================================
# ALB CONTROLLER MODULE
# ========================================
module "alb_controller" {
  source = "./modules/alb-controller"
  
  cluster_name                        = var.cluster_name
  oidc_provider_arn                   = module.eks.oidc_provider_arn
  oidc_provider_url                   = module.eks.oidc_provider_url
  enable_aws_load_balancer_controller = var.enable_aws_load_balancer_controller
  common_tags                         = var.common_tags
  
  depends_on = [module.eks]
}

# ========================================
# EXTERNAL DNS MODULE
# ========================================
module "external_dns" {
  source = "./modules/external-dns"
  
  cluster_name        = var.cluster_name
  oidc_provider_arn   = module.eks.oidc_provider_arn
  oidc_provider_url   = module.eks.oidc_provider_url
  enable_external_dns = var.enable_external_dns
  route53_zone_arns   = var.route53_zone_arns
  common_tags         = var.common_tags
  
  depends_on = [module.eks]
}

# ========================================
# ROUTE53 MODULE
# ========================================
module "route53" {
  source = "./modules/route53"
  
  domain_name             = var.domain_name
  create_dns_records      = var.create_dns_records
  argocd_enabled          = var.argocd_dns_enabled
  argocd_alb_dns_name     = var.argocd_alb_dns_name
  argocd_alb_zone_id      = var.argocd_alb_zone_id
  create_wildcard_record  = var.create_wildcard_dns_record
  wildcard_alb_dns_name   = var.wildcard_alb_dns_name
  wildcard_alb_zone_id    = var.wildcard_alb_zone_id
  
  depends_on = [module.eks]
}

# ========================================
# RESOURCE LIMITS MODULE (K8s Resources)
# ========================================
module "resource_limits" {
  source = "./modules/resource-limits"
  
  count = var.enable_resource_limits ? 1 : 0
  
  namespaces              = var.resource_limit_namespaces
  limit_ranges            = var.limit_ranges
  resource_quotas         = var.resource_quotas
  priority_classes        = var.priority_classes
  pod_disruption_budgets  = var.pod_disruption_budgets
  enable_network_policies = var.enable_network_policies
  common_tags             = var.common_tags
  
  depends_on = [module.eks, module.node_groups]
}
