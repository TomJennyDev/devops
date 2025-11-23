# ========================================
# VARIABLES - DEV ENVIRONMENT
# ========================================
# These variables will be populated from terraform.tfvars

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks"
  type        = list(string)
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["ap-southeast-1a", "ap-southeast-1b"]
}

variable "nat_gateway_count" {
  description = "Number of NAT Gateways"
  type        = number
}

variable "cluster_endpoint_public_access" {
  description = "Enable public API endpoint"
  type        = bool
}

variable "cluster_endpoint_private_access" {
  description = "Enable private API endpoint"
  type        = bool
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDR blocks for public API access"
  type        = list(string)
}

variable "cluster_enabled_log_types" {
  description = "CloudWatch log types"
  type        = list(string)
}

variable "cluster_log_retention_days" {
  description = "Log retention period"
  type        = number
}

variable "node_group_name" {
  description = "Node group name"
  type        = string
}

variable "node_group_desired_size" {
  description = "Desired number of nodes"
  type        = number
}

variable "node_group_min_size" {
  description = "Minimum number of nodes"
  type        = number
}

variable "node_group_max_size" {
  description = "Maximum number of nodes"
  type        = number
}

variable "node_group_instance_types" {
  description = "EC2 instance types"
  type        = list(string)
}

variable "node_group_capacity_type" {
  description = "Capacity type (ON_DEMAND or SPOT)"
  type        = string
}

variable "node_group_disk_size" {
  description = "Root disk size in GB"
  type        = number
}

variable "node_group_ami_type" {
  description = "AMI type"
  type        = string
}

variable "node_group_labels" {
  description = "Kubernetes labels"
  type        = map(string)
}

variable "node_group_taints" {
  description = "Kubernetes taints"
  type        = list(object({
    key    = string
    value  = string
    effect = string
  }))
}

variable "enable_node_ssh_access" {
  description = "Enable SSH access to nodes"
  type        = bool
}

variable "node_ssh_key_name" {
  description = "SSH key pair name"
  type        = string
}

variable "ssh_allowed_cidr_blocks" {
  description = "CIDR blocks for SSH access"
  type        = list(string)
}

variable "vpc_cni_version" {
  description = "VPC CNI addon version"
  type        = string
}

variable "coredns_version" {
  description = "CoreDNS addon version"
  type        = string
}

variable "kube_proxy_version" {
  description = "kube-proxy addon version"
  type        = string
}

variable "common_tags" {
  description = "Common tags"
  type        = map(string)
}
