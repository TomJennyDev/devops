# ============================================
# EKS Cluster
# ============================================
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = var.cluster_role_arn

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = var.cluster_endpoint_private_access
    endpoint_public_access  = var.cluster_endpoint_public_access
    public_access_cidrs     = var.cluster_endpoint_public_access_cidrs
    security_group_ids      = [var.cluster_security_group_id]
  }

  enabled_cluster_log_types = var.cluster_enabled_log_types

  tags = merge(
    {
      Name = var.cluster_name
    },
    var.common_tags
  )

  depends_on = [
    aws_cloudwatch_log_group.eks_cluster
  ]
}

# ============================================
# CloudWatch Log Group for EKS Cluster
# ============================================
resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.cluster_log_retention_days

  tags = var.common_tags
}

# ============================================
# EKS Addons (Latest versions as of Nov 2025)
# ============================================
resource "aws_eks_addon" "vpc_cni" {
  count = var.enable_cluster_addons ? 1 : 0

  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "vpc-cni"
  addon_version            = var.vpc_cni_version
  resolve_conflicts_on_update = "PRESERVE"

  tags = var.common_tags
}

# NOTE: CoreDNS addon moved to root module (main.tf)
# Reason: CoreDNS needs node groups to be ready, but node_groups module
# is created after eks module. Moving CoreDNS to root ensures proper dependency chain:
# eks module -> node_groups module -> coredns addon
# This prevents the 20-minute timeout issue where CoreDNS waits for nodes to schedule pods

# resource "aws_eks_addon" "coredns" {
#   count = var.enable_cluster_addons ? 1 : 0
#   cluster_name                = aws_eks_cluster.main.name
#   addon_name                  = "coredns"
#   addon_version               = var.coredns_version
#   resolve_conflicts_on_create = "OVERWRITE"
#   resolve_conflicts_on_update = "PRESERVE"
#   depends_on = [
#     aws_eks_cluster.main,
#     aws_eks_addon.vpc_cni
#   ]
#   tags = var.common_tags
# }

resource "aws_eks_addon" "kube_proxy" {
  count = var.enable_cluster_addons ? 1 : 0

  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "kube-proxy"
  addon_version            = var.kube_proxy_version
  resolve_conflicts_on_update = "PRESERVE"

  tags = var.common_tags
}

# ============================================
# OIDC Provider for IRSA (IAM Roles for Service Accounts)
# ============================================
data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = var.common_tags
}