# ============================================
# WAF MODULE VARIABLES
# ============================================

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "enable_waf" {
  description = "Enable AWS WAF Web ACL"
  type        = bool
  default     = false
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

# ============================================
# WAF SCOPE
# ============================================

variable "waf_scope" {
  description = "WAF scope: CLOUDFRONT (global) or REGIONAL (ALB)"
  type        = string
  default     = "REGIONAL"

  validation {
    condition     = contains(["CLOUDFRONT", "REGIONAL"], var.waf_scope)
    error_message = "WAF scope must be either CLOUDFRONT or REGIONAL."
  }
}

# ============================================
# AWS MANAGED RULES
# ============================================

variable "core_rule_set_excluded_rules" {
  description = "List of rules to exclude from Core Rule Set"
  type        = list(string)
  default     = []
}

variable "enable_sql_injection_rule" {
  description = "Enable SQL injection protection rule"
  type        = bool
  default     = true
}

variable "enable_linux_rule" {
  description = "Enable Linux operating system protection rule"
  type        = bool
  default     = true
}

# ============================================
# RATE LIMITING
# ============================================

variable "enable_rate_limiting" {
  description = "Enable rate limiting rule"
  type        = bool
  default     = true
}

variable "rate_limit_requests" {
  description = "Maximum requests per 5 minutes from single IP"
  type        = number
  default     = 2000
}

# ============================================
# GEO BLOCKING
# ============================================

variable "enable_geo_blocking" {
  description = "Enable geographic blocking"
  type        = bool
  default     = false
}

variable "blocked_countries" {
  description = "List of country codes to block (ISO 3166-1 alpha-2)"
  type        = list(string)
  default     = []
}

# ============================================
# IP FILTERING
# ============================================

variable "enable_ip_blacklist" {
  description = "Enable IP blacklist"
  type        = bool
  default     = false
}

variable "blacklist_ip_addresses" {
  description = "List of IP addresses/CIDR to block"
  type        = list(string)
  default     = []
}

variable "enable_ip_whitelist" {
  description = "Enable IP whitelist (only allow specific IPs)"
  type        = bool
  default     = false
}

variable "whitelist_ip_addresses" {
  description = "List of IP addresses/CIDR to allow"
  type        = list(string)
  default     = []
}

# ============================================
# REGEX PATTERN MATCHING
# ============================================

variable "enable_regex_pattern_matching" {
  description = "Enable custom regex pattern matching"
  type        = bool
  default     = false
}

variable "regex_patterns" {
  description = "List of regex patterns to block"
  type        = list(string)
  default     = []
}

# ============================================
# LOGGING
# ============================================

variable "enable_waf_logging" {
  description = "Enable WAF logging to CloudWatch"
  type        = bool
  default     = true
}

variable "waf_log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "waf_redacted_fields" {
  description = "Fields to redact from WAF logs"
  type = list(object({
    type = string
    name = optional(string)
  }))
  default = [
    {
      type = "single_header"
      name = "authorization"
    },
    {
      type = "single_header"
      name = "cookie"
    }
  ]
}

# ============================================
# MONITORING
# ============================================

variable "enable_waf_alarms" {
  description = "Enable CloudWatch alarms for WAF"
  type        = bool
  default     = true
}

variable "blocked_requests_threshold" {
  description = "Threshold for blocked requests alarm"
  type        = number
  default     = 100
}

variable "rate_limited_threshold" {
  description = "Threshold for rate limited requests alarm"
  type        = number
  default     = 50
}

variable "alarm_actions" {
  description = "SNS topic ARNs for alarm notifications"
  type        = list(string)
  default     = []
}
