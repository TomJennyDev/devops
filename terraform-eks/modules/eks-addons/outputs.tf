# ============================================
# EKS Addons Module Outputs
# ============================================

output "vpc_cni_addon_arn" {
  description = "ARN of VPC CNI addon"
  value       = try(aws_eks_addon.vpc_cni[0].arn, null)
}

output "coredns_addon_arn" {
  description = "ARN of CoreDNS addon"
  value       = try(aws_eks_addon.coredns[0].arn, null)
}

output "kube_proxy_addon_arn" {
  description = "ARN of kube-proxy addon"
  value       = try(aws_eks_addon.kube_proxy[0].arn, null)
}
