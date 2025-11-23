# ============================================
# EKS Cluster Outputs
# ============================================
output "cluster_id" {
  description = "The name/id of the EKS cluster"
  value       = module.eks.cluster_id
}

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = var.cluster_name
}

output "cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the cluster"
  value       = module.eks.cluster_arn
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "The Kubernetes server version for the cluster"
  value       = module.eks.cluster_version
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.security_groups.cluster_security_group_id
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer"
  value       = module.eks.cluster_oidc_issuer_url
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC Provider for EKS"
  value       = module.eks.oidc_provider_arn
}

# ============================================
# VPC Outputs
# ============================================
output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "The CIDR block of the VPC"
  value       = module.vpc.vpc_cidr
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnet_ids
}

# ============================================
# Node Group Outputs
# ============================================
output "node_group_id" {
  description = "EKS node group ID"
  value       = module.node_groups.node_group_id
}

output "node_group_arn" {
  description = "Amazon Resource Name (ARN) of the EKS Node Group"
  value       = module.node_groups.node_group_arn
}

output "node_group_status" {
  description = "Status of the EKS node group"
  value       = module.node_groups.node_group_status
}

output "node_security_group_id" {
  description = "Security group ID attached to the EKS nodes"
  value       = module.security_groups.node_security_group_id
}

output "node_role_arn" {
  description = "IAM role ARN for EKS nodes"
  value       = module.iam.node_role_arn
}

# ============================================
# External DNS Outputs
# ============================================
output "external_dns_role_arn" {
  description = "IAM role ARN for External DNS (use in ArgoCD config)"
  value       = module.external_dns.external_dns_role_arn
}

output "external_dns_role_name" {
  description = "IAM role name for External DNS"
  value       = module.external_dns.external_dns_role_name
}

# ============================================
# AWS Load Balancer Controller Outputs
# ============================================
output "aws_load_balancer_controller_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller (use in Helm/ArgoCD)"
  value       = module.alb_controller.aws_load_balancer_controller_role_arn
}

output "aws_load_balancer_controller_policy_arn" {
  description = "IAM policy ARN for AWS Load Balancer Controller"
  value       = module.alb_controller.aws_load_balancer_controller_policy_arn
}

# ============================================
# Kubectl Config Command
# ============================================
output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${var.cluster_name}"
}