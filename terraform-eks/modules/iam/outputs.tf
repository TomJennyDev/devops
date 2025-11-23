output "cluster_role_arn" {
  description = "ARN of IAM role for EKS cluster"
  value       = aws_iam_role.eks_cluster.arn
}

output "node_role_arn" {
  description = "ARN of IAM role for EKS nodes"
  value       = aws_iam_role.eks_node.arn
}

output "node_instance_profile_name" {
  description = "Name of IAM instance profile for EKS nodes"
  value       = aws_iam_instance_profile.eks_node.name
}
