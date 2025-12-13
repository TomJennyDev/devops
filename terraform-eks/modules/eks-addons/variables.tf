# ============================================
# EKS Addons Module Variables
# ============================================

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "enable_cluster_addons" {
  description = "Enable EKS cluster addons"
  type        = bool
  default     = true
}

variable "vpc_cni_version" {
  description = "Version of VPC CNI addon"
  type        = string
  default     = "v1.18.5-eksbuild.1"
}

variable "coredns_version" {
  description = "Version of CoreDNS addon"
  type        = string
  default     = "v1.11.3-eksbuild.1"
}

variable "kube_proxy_version" {
  description = "Version of kube-proxy addon"
  type        = string
  default     = "v1.31.0-eksbuild.2"
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
