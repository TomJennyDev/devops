# ============================================
# Resource Limits Module Variables
# ============================================

variable "namespaces" {
  description = "List of namespaces to create and manage"
  type        = list(string)
  default     = ["default", "dev", "staging", "prod"]
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

# ============================================
# LimitRange Configuration
# ============================================
variable "limit_ranges" {
  description = "LimitRange configurations per namespace"
  type = map(object({
    namespace = string

    # Container defaults
    container_default_limit_cpu      = string
    container_default_limit_memory   = string
    container_default_request_cpu    = string
    container_default_request_memory = string

    # Container max/min
    container_max_cpu    = string
    container_max_memory = string
    container_min_cpu    = string
    container_min_memory = string

    # Pod max/min
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

# ============================================
# ResourceQuota Configuration
# ============================================
variable "resource_quotas" {
  description = "ResourceQuota configurations per namespace"
  type = map(object({
    namespace = string

    # Resource limits
    requests_cpu    = string
    requests_memory = string
    limits_cpu      = string
    limits_memory   = string

    # Object counts
    max_pods     = number
    max_services = number
    max_pvcs     = number

    # Storage
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

# ============================================
# Priority Classes
# ============================================
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

# ============================================
# Pod Disruption Budgets
# ============================================
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

# ============================================
# Network Policies
# ============================================
variable "enable_network_policies" {
  description = "Enable default network policies for namespaces"
  type        = bool
  default     = false
}
