# ============================================
# CLOUDFRONT MODULE VARIABLES
# ============================================

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "enable_cloudfront" {
  description = "Enable CloudFront distribution"
  type        = bool
  default     = true
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

# ============================================
# CLOUDFRONT DISTRIBUTION
# ============================================

variable "cloudfront_aliases" {
  description = "List of CNAMEs (alternate domain names) for the distribution"
  type        = list(string)
  default     = []
}

variable "cloudfront_price_class" {
  description = "Price class for CloudFront distribution (PriceClass_All, PriceClass_200, PriceClass_100)"
  type        = string
  default     = "PriceClass_100"

  validation {
    condition     = contains(["PriceClass_All", "PriceClass_200", "PriceClass_100"], var.cloudfront_price_class)
    error_message = "Price class must be PriceClass_All, PriceClass_200, or PriceClass_100."
  }
}

variable "default_root_object" {
  description = "Default root object for CloudFront"
  type        = string
  default     = "index.html"
}

# ============================================
# ORIGIN CONFIGURATION
# ============================================

variable "alb_domain_name" {
  description = "Domain name of the ALB (origin)"
  type        = string
}

variable "origin_custom_header_value" {
  description = "Custom header value for origin verification (random string)"
  type        = string
  default     = ""
  sensitive   = true
}

# ============================================
# S3 ORIGIN (Optional)
# ============================================

variable "enable_s3_origin" {
  description = "Enable S3 bucket as additional origin for static content"
  type        = bool
  default     = false
}

variable "s3_bucket_domain_name" {
  description = "S3 bucket domain name for static content origin"
  type        = string
  default     = ""
}

variable "s3_origin_access_identity" {
  description = "CloudFront origin access identity for S3"
  type        = string
  default     = ""
}

# ============================================
# CACHE CONFIGURATION
# ============================================

variable "cache_default_ttl" {
  description = "Default TTL for cached objects (seconds)"
  type        = number
  default     = 3600  # 1 hour
}

variable "cache_max_ttl" {
  description = "Maximum TTL for cached objects (seconds)"
  type        = number
  default     = 86400  # 24 hours
}

variable "cache_min_ttl" {
  description = "Minimum TTL for cached objects (seconds)"
  type        = number
  default     = 0
}

variable "cache_header_whitelist" {
  description = "List of headers to include in cache key"
  type        = list(string)
  default     = ["Host", "CloudFront-Forwarded-Proto", "CloudFront-Is-Desktop-Viewer", "CloudFront-Is-Mobile-Viewer"]
}

# ============================================
# SSL/TLS CERTIFICATE
# ============================================

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for CloudFront (must be in us-east-1)"
  type        = string
}

# ============================================
# GEO RESTRICTIONS
# ============================================

variable "geo_restriction_type" {
  description = "Geo restriction type (none, whitelist, blacklist)"
  type        = string
  default     = "none"

  validation {
    condition     = contains(["none", "whitelist", "blacklist"], var.geo_restriction_type)
    error_message = "Geo restriction type must be none, whitelist, or blacklist."
  }
}

variable "geo_restriction_locations" {
  description = "List of country codes for geo restriction (ISO 3166-1-alpha-2)"
  type        = list(string)
  default     = []
}

# ============================================
# LOGGING
# ============================================

variable "enable_logging" {
  description = "Enable CloudFront access logging"
  type        = bool
  default     = true
}

variable "logging_bucket" {
  description = "S3 bucket for CloudFront access logs"
  type        = string
  default     = ""
}

# ============================================
# WAF
# ============================================

variable "waf_web_acl_id" {
  description = "AWS WAF Web ACL ID to associate with CloudFront"
  type        = string
  default     = ""
}

# ============================================
# CLOUDFRONT FUNCTIONS
# ============================================

variable "enable_url_rewrite_function" {
  description = "Enable URL rewrite CloudFront function"
  type        = bool
  default     = false
}

variable "viewer_request_function_arn" {
  description = "ARN of CloudFront function for viewer request"
  type        = string
  default     = ""
}

# ============================================
# MONITORING
# ============================================

variable "enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms for CloudFront"
  type        = bool
  default     = true
}

variable "error_rate_threshold" {
  description = "Threshold for 5xx error rate alarm (%)"
  type        = number
  default     = 5
}

variable "cache_hit_rate_threshold" {
  description = "Threshold for cache hit rate alarm (%)"
  type        = number
  default     = 80
}

variable "alarm_actions" {
  description = "List of ARNs to notify when alarm triggers (SNS topics)"
  type        = list(string)
  default     = []
}
