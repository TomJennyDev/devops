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

# ========================================
# CLOUDFRONT CDN VARIABLES
# ========================================
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
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
  description = "WAF scope: CLOUDFRONT (global) or REGIONAL (ALB)"
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
  description = "Max requests per 5 min from single IP"
  type        = number
  default     = 2000
}

variable "waf_enable_geo_blocking" {
  description = "Enable geographic blocking"
  type        = bool
  default     = false
}

variable "waf_blocked_countries" {
  description = "Countries to block (ISO 3166-1 alpha-2)"
  type        = list(string)
  default     = []
}

variable "waf_enable_ip_blacklist" {
  description = "Enable IP blacklist"
  type        = bool
  default     = false
}

variable "waf_blacklist_ips" {
  description = "IP addresses/CIDR to block"
  type        = list(string)
  default     = []
}

variable "waf_enable_ip_whitelist" {
  description = "Enable IP whitelist"
  type        = bool
  default     = false
}

variable "waf_whitelist_ips" {
  description = "IP addresses/CIDR to allow"
  type        = list(string)
  default     = []
}

variable "waf_enable_regex" {
  description = "Enable regex pattern matching"
  type        = bool
  default     = false
}

variable "waf_regex_patterns" {
  description = "Regex patterns to block"
  type        = list(string)
  default     = []
}

variable "waf_enable_logging" {
  description = "Enable WAF logging"
  type        = bool
  default     = true
}

variable "waf_log_retention_days" {
  description = "WAF log retention days"
  type        = number
  default     = 30
}

variable "waf_redacted_fields" {
  description = "Fields to redact from logs"
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
  description = "Blocked requests alarm threshold"
  type        = number
  default     = 100
}

variable "waf_rate_limited_threshold" {
  description = "Rate limited alarm threshold"
  type        = number
  default     = 50
}

variable "waf_alarm_actions" {
  description = "SNS topic ARNs for alarms"
  type        = list(string)
  default     = []
}
