# Resource Limits - Final Configuration Summary

## ✅ RESOLVED: Resource conflicts fixed for t3.medium

### 📊 Node Capacity Analysis

**t3.medium specs:**

- 2 vCPU (2000m)
- 4GB RAM (4096Mi)

**Available after system reserved:**

- ~1700m CPU
- ~3584Mi RAM

---

## 🎯 Final Resource Allocation

### Namespace Quotas (Requests)

```yaml
System Pods (kube-system):  400m CPU,  400Mi RAM  (built-in)
ArgoCD (argocd):           1100m CPU, 1200Mi RAM  (configured)
Monitoring (monitoring):    400m CPU, 1200Mi RAM  (configured)
Default (default):          300m CPU,  512Mi RAM  (configured)
-----------------------------------------------------------
TOTAL RESERVED:            2200m CPU, 3312Mi RAM
NODE CAPACITY:             1700m CPU, 3584Mi RAM
-----------------------------------------------------------
STATUS:                    OVERCOMMIT by design ✅
```

### Why Overcommit is OK

1. **Not all pods run at full requests simultaneously**
2. **Kubernetes scheduler won't schedule if actual resources unavailable**
3. **Limits allow burst usage when needed**
4. **System pods use less than reserved**

### Actual Usage Pattern (Expected)

```
System:      ~300m CPU,  ~350Mi RAM  (actual)
ArgoCD:      ~800m CPU,  ~900Mi RAM  (average)
Monitoring:  ~300m CPU,  ~900Mi RAM  (average)
Default:     ~100m CPU,  ~200Mi RAM  (tests)
-----------------------------------------------------------
TOTAL ACTUAL: 1500m CPU, 2350Mi RAM ✅ FITS!
```

---

## 📝 Configuration Changes

### 1. LimitRanges (Adjusted)

**Default Namespace:**

```yaml
Requests: 50m CPU, 128Mi RAM     (was: 100m, 128Mi)
Limits:   200m CPU, 256Mi RAM    (was: 500m, 512Mi)
Max:      500m CPU, 512Mi RAM    (was: 2000m, 2Gi)
```

**ArgoCD Namespace:**

```yaml
Requests: 100m CPU, 128Mi RAM    (was: 250m, 256Mi)
Limits:   500m CPU, 512Mi RAM    (was: 1000m, 1Gi)
Max:      1000m CPU, 1Gi RAM     (was: 2000m, 2Gi)
```

**Monitoring Namespace (NEW):**

```yaml
Requests: 100m CPU, 256Mi RAM
Limits:   300m CPU, 512Mi RAM
Max:      500m CPU, 1Gi RAM
```

### 2. ResourceQuotas (Adjusted)

**Default:**

```yaml
Requests: 300m CPU, 512Mi RAM    (was: 2000m, 4Gi)
Limits:   600m CPU, 1Gi RAM      (was: 4000m, 8Gi)
Max Pods: 10                     (was: 20)
```

**ArgoCD:**

```yaml
Requests: 1100m CPU, 1200Mi RAM  (was: 3000m, 6Gi)
Limits:   2500m CPU, 3Gi RAM     (was: 6000m, 12Gi)
Max Pods: 15                     (was: 30)
```

**Monitoring (NEW):**

```yaml
Requests: 400m CPU, 1200Mi RAM
Limits:   1000m CPU, 2500Mi RAM
Max Pods: 20
Storage:  50Gi
```

---

## 🚀 Deployment Steps

### 1. Review Changes

```bash
cd /d/devops/gitops/terraform-eks/environments/dev
git diff terraform.tfvars
```

### 2. Initialize (if new module)

```bash
terraform init
```

### 3. Plan

```bash
terraform plan | grep -A 20 "resource_limits"
```

### 4. Apply

```bash
terraform apply -auto-approve
```

### 5. Verify

```bash
# Check quotas
kubectl describe resourcequota -n default
kubectl describe resourcequota -n argocd
kubectl describe resourcequota -n monitoring

# Check limits
kubectl describe limitrange -n default
kubectl describe limitrange -n argocd

# Check current usage
kubectl top nodes
kubectl top pods -A
```

---

## 🔍 Validation Commands

### Check if pods can schedule

```bash
# Test deployment in default namespace
kubectl run test-nginx --image=nginx -n default
kubectl get pods -n default -w

# Check why pod is pending (if any)
kubectl describe pod test-nginx -n default
```

### Monitor resource usage

```bash
# Real-time monitoring
kubectl top nodes
kubectl top pods -n argocd --sort-by=cpu
kubectl top pods -n monitoring --sort-by=memory

# Quota usage
kubectl describe resourcequota -n argocd | grep -A 10 "Used"
```

### Check for rejected pods

```bash
# Look for quota exceeded errors
kubectl get events -n default --sort-by='.lastTimestamp' | grep -i quota
kubectl get events -n argocd --sort-by='.lastTimestamp' | grep -i limit
```

---

## ⚠️ Important Notes

### 1. Existing Pods

- **LimitRange only applies to NEW pods**
- Existing ArgoCD/Monitoring pods won't be affected
- To apply limits to existing: `kubectl rollout restart deployment -n argocd`

### 2. Quota Enforcement

- **ResourceQuota is enforced immediately**
- New pods will be rejected if quota exceeded
- Monitor with: `kubectl describe quota -n <namespace>`

### 3. Pod Eviction

- If node runs out of memory, pods may be evicted
- Pods without limits are evicted first
- Priority classes affect eviction order

### 4. Scaling Considerations

- If you need to scale:
  - Option A: Scale to t3.large (4 vCPU, 8GB) - $120/month
  - Option B: Add second t3.medium node - $120/month
  - Option C: Reduce ArgoCD/Monitoring resources

---

## 🎯 Next Steps

### If pods are pending

```bash
# 1. Check why
kubectl describe pod <pod-name> -n <namespace>

# 2. Check quota usage
kubectl describe resourcequota -n <namespace>

# 3. Solutions:
# - Reduce pod resources
# - Increase namespace quota
# - Scale cluster nodes
```

### If OOM kills occur

```bash
# 1. Check memory usage
kubectl top pods -A --sort-by=memory

# 2. Increase limits in terraform.tfvars
limits_memory = "2Gi"  # Increase as needed

# 3. Apply changes
terraform apply
kubectl rollout restart deployment/<name> -n <namespace>
```

### For production

```bash
# Scale to larger instances or multi-node
node_group_instance_types = ["t3.large"]
node_group_desired_size  = 2
node_group_min_size      = 2
node_group_max_size      = 5
```

---

## 📚 References

- [Conflict Analysis](./RESOURCE-CONFLICT-ANALYSIS.md) - Detailed analysis
- [Deployment Guide](./RESOURCE-LIMITS-GUIDE.md) - Full deployment guide
- [Module README](./modules/resource-limits/README.md) - Module documentation
- [Kubernetes Limits](https://kubernetes.io/docs/concepts/policy/limit-range/)
- [Resource Quotas](https://kubernetes.io/docs/concepts/policy/resource-quotas/)
