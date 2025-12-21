# ============================================

# Resource Limits Module README

# ============================================

# Terraform Resource Limits Module

Deploy Kubernetes resource limits, quotas, and policies via Terraform.

## Features

- ✅ **LimitRange**: Auto-apply default CPU/Memory limits
- ✅ **ResourceQuota**: Limit total namespace resources
- ✅ **Priority Classes**: Pod scheduling priorities
- ✅ **Pod Disruption Budgets**: High availability
- ✅ **Network Policies**: Namespace isolation (optional)

## Usage

### Basic Example

```hcl
module "resource_limits" {
  source = "./modules/resource-limits"

  namespaces = ["default", "dev", "staging"]

  common_tags = {
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}
```

### Advanced Example with Custom Limits

```hcl
module "resource_limits" {
  source = "./modules/resource-limits"

  namespaces = ["default", "dev", "staging", "prod"]

  # LimitRange per namespace
  limit_ranges = {
    default = {
      namespace = "default"

      # Defaults applied to pods without resource specs
      container_default_limit_cpu      = "500m"
      container_default_limit_memory   = "512Mi"
      container_default_request_cpu    = "100m"
      container_default_request_memory = "128Mi"

      # Max/Min per container
      container_max_cpu    = "2000m"
      container_max_memory = "2Gi"
      container_min_cpu    = "50m"
      container_min_memory = "64Mi"

      # Max/Min per pod
      pod_max_cpu    = "4000m"
      pod_max_memory = "4Gi"
      pod_min_cpu    = "50m"
      pod_min_memory = "64Mi"
    }

    prod = {
      namespace = "prod"

      # Production: Higher defaults
      container_default_limit_cpu      = "1000m"
      container_default_limit_memory   = "1Gi"
      container_default_request_cpu    = "500m"
      container_default_request_memory = "512Mi"

      container_max_cpu    = "4000m"
      container_max_memory = "4Gi"
      container_min_cpu    = "100m"
      container_min_memory = "128Mi"

      pod_max_cpu    = "8000m"
      pod_max_memory = "16Gi"
      pod_min_cpu    = "100m"
      pod_min_memory = "128Mi"
    }
  }

  # ResourceQuota per namespace
  resource_quotas = {
    default = {
      namespace = "default"

      requests_cpu    = "4000m"   # 4 CPUs
      requests_memory = "8Gi"     # 8GB RAM
      limits_cpu      = "8000m"   # 8 CPUs
      limits_memory   = "16Gi"    # 16GB RAM

      max_pods     = 50
      max_services = 20
      max_pvcs     = 10

      requests_storage = "100Gi"
    }

    prod = {
      namespace = "prod"

      requests_cpu    = "8000m"
      requests_memory = "16Gi"
      limits_cpu      = "16000m"
      limits_memory   = "32Gi"

      max_pods     = 100
      max_services = 50
      max_pvcs     = 20

      requests_storage = "500Gi"
    }
  }

  # Priority classes
  priority_classes = {
    critical = {
      value       = 10000
      description = "Critical system workloads"
    }
    high = {
      value       = 1000
      description = "High priority workloads"
    }
    medium = {
      value       = 500
      description = "Normal workloads"
      global_default = true  # Default priority
    }
    low = {
      value       = 100
      description = "Low priority batch jobs"
    }
  }

  # Pod Disruption Budgets
  pod_disruption_budgets = {
    api-pdb = {
      namespace       = "prod"
      min_available   = "50%"
      selector_labels = {
        app = "api"
      }
    }
  }

  # Enable network isolation
  enable_network_policies = true

  common_tags = {
    Environment = "dev"
    ManagedBy   = "terraform"
    Project     = "my-project"
  }
}
```

## Outputs

```hcl
# List of managed namespaces
output "namespaces" {
  value = module.resource_limits.managed_namespaces
}

# LimitRanges created
output "limit_ranges" {
  value = module.resource_limits.limit_ranges
}

# ResourceQuotas created
output "quotas" {
  value = module.resource_limits.resource_quotas
}

# Summary
output "summary" {
  value = module.resource_limits.resource_summary
}
```

## Requirements

- Terraform >= 1.0
- Kubernetes Provider >= 2.38
- Kubernetes cluster with RBAC enabled

## Verification

```bash
# Check LimitRanges
kubectl describe limitrange -n default

# Check ResourceQuotas
kubectl describe resourcequota -n default

# Check Priority Classes
kubectl get priorityclasses

# Test with a pod
kubectl run test --image=nginx --limits=cpu=100m,memory=128Mi -n default
```
