# ========================================

# RESOURCE CONFLICT ANALYSIS

# ========================================

# Date: 2025-12-08

# Environment: DEV

## 📊 Node Capacity (t3.medium)

- **CPU**: 2 vCPUs (2000m)
- **Memory**: 4GB (4096Mi)
- **System Reserved**: ~300m CPU, ~512Mi RAM
- **Available for pods**: ~1700m CPU, ~3584Mi RAM

---

## 🔍 Current Service Resources

### 1. ArgoCD (namespace: argocd)

```yaml
Server:
  requests: 250m CPU, 256Mi RAM
  limits:   500m CPU, 512Mi RAM

Repo Server:
  requests: 250m CPU, 256Mi RAM
  limits:   500m CPU, 512Mi RAM

Application Controller:
  requests: 500m CPU, 512Mi RAM
  limits:   1000m CPU, 1Gi RAM

Total ArgoCD:
  requests: 1000m CPU, 1024Mi RAM
  limits:   2000m CPU, 2560Mi RAM
```

### 2. Prometheus Stack (namespace: monitoring)

```yaml
Prometheus Server:
  requests: 150m CPU, 512Mi RAM
  limits:   400m CPU, 1Gi RAM

Grafana:
  requests: 100m CPU, 256Mi RAM
  limits:   200m CPU, 512Mi RAM

AlertManager:
  requests: ~50m CPU, ~128Mi RAM
  limits:   ~100m CPU, ~256Mi RAM

Node Exporter (DaemonSet):
  requests: ~50m CPU, ~100Mi RAM
  limits:   ~100m CPU, ~200Mi RAM

Total Monitoring:
  requests: ~350m CPU, ~1000Mi RAM
  limits:   ~800m CPU, ~2000Mi RAM
```

### 3. System Pods (kube-system)

```yaml
CoreDNS (2 replicas):
  requests: ~200m CPU, ~140Mi RAM
  limits:   ~400m CPU, ~280Mi RAM

AWS Load Balancer Controller:
  requests: ~100m CPU, ~128Mi RAM
  limits:   ~200m CPU, ~256Mi RAM

VPC CNI, kube-proxy:
  requests: ~100m CPU, ~128Mi RAM
  limits:   ~200m CPU, ~256Mi RAM

Total System:
  requests: ~400m CPU, ~400Mi RAM
  limits:   ~800m CPU, ~800Mi RAM
```

---

## ⚠️ RESOURCE CONFLICT DETECTED

### Total Requests (minimum needed)

```
ArgoCD:     1000m CPU + 1024Mi RAM
Monitoring:  350m CPU + 1000Mi RAM
System:      400m CPU +  400Mi RAM
-------------------------------------------
TOTAL:      1750m CPU + 2424Mi RAM
```

### Total Limits (maximum burst)

```
ArgoCD:     2000m CPU + 2560Mi RAM
Monitoring:  800m CPU + 2000Mi RAM
System:      800m CPU +  800Mi RAM
-------------------------------------------
TOTAL:      3600m CPU + 5360Mi RAM
```

### Node Capacity

```
Available:  1700m CPU + 3584Mi RAM
Required:   1750m CPU + 2424Mi RAM
```

## 🚨 CONFLICTS

1. **CPU Requests**: 1750m > 1700m (OVER by 50m)
   - ❌ Not enough CPU to schedule all pods!

2. **Memory Requests**: 2424Mi < 3584Mi (OK)
   - ✅ Memory requests fit

3. **CPU Limits**: 3600m > 2000m (212% overcommit)
   - ⚠️ High overcommit, may cause throttling

4. **Memory Limits**: 5360Mi > 4096Mi (130% overcommit)
   - ⚠️ Risk of OOM kills

---

## 🎯 RECOMMENDATIONS

### Option 1: Reduce ResourceQuota (Recommended for Dev)

```hcl
# terraform-eks/environments/dev/terraform.tfvars

resource_quotas = {
  default = {
    namespace = "default"

    # REDUCED - Allow more headroom
    requests_cpu    = "500m"    # Was: 2000m
    requests_memory = "1Gi"     # Was: 4Gi
    limits_cpu      = "1000m"   # Was: 4000m
    limits_memory   = "2Gi"     # Was: 8Gi

    max_pods     = 10           # Was: 20
    max_services = 5            # Was: 10
    max_pvcs     = 3            # Was: 5

    requests_storage = "20Gi"   # Was: 50Gi
  }

  argocd = {
    namespace = "argocd"

    # REALISTIC - Match actual usage
    requests_cpu    = "1200m"   # Was: 3000m
    requests_memory = "1500Mi"  # Was: 6Gi
    limits_cpu      = "2500m"   # Was: 6000m
    limits_memory   = "3Gi"     # Was: 12Gi

    max_pods     = 15
    max_services = 10
    max_pvcs     = 3

    requests_storage = "20Gi"
  }

  # ADD monitoring namespace
  monitoring = {
    namespace = "monitoring"

    requests_cpu    = "500m"
    requests_memory = "1500Mi"
    limits_cpu      = "1000m"
    limits_memory   = "2500Mi"

    max_pods     = 20
    max_services = 10
    max_pvcs     = 5

    requests_storage = "50Gi"
  }
}
```

### Option 2: Scale Up Node (More Expensive)

```hcl
# Switch to t3.large for more resources
node_group_instance_types = ["t3.large"]
# t3.large: 2 vCPU → 4 vCPU, 4GB → 8GB RAM
# Cost: ~$60/month → ~$120/month
```

### Option 3: Reduce Service Resources

```yaml
# argocd-values.yaml - Reduce ArgoCD resources
controller:
  resources:
    requests:
      cpu: 250m      # Was: 500m
      memory: 256Mi  # Was: 512Mi
    limits:
      cpu: 500m      # Was: 1000m
      memory: 512Mi  # Was: 1Gi

# prometheus dev-values.yaml - Reduce Prometheus
prometheus:
  prometheusSpec:
    resources:
      requests:
        cpu: 100m      # Was: 150m
        memory: 256Mi  # Was: 512Mi
      limits:
        cpu: 200m      # Was: 400m
        memory: 512Mi  # Was: 1Gi
```

### Option 4: Vertical Pod Autoscaler (Advanced)

```hcl
# Enable VPA to auto-adjust resources
enable_vpa = true
```

---

## 📊 Revised Calculation (Option 1)

### After reducing quotas

```
Available Node:  1700m CPU, 3584Mi RAM

Reserved:
  ArgoCD:        1000m CPU, 1024Mi RAM
  Monitoring:     350m CPU, 1000Mi RAM  
  System:         400m CPU,  400Mi RAM
  Default NS:     500m CPU, 1000Mi RAM (quota)
  ----------------------------------------
  TOTAL:         2250m CPU, 3424Mi RAM

Status:
  CPU:    2250m > 1700m ❌ Still over!
  Memory: 3424Mi < 3584Mi ✅ OK
```

### Best Solution: Combination

```hcl
# 1. Reduce default namespace quota
default = {
  requests_cpu = "300m"      # Minimal for dev testing
  requests_memory = "512Mi"
}

# 2. Accurate quotas for existing services
argocd = {
  requests_cpu = "1100m"     # Actual usage + 10% buffer
  requests_memory = "1200Mi"
}

monitoring = {
  requests_cpu = "400m"
  requests_memory = "1200Mi"
}
```

### Final Calculation

```
Available:    1700m CPU, 3584Mi RAM
Reserved:
  System:       400m CPU,  400Mi RAM
  ArgoCD:      1100m CPU, 1200Mi RAM
  Monitoring:   400m CPU, 1200Mi RAM
  Default:      300m CPU,  512Mi RAM
  -----------------------------------------
  TOTAL:       2200m CPU, 3312Mi RAM

Headroom:    -500m CPU, +272Mi RAM

❌ Still need to either:
   - Scale to t3.large (4 vCPU)
   - OR reduce service resources
   - OR disable monitoring in dev
```

---

## ✅ FINAL RECOMMENDATION

**For t3.medium (single node dev):**

```hcl
# Disable monitoring in dev, or use minimal config
enable_monitoring = false

# OR reduce ArgoCD resources
# argocd-values.yaml
controller:
  resources:
    requests: { cpu: 250m, memory: 256Mi }
    limits: { cpu: 500m, memory: 512Mi }

# Minimal quotas
resource_quotas = {
  default = {
    requests_cpu = "300m"
    requests_memory = "512Mi"
    max_pods = 10
  }

  argocd = {
    requests_cpu = "1000m"
    requests_memory = "1Gi"
    max_pods = 10
  }
}
```

**This gives you:**

```
System:    400m CPU,  400Mi RAM
ArgoCD:   1000m CPU, 1000Mi RAM
Default:   300m CPU,  512Mi RAM
---------------------------------
TOTAL:    1700m CPU, 1912Mi RAM ✅ FITS!

Headroom: 0m CPU, 1672Mi RAM
```
