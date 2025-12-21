# ============================================
# EKS Addons Module
# ============================================
# Manages EKS addons separately from cluster creation
# to avoid circular dependencies with node groups
# ============================================

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# ============================================
# VPC CNI Addon
# ============================================
resource "aws_eks_addon" "vpc_cni" {
  count = var.enable_cluster_addons ? 1 : 0

  cluster_name             = var.cluster_name
  addon_name               = "vpc-cni"
  addon_version            = var.vpc_cni_version
  resolve_conflicts_on_update = "PRESERVE"

  tags = var.common_tags

  lifecycle {
    ignore_changes = [modified_at]
  }
}

# ============================================
# CoreDNS Addon
# ============================================
resource "aws_eks_addon" "coredns" {
  count = var.enable_cluster_addons ? 1 : 0

  cluster_name                = var.cluster_name
  addon_name                  = "coredns"
  addon_version               = var.coredns_version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  # CRITICAL: Wait for VPC CNI and node groups
  depends_on = [
    aws_eks_addon.vpc_cni
  ]

  tags = var.common_tags

  lifecycle {
    ignore_changes = [modified_at]
  }
}

# ============================================
# Kube Proxy Addon
# ============================================
resource "aws_eks_addon" "kube_proxy" {
  count = var.enable_cluster_addons ? 1 : 0

  cluster_name             = var.cluster_name
  addon_name               = "kube-proxy"
  addon_version            = var.kube_proxy_version
  resolve_conflicts_on_update = "PRESERVE"

  tags = var.common_tags

  lifecycle {
    ignore_changes = [modified_at]
  }
}

# ============================================
# EBS CSI Driver Addon
# ============================================
resource "aws_eks_addon" "ebs_csi_driver" {
  count = var.enable_cluster_addons ? 1 : 0

  cluster_name             = var.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = var.ebs_csi_driver_version
  resolve_conflicts_on_update = "PRESERVE"

  service_account_role_arn = var.ebs_csi_driver_role_arn

  tags = var.common_tags

  lifecycle {
    ignore_changes = [modified_at]
  }
}
