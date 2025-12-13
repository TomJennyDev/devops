# ========================================
# OUTPUTS - DEV ENVIRONMENT
# ========================================

output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Cluster security group ID"
  value       = module.eks.cluster_security_group_id
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = module.eks.configure_kubectl
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.eks.vpc_id
}

output "node_group_id" {
  description = "Node group ID"
  value       = module.eks.node_group_id
}

output "aws_load_balancer_controller_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller"
  value       = module.eks.aws_load_balancer_controller_role_arn
}

output "external_dns_role_arn" {
  description = "IAM role ARN for External DNS (if enabled)"
  value       = module.eks.external_dns_role_arn
}

# ========================================
# ECR OUTPUTS (Independent Module)
# ========================================

output "ecr_repository_urls" {
  description = "ECR repository URLs"
  value       = module.ecr.repository_urls
}

output "ecr_flowise_server_url" {
  description = "ECR URL for flowise-server"
  value       = module.ecr.flowise_server_url
}

output "ecr_flowise_ui_url" {
  description = "ECR URL for flowise-ui"
  value       = module.ecr.flowise_ui_url
}

output "ecr_docker_login_command" {
  description = "Command to authenticate Docker with ECR"
  value       = module.ecr.docker_login_command
}

