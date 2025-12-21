# ============================================
# Resource Limits Module
# ============================================
# Deploy LimitRange and ResourceQuota via Terraform

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38"
    }
  }
}

# ============================================
# Namespaces
# ============================================
resource "kubernetes_namespace" "managed_namespaces" {
  for_each = toset(var.namespaces)

  metadata {
    name = each.value
    labels = merge(
      {
        "managed-by" = "terraform"
        "resource-limits" = "enabled"
      },
      var.common_tags
    )
  }
}

# ============================================
# LimitRange - Default Resource Limits
# ============================================
resource "kubernetes_limit_range" "namespace_limits" {
  for_each = var.limit_ranges

  metadata {
    name      = "${each.key}-limit-range"
    namespace = each.value.namespace

    labels = merge(
      {
        "managed-by" = "terraform"
      },
      var.common_tags
    )
  }

  spec {
    # Container limits
    limit {
      type = "Container"

      # Default limits if not specified
      default = {
        cpu    = each.value.container_default_limit_cpu
        memory = each.value.container_default_limit_memory
      }

      # Default requests if not specified
      default_request = {
        cpu    = each.value.container_default_request_cpu
        memory = each.value.container_default_request_memory
      }

      # Maximum allowed
      max = {
        cpu    = each.value.container_max_cpu
        memory = each.value.container_max_memory
      }

      # Minimum allowed
      min = {
        cpu    = each.value.container_min_cpu
        memory = each.value.container_min_memory
      }
    }

    # Pod limits
    limit {
      type = "Pod"

      max = {
        cpu    = each.value.pod_max_cpu
        memory = each.value.pod_max_memory
      }

      min = {
        cpu    = each.value.pod_min_cpu
        memory = each.value.pod_min_memory
      }
    }
  }

  depends_on = [kubernetes_namespace.managed_namespaces]
}

# ============================================
# ResourceQuota - Namespace Total Limits
# ============================================
resource "kubernetes_resource_quota" "namespace_quotas" {
  for_each = var.resource_quotas

  metadata {
    name      = "${each.key}-quota"
    namespace = each.value.namespace

    labels = merge(
      {
        "managed-by" = "terraform"
      },
      var.common_tags
    )
  }

  spec {
    hard = {
      # CPU and Memory
      "requests.cpu"    = each.value.requests_cpu
      "requests.memory" = each.value.requests_memory
      "limits.cpu"      = each.value.limits_cpu
      "limits.memory"   = each.value.limits_memory

      # Object counts
      "pods"                   = each.value.max_pods
      "services"               = each.value.max_services
      "persistentvolumeclaims" = each.value.max_pvcs
      "configmaps"            = lookup(each.value, "max_configmaps", 50)
      "secrets"               = lookup(each.value, "max_secrets", 50)

      # Storage
      "requests.storage" = each.value.requests_storage
    }

    # Scope selectors (optional)
    dynamic "scope_selector" {
      for_each = lookup(each.value, "scope_selectors", [])
      content {
        dynamic "match_expression" {
          for_each = scope_selector.value.match_expressions
          content {
            scope_name = match_expression.value.scope_name
            operator   = match_expression.value.operator
            values     = match_expression.value.values
          }
        }
      }
    }
  }

  depends_on = [kubernetes_namespace.managed_namespaces]
}

# ============================================
# Priority Classes (Optional)
# ============================================
resource "kubernetes_priority_class" "custom_priorities" {
  for_each = var.priority_classes

  metadata {
    name = each.key
  }

  value               = each.value.value
  global_default      = lookup(each.value, "global_default", false)
  description         = lookup(each.value, "description", "")
  preemption_policy   = lookup(each.value, "preemption_policy", "PreemptLowerPriority")
}

# ============================================
# Pod Disruption Budgets (Optional)
# ============================================
resource "kubernetes_pod_disruption_budget_v1" "app_pdbs" {
  for_each = var.pod_disruption_budgets

  metadata {
    name      = each.key
    namespace = each.value.namespace

    labels = merge(
      {
        "managed-by" = "terraform"
      },
      var.common_tags
    )
  }

  spec {
    max_unavailable = lookup(each.value, "max_unavailable", null)
    min_available   = lookup(each.value, "min_available", null)

    selector {
      match_labels = each.value.selector_labels
    }
  }

  depends_on = [kubernetes_namespace.managed_namespaces]
}

# ============================================
# Network Policies (Optional)
# ============================================
resource "kubernetes_network_policy" "namespace_isolation" {
  for_each = var.enable_network_policies ? toset(var.namespaces) : []

  metadata {
    name      = "default-deny-ingress"
    namespace = each.value

    labels = merge(
      {
        "managed-by" = "terraform"
      },
      var.common_tags
    )
  }

  spec {
    pod_selector {}
    policy_types = ["Ingress"]
  }

  depends_on = [kubernetes_namespace.managed_namespaces]
}
