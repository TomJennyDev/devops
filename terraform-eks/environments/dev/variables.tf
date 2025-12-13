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

# ========================================
# ROUTE53 DNS VARIABLES
# ========================================
variable "domain_name" {
  description = "Domain name for Route53"
  type        = string
  default     = ""
}

variable "create_dns_records" {
  description = "Create DNS records"
  type        = bool
  default     = false
}

variable "argocd_dns_enabled" {
  description = "Create ArgoCD DNS record"
  type        = bool
  default     = false
}

# ========================================
# CONTROLLERS
# ========================================

variable "enable_aws_load_balancer_controller" {
  description = "Enable AWS Load Balancer Controller"
  type        = bool
  default     = true
}

variable "enable_external_dns" {
  description = "Enable External DNS for Route53"
  type        = bool
  default     = false
}

# ========================================
# ROUTE53 DNS
# ========================================

variable "argocd_alb_dns_name" {
  description = "ALB DNS name for ArgoCD"
  type        = string
  default     = ""
}

variable "argocd_alb_zone_id" {
  description = "ALB Zone ID for ArgoCD"
  type        = string
  default     = ""
}

variable "create_wildcard_dns_record" {
  description = "Create wildcard DNS record"
  type        = bool
  default     = false
}

variable "wildcard_alb_dns_name" {
  description = "ALB DNS name for wildcard"
  type        = string
  default     = ""
}

variable "wildcard_alb_zone_id" {
  description = "ALB Zone ID for wildcard"
  type        = string
  default     = ""
}

# ========================================
# RESOURCE LIMITS VARIABLES
# ========================================
variable "enable_resource_limits" {
  description = "Enable resource limits"
  type        = bool
  default     = false
}

variable "resource_limit_namespaces" {
  description = "Namespaces to manage"
  type        = list(string)
  default     = ["default"]
}

variable "limit_ranges" {
  description = "LimitRange configurations"
  type = map(object({
    namespace = string
    container_default_limit_cpu      = string
    container_default_limit_memory   = string
    container_default_request_cpu    = string
    container_default_request_memory = string
    container_max_cpu    = string
    container_max_memory = string
    container_min_cpu    = string
    container_min_memory = string
    pod_max_cpu    = string
    pod_max_memory = string
    pod_min_cpu    = string
    pod_min_memory = string
  }))
  default = {}
}

variable "resource_quotas" {
  description = "ResourceQuota configurations"
  type = map(object({
    namespace = string
    requests_cpu    = string
    requests_memory = string
    limits_cpu      = string
    limits_memory   = string
    max_pods     = number
    max_services = number
    max_pvcs     = number
    requests_storage = string
  }))
  default = {}
}

variable "priority_classes" {
  description = "Priority classes"
  type = map(object({
    value              = number
    global_default     = optional(bool, false)
    description        = optional(string, "")
    preemption_policy  = optional(string, "PreemptLowerPriority")
  }))
  default = {}
}

variable "pod_disruption_budgets" {
  description = "Pod Disruption Budgets"
  type = map(object({
    namespace        = string
    max_unavailable  = optional(string)
    min_available    = optional(string)
    selector_labels  = map(string)
  }))
  default = {}
}

variable "enable_network_policies" {
  description = "Enable network policies"
  type        = bool
  default     = false
}

# ========================================
# ECR VARIABLES (Independent Module)
# ========================================
# ECR doesn't depend on other modules - can be managed separately

variable "ecr_repositories" {
  description = "Map of ECR repositories to create"
  type = map(object({
    image_tag_mutability = optional(string, "MUTABLE")
    scan_on_push         = optional(bool, true)
    max_image_count      = optional(number, 30)
    untagged_days        = optional(number, 7)
    repository_policy    = optional(string, null)
    tags                 = optional(map(string), {})
  }))
  default = {}
}

variable "ecr_encryption_type" {
  description = "Encryption type for ECR (AES256 or KMS)"
  type        = string
  default     = "AES256"
}

variable "ecr_force_delete" {
  description = "Force delete ECR repositories even if they contain images"
  type        = bool
  default     = false
}
