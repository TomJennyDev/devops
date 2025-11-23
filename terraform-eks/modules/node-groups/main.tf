# ============================================
# EKS Node Group (EC2 Workers)
# ============================================
resource "aws_eks_node_group" "main" {
  cluster_name    = var.cluster_name
  node_group_name = var.node_group_name
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.subnet_ids
  version         = var.cluster_version

  # ============================================
  # Scaling Configuration
  # ============================================
  scaling_config {
    desired_size = var.node_group_desired_size
    max_size     = var.node_group_max_size
    min_size     = var.node_group_min_size
  }

  # ============================================
  # Update Configuration
  # ============================================
  update_config {
    max_unavailable = var.node_group_max_unavailable
  }

  # ============================================
  # EC2 Instance Configuration
  # ============================================
  ami_type       = var.node_group_ami_type
  capacity_type  = var.node_group_capacity_type
  disk_size      = var.node_group_disk_size
  instance_types = var.node_group_instance_types

  # ============================================
  # Node Labels (for workload routing)
  # ============================================
  labels = merge(
    {
      "node-group" = var.node_group_name
    },
    var.node_group_labels
  )

  # ============================================
  # Node Taints (for dedicated workloads)
  # ============================================
  dynamic "taint" {
    for_each = var.node_group_taints
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  # ============================================
  # SSH Remote Access (optional)
  # ============================================
  dynamic "remote_access" {
    for_each = var.enable_node_ssh_access ? [1] : []
    content {
      ec2_ssh_key               = var.node_ssh_key_name
    }
  }

  # ============================================
  # Tags
  # ============================================
  tags = merge(
    {
      Name = "${var.cluster_name}-${var.node_group_name}"
    },
    var.common_tags
  )

  # ============================================
  # Lifecycle Rules
  # ============================================
  lifecycle {
    create_before_destroy = true
    ignore_changes        = [scaling_config[0].desired_size]
  }
}

# ============================================
# Additional Node Groups (Optional)
# ============================================

# Example: Spot Instance Node Group
# Uncomment to enable cost-optimized spot instances
/*
resource "aws_eks_node_group" "spot" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.node_group_name}-spot"
  node_role_arn   = aws_iam_role.eks_node.arn
  subnet_ids      = aws_subnet.eks_subnet_private[*].id
  version         = var.cluster_version

  scaling_config {
    desired_size = 2
    max_size     = 10
    min_size     = 0
  }

  update_config {
    max_unavailable = 1
  }

  ami_type       = "AL2023_x86_64_STANDARD"
  capacity_type  = "SPOT"  # 70% cheaper!
  disk_size      = 20
  instance_types = ["t3.medium", "t3a.medium", "t2.medium"]  # Mixed for availability

  labels = {
    role          = "spot"
    capacity-type = "spot"
  }

  tags = merge(
    {
      Name = "${var.cluster_name}-spot-nodes"
    },
    var.common_tags
  )

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_ecr_policy
  ]

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [scaling_config[0].desired_size]
  }
}
*/

# Example: GPU Node Group
# Uncomment to enable GPU nodes for ML workloads
/*
resource "aws_eks_node_group" "gpu" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.node_group_name}-gpu"
  node_role_arn   = aws_iam_role.eks_node.arn
  subnet_ids      = aws_subnet.eks_subnet_private[*].id
  version         = var.cluster_version

  scaling_config {
    desired_size = 0
    max_size     = 3
    min_size     = 0
  }

  update_config {
    max_unavailable = 1
  }

  ami_type       = "AL2_x86_64_GPU"
  capacity_type  = "SPOT"  # Save 70% on expensive GPU instances
  disk_size      = 50
  instance_types = ["g4dn.xlarge"]  # 1 GPU, 4 vCPU, 16GB RAM

  labels = {
    role          = "gpu"
    nvidia-gpu    = "true"
    workload-type = "ml"
  }

  # Taint to ensure only GPU workloads run here
  taint {
    key    = "nvidia.com/gpu"
    value  = "true"
    effect = "NoSchedule"
  }

  tags = merge(
    {
      Name = "${var.cluster_name}-gpu-nodes"
    },
    var.common_tags
  )

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_ecr_policy
  ]

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [scaling_config[0].desired_size]
  }
}
*/

# Example: ARM-based Node Group (Graviton)
# Uncomment to enable ARM nodes (20% cheaper)
/*
resource "aws_eks_node_group" "arm" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.node_group_name}-arm"
  node_role_arn   = aws_iam_role.eks_node.arn
  subnet_ids      = aws_subnet.eks_subnet_private[*].id
  version         = var.cluster_version

  scaling_config {
    desired_size = 2
    max_size     = 5
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  ami_type       = "AL2023_ARM_64_STANDARD"
  capacity_type  = "ON_DEMAND"
  disk_size      = 20
  instance_types = ["t4g.medium"]  # ARM Graviton - 20% cheaper

  labels = {
    role         = "arm"
    architecture = "arm64"
  }

  tags = merge(
    {
      Name = "${var.cluster_name}-arm-nodes"
    },
    var.common_tags
  )

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_ecr_policy
  ]

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [scaling_config[0].desired_size]
  }
}
*/
