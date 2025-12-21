# AWS Region
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-west-2"
  
  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]{1}$", var.aws_region))
    error_message = "AWS region must be valid format (e.g., us-west-2, ap-southeast-1)."
  }
}

# EKS Cluster
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "my-eks-cluster"
  
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{0,99}$", var.cluster_name))
    error_message = "Cluster name must start with letter, contain only alphanumeric and hyphens, max 100 chars."
  }
}

variable "cluster_version" {
  description = "Kubernetes version to use for the EKS cluster"
  type        = string
  default     = "1.34"
  
  validation {
    condition     = can(regex("^1\\.(2[89]|3[0-9])$", var.cluster_version))
    error_message = "Cluster version must be between 1.28 and 1.39 (current supported versions)."
  }
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
  
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b", "us-west-2c"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
}

variable "public_subnet_count" {
  description = "Number of public subnets"
  type        = number
  default     = 3
  
  validation {
    condition     = var.public_subnet_count >= 2 && var.public_subnet_count <= 6
    error_message = "Public subnet count must be between 2 and 6 for proper HA setup."
  }
}

variable "private_subnet_count" {
  description = "Number of private subnets"
  type        = number
  default     = 3
  
  validation {
    condition     = var.private_subnet_count >= 2 && var.private_subnet_count <= 6
    error_message = "Private subnet count must be between 2 and 6 for proper HA setup."
  }
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "nat_gateway_count" {
  description = "Number of NAT Gateways (1 for cost saving, 3 for HA)"
  type        = number
  default     = 1
  
  validation {
    condition     = var.nat_gateway_count >= 1 && var.nat_gateway_count <= 3
    error_message = "NAT Gateway count must be 1 (cost-effective) or 3 (high availability)."
  }
}

# EKS Node Group
variable "node_group_name" {
  description = "Name of the EKS node group"
  type        = string
  default     = "general-nodes"
}

variable "node_max_unavailable" {
  description = "Maximum number of nodes unavailable during update"
  type        = number
  default     = 1
}

variable "node_ssh_key_name" {
  description = "EC2 Key Pair name for SSH access to nodes"
  type        = string
  default     = ""
}

# Cluster Addons
variable "enable_cluster_addons" {
  description = "Enable EKS cluster addons"
  type        = bool
  default     = true
}

variable "enable_aws_load_balancer_controller" {
  description = "Enable AWS Load Balancer Controller for ALB/NLB support"
  type        = bool
  default     = true
}

# External DNS
variable "enable_external_dns" {
  description = "Enable External DNS for automatic Route53 DNS management"
  type        = bool
  default     = false
}

variable "route53_zone_arns" {
  description = "List of Route53 Hosted Zone ARNs that External DNS can manage (empty = all zones)"
  type        = list(string)
  default     = []
}

# Cluster Endpoint Access
variable "cluster_endpoint_private_access" {
  description = "Enable private API server endpoint"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access" {
  description = "Enable public API server endpoint"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "List of CIDR blocks that can access the public API server endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# Logging
variable "cluster_enabled_log_types" {
  description = "List of control plane logging types to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

# Logging
variable "cluster_log_retention_days" {
  description = "Number of days to retain cluster logs in CloudWatch"
  type        = number
  default     = 7
}

# Node Group Configuration
variable "node_group_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "node_group_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "node_group_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 4
}

variable "node_group_instance_types" {
  description = "List of instance types for the node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_group_capacity_type" {
  description = "Capacity type for node group (ON_DEMAND or SPOT)"
  type        = string
  default     = "ON_DEMAND"
}

variable "node_group_disk_size" {
  description = "Disk size in GB for worker nodes"
  type        = number
  default     = 50
}

variable "node_group_ami_type" {
  description = "AMI type for node group"
  type        = string
  default     = "AL2023_x86_64_STANDARD"
}

variable "node_group_labels" {
  description = "Labels to apply to node group"
  type        = map(string)
  default     = {}
}

variable "node_group_taints" {
  description = "Taints to apply to node group"
  type        = list(object({
    key    = string
    value  = string
    effect = string
  }))
  default     = []
}

variable "enable_node_ssh_access" {
  description = "Enable SSH access to worker nodes"
  type        = bool
  default     = false
}

variable "ssh_allowed_cidr_blocks" {
  description = "CIDR blocks allowed to SSH to nodes"
  type        = list(string)
  default     = []
}

# EKS Addon Versions
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

# Tags
variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

# ========================================
# ROUTE53 DNS VARIABLES
# ========================================
variable "domain_name" {
  description = "Domain name for Route53 hosted zone"
  type        = string
  default     = ""
}

variable "create_dns_records" {
  description = "Whether to create DNS records in Route53"
  type        = bool
  default     = false
}

variable "argocd_dns_enabled" {
  description = "Whether to create ArgoCD DNS record"
  type        = bool
  default     = false
}

variable "argocd_alb_dns_name" {
  description = "ALB DNS name for ArgoCD (get from kubectl after deployment)"
  type        = string
  default     = ""
}

variable "argocd_alb_zone_id" {
  description = "ALB Zone ID for ArgoCD (get from kubectl after deployment)"
  type        = string
  default     = ""
}

variable "create_wildcard_dns_record" {
  description = "Whether to create wildcard DNS record for app ingresses"
  type        = bool
  default     = false
}

variable "wildcard_alb_dns_name" {
  description = "ALB DNS name for wildcard record"
  type        = string
  default     = ""
}

variable "wildcard_alb_zone_id" {
  description = "ALB Zone ID for wildcard record"
  type        = string
  default     = ""
}

# ========================================
# RESOURCE LIMITS VARIABLES
# ========================================
variable "enable_resource_limits" {
  description = "Enable Kubernetes resource limits, quotas, and policies"
  type        = bool
  default     = false
}

variable "resource_limit_namespaces" {
  description = "List of namespaces to manage with resource limits"
  type        = list(string)
  default     = ["default", "dev", "staging", "prod"]
}

variable "limit_ranges" {
  description = "LimitRange configurations per namespace"
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
  
  default = {
    default = {
      namespace = "default"
      
      container_default_limit_cpu      = "500m"
      container_default_limit_memory   = "512Mi"
      container_default_request_cpu    = "100m"
      container_default_request_memory = "128Mi"
      
      container_max_cpu    = "2000m"
      container_max_memory = "2Gi"
      container_min_cpu    = "50m"
      container_min_memory = "64Mi"
      
      pod_max_cpu    = "4000m"
      pod_max_memory = "4Gi"
      pod_min_cpu    = "50m"
      pod_min_memory = "64Mi"
    }
  }
}

variable "resource_quotas" {
  description = "ResourceQuota configurations per namespace"
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
  
  default = {
    default = {
      namespace = "default"
      
      requests_cpu    = "2000m"
      requests_memory = "4Gi"
      limits_cpu      = "4000m"
      limits_memory   = "8Gi"
      
      max_pods     = 20
      max_services = 10
      max_pvcs     = 5
      
      requests_storage = "50Gi"
    }
  }
}

variable "priority_classes" {
  description = "Priority classes for pod scheduling"
  type = map(object({
    value              = number
    global_default     = optional(bool, false)
    description        = optional(string, "")
    preemption_policy  = optional(string, "PreemptLowerPriority")
  }))
  
  default = {
    high-priority = {
      value       = 1000
      description = "High priority for critical workloads"
    }
    medium-priority = {
      value       = 500
      description = "Medium priority for normal workloads"
    }
    low-priority = {
      value       = 100
      description = "Low priority for batch jobs"
    }
  }
}

variable "pod_disruption_budgets" {
  description = "Pod Disruption Budgets configuration"
  type = map(object({
    namespace        = string
    max_unavailable  = optional(string)
    min_available    = optional(string)
    selector_labels  = map(string)
  }))
  
  default = {}
}

variable "enable_network_policies" {
  description = "Enable default network policies for namespaces"
  type        = bool
  default     = false
}
variable "ebs_csi_driver_version" {
  description = "Version of EBS CSI driver addon"
  type        = string
  default     = "v1.37.0-eksbuild.1"
}

# ========================================
# CLOUDFRONT CDN VARIABLES
# ========================================
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "enable_cloudfront" {
  description = "Enable CloudFront CDN distribution"
  type        = bool
  default     = false
}

variable "cloudfront_aliases" {
  description = "List of CNAMEs (alternate domain names) for CloudFront"
  type        = list(string)
  default     = []
}

variable "cloudfront_price_class" {
  description = "CloudFront price class (PriceClass_All, PriceClass_200, PriceClass_100)"
  type        = string
  default     = "PriceClass_100"
}

variable "cloudfront_default_root_object" {
  description = "Default root object for CloudFront"
  type        = string
  default     = "index.html"
}

variable "cloudfront_alb_domain_name" {
  description = "Domain name of the ALB (CloudFront origin)"
  type        = string
  default     = ""
}

variable "cloudfront_origin_custom_header" {
  description = "Custom header value for origin verification"
  type        = string
  default     = ""
  sensitive   = true
}

variable "cloudfront_enable_s3_origin" {
  description = "Enable S3 bucket as additional origin for static content"
  type        = bool
  default     = false
}

variable "cloudfront_s3_bucket_domain" {
  description = "S3 bucket domain name for static content origin"
  type        = string
  default     = ""
}

variable "cloudfront_s3_oai" {
  description = "CloudFront origin access identity for S3"
  type        = string
  default     = ""
}

variable "cloudfront_cache_default_ttl" {
  description = "Default TTL for cached objects (seconds)"
  type        = number
  default     = 3600
}

variable "cloudfront_cache_max_ttl" {
  description = "Maximum TTL for cached objects (seconds)"
  type        = number
  default     = 86400
}

variable "cloudfront_cache_min_ttl" {
  description = "Minimum TTL for cached objects (seconds)"
  type        = number
  default     = 0
}

variable "cloudfront_cache_headers" {
  description = "List of headers to include in cache key"
  type        = list(string)
  default     = ["Host", "CloudFront-Forwarded-Proto", "CloudFront-Is-Desktop-Viewer", "CloudFront-Is-Mobile-Viewer"]
}

variable "cloudfront_acm_certificate_arn" {
  description = "ACM certificate ARN for CloudFront (must be in us-east-1)"
  type        = string
  default     = ""
}

variable "cloudfront_geo_restriction_type" {
  description = "Geo restriction type (none, whitelist, blacklist)"
  type        = string
  default     = "none"
}

variable "cloudfront_geo_restriction_locations" {
  description = "List of country codes for geo restriction"
  type        = list(string)
  default     = []
}

variable "cloudfront_enable_logging" {
  description = "Enable CloudFront access logging"
  type        = bool
  default     = true
}

variable "cloudfront_logging_bucket" {
  description = "S3 bucket for CloudFront access logs"
  type        = string
  default     = ""
}

variable "cloudfront_waf_web_acl_id" {
  description = "AWS WAF Web ACL ID to associate with CloudFront"
  type        = string
  default     = ""
}

variable "cloudfront_enable_url_rewrite" {
  description = "Enable URL rewrite CloudFront function"
  type        = bool
  default     = false
}

variable "cloudfront_function_arn" {
  description = "ARN of CloudFront function for viewer request"
  type        = string
  default     = ""
}

variable "cloudfront_enable_alarms" {
  description = "Enable CloudWatch alarms for CloudFront"
  type        = bool
  default     = true
}

variable "cloudfront_error_rate_threshold" {
  description = "Threshold for 5xx error rate alarm (%)"
  type        = number
  default     = 5
}

variable "cloudfront_cache_hit_threshold" {
  description = "Threshold for cache hit rate alarm (%)"
  type        = number
  default     = 80
}

variable "cloudfront_alarm_actions" {
  description = "List of ARNs to notify when alarm triggers"
  type        = list(string)
  default     = []
}

# ========================================
# WAF VARIABLES
# ========================================
variable "enable_waf" {
  description = "Enable AWS WAF Web ACL"
  type        = bool
  default     = false
}

variable "waf_scope" {
  description = "WAF scope: CLOUDFRONT or REGIONAL"
  type        = string
  default     = "CLOUDFRONT"
}

variable "waf_core_rule_excluded" {
  description = "Core rule set rules to exclude"
  type        = list(string)
  default     = []
}

variable "waf_enable_sqli_rule" {
  description = "Enable SQL injection protection"
  type        = bool
  default     = true
}

variable "waf_enable_linux_rule" {
  description = "Enable Linux OS protection"
  type        = bool
  default     = true
}

variable "waf_enable_rate_limit" {
  description = "Enable rate limiting"
  type        = bool
  default     = true
}

variable "waf_rate_limit_value" {
  description = "Max requests per 5 min"
  type        = number
  default     = 2000
}

variable "waf_enable_geo_blocking" {
  description = "Enable geo blocking"
  type        = bool
  default     = false
}

variable "waf_blocked_countries" {
  description = "Countries to block"
  type        = list(string)
  default     = []
}

variable "waf_enable_ip_blacklist" {
  description = "Enable IP blacklist"
  type        = bool
  default     = false
}

variable "waf_blacklist_ips" {
  description = "IPs to block"
  type        = list(string)
  default     = []
}

variable "waf_enable_ip_whitelist" {
  description = "Enable IP whitelist"
  type        = bool
  default     = false
}

variable "waf_whitelist_ips" {
  description = "IPs to allow"
  type        = list(string)
  default     = []
}

variable "waf_enable_regex" {
  description = "Enable regex patterns"
  type        = bool
  default     = false
}

variable "waf_regex_patterns" {
  description = "Regex patterns"
  type        = list(string)
  default     = []
}

variable "waf_enable_logging" {
  description = "Enable WAF logging"
  type        = bool
  default     = true
}

variable "waf_log_retention_days" {
  description = "Log retention days"
  type        = number
  default     = 30
}

variable "waf_redacted_fields" {
  description = "Fields to redact"
  type = list(object({
    type = string
    name = optional(string)
  }))
  default = []
}

variable "waf_enable_alarms" {
  description = "Enable WAF alarms"
  type        = bool
  default     = true
}

variable "waf_blocked_threshold" {
  description = "Blocked requests threshold"
  type        = number
  default     = 100
}

variable "waf_rate_limited_threshold" {
  description = "Rate limited threshold"
  type        = number
  default     = 50
}

variable "waf_alarm_actions" {
  description = "SNS topic ARNs"
  type        = list(string)
  default     = []
}
