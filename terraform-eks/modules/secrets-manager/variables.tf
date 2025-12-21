# ========================================
# SECRETS MANAGER MODULE - VARIABLES
# ========================================

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "secrets" {
  description = "Map of secrets to create in Secrets Manager"
  type = map(object({
    description = string
    type        = string # e.g., "database", "api-key", "password"
    value       = map(string)
  }))
  default = {}
}

variable "recovery_window_days" {
  description = "Number of days AWS waits before permanently deleting secret"
  type        = number
  default     = 7
  validation {
    condition     = var.recovery_window_days >= 7 && var.recovery_window_days <= 30
    error_message = "Recovery window must be between 7 and 30 days."
  }
}

variable "create_access_policy" {
  description = "Create IAM policy for secret access"
  type        = bool
  default     = true
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
