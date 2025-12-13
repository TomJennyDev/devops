# ==================================================
# ECR Module Variables
# ==================================================

variable "repositories" {
  description = "Map of ECR repositories to create"
  type = map(object({
    image_tag_mutability = optional(string, "MUTABLE")        # MUTABLE or IMMUTABLE
    scan_on_push         = optional(bool, true)               # Enable image scanning
    max_image_count      = optional(number, 30)               # Keep last N images
    untagged_days        = optional(number, 7)                # Delete untagged images after N days
    repository_policy    = optional(string, null)             # JSON policy document
    tags                 = optional(map(string), {})          # Additional tags
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.repositories :
      contains(["MUTABLE", "IMMUTABLE"], v.image_tag_mutability)
    ])
    error_message = "image_tag_mutability must be either MUTABLE or IMMUTABLE."
  }
}

variable "encryption_type" {
  description = "Encryption type to use (AES256 or KMS)"
  type        = string
  default     = "AES256"

  validation {
    condition     = contains(["AES256", "KMS"], var.encryption_type)
    error_message = "encryption_type must be either AES256 or KMS."
  }
}

variable "kms_key_arn" {
  description = "ARN of KMS key for encryption (required if encryption_type is KMS)"
  type        = string
  default     = null
}

variable "force_delete" {
  description = "If true, will delete repository even if it contains images"
  type        = bool
  default     = false
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "pull_through_cache_rules" {
  description = "Map of pull through cache rules for caching public images"
  type = map(object({
    upstream_registry_url = string
    credential_arn        = optional(string, null)
  }))
  default = {}

  # Example:
  # pull_through_cache_rules = {
  #   "docker-hub" = {
  #     upstream_registry_url = "registry-1.docker.io"
  #   }
  #   "quay" = {
  #     upstream_registry_url = "quay.io"
  #   }
  # }
}
