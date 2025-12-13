# ============================================
# Resource Limits Module Outputs
# ============================================

output "managed_namespaces" {
  description = "List of managed namespaces"
  value       = [for ns in kubernetes_namespace.managed_namespaces : ns.metadata[0].name]
}

output "limit_ranges" {
  description = "LimitRange resources created"
  value = {
    for k, lr in kubernetes_limit_range.namespace_limits : k => {
      name      = lr.metadata[0].name
      namespace = lr.metadata[0].namespace
    }
  }
}

output "resource_quotas" {
  description = "ResourceQuota resources created"
  value = {
    for k, rq in kubernetes_resource_quota.namespace_quotas : k => {
      name      = rq.metadata[0].name
      namespace = rq.metadata[0].namespace
      hard      = rq.spec[0].hard
    }
  }
}

output "priority_classes" {
  description = "Priority classes created"
  value = {
    for k, pc in kubernetes_priority_class.custom_priorities : k => {
      name  = pc.metadata[0].name
      value = pc.value
    }
  }
}

output "resource_summary" {
  description = "Summary of resource configurations"
  value = {
    namespaces_managed       = length(kubernetes_namespace.managed_namespaces)
    limit_ranges_created     = length(kubernetes_limit_range.namespace_limits)
    resource_quotas_created  = length(kubernetes_resource_quota.namespace_quotas)
    priority_classes_created = length(kubernetes_priority_class.custom_priorities)
  }
}
