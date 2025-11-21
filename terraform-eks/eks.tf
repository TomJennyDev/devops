# ============================================
# EKS Cluster
# ============================================
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids              = concat(aws_subnet.eks_subnet_private[*].id, aws_subnet.eks_subnet_public[*].id)
    endpoint_private_access = var.cluster_endpoint_private_access
    endpoint_public_access  = var.cluster_endpoint_public_access
    public_access_cidrs     = var.cluster_endpoint_public_access_cidrs
    security_group_ids      = [aws_security_group.eks_cluster.id]
  }

  enabled_cluster_log_types = var.cluster_enabled_log_types

  tags = merge(
    {
      Name = var.cluster_name
    },
    var.tags
  )

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_cloudwatch_log_group.eks_cluster
  ]
}

# ============================================
# CloudWatch Log Group for EKS Cluster
# ============================================
resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = 7

  tags = var.tags
}

# ============================================
# EKS Addons (Latest versions as of Nov 2025)
# ============================================
resource "aws_eks_addon" "vpc_cni" {
  count = var.enable_cluster_addons ? 1 : 0

  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "vpc-cni"
  addon_version            = var.addon_vpc_cni_version
  resolve_conflicts_on_update = "PRESERVE"

  tags = var.tags
}

resource "aws_eks_addon" "coredns" {
  count = var.enable_cluster_addons ? 1 : 0

  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "coredns"
  addon_version            = var.addon_coredns_version
  resolve_conflicts_on_update = "PRESERVE"

  tags = var.tags

  depends_on = [aws_eks_node_group.main]
}

resource "aws_eks_addon" "kube_proxy" {
  count = var.enable_cluster_addons ? 1 : 0

  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "kube-proxy"
  addon_version            = var.addon_kube_proxy_version
  resolve_conflicts_on_update = "PRESERVE"

  tags = var.tags
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

  tags = var.tags
}