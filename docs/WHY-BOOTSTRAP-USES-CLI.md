# Tại sao Bootstrap Script dùng CLI? (Anti-pattern)

## ❌ Vấn đề: Bootstrap script hiện tại

```bash
# scripts/bootstrap.sh
kubectl apply -f argocd/bootstrap/infrastructure-apps-dev.yaml  ❌
kubectl apply -f argocd/bootstrap/flowise-dev.yaml              ❌
```

### Tại sao đây là Anti-pattern?

1. **Phá vỡ GitOps principles**
   - Git KHÔNG phải single source of truth
   - Manual `kubectl apply` = imperative command
   - ArgoCD không track được resources này

2. **Không có drift detection**
   - Nếu ai đó chỉnh sửa trực tiếp trên cluster
   - ArgoCD không tự động revert về Git state
   - Mất đi lợi ích của self-healing

3. **Không có audit trail**
   - Không biết khi nào resources được tạo/xóa
   - Không có Git history cho bootstrap apps
   - Khó rollback nếu có vấn đề

4. **Không consistent**
   - Bootstrap apps: kubectl apply (imperative)
   - Other apps: ArgoCD sync (declarative)
   - Hai cách quản lý khác nhau cho cùng cluster

## ✅ Giải pháp: True GitOps Way

### Approach 1: Root App-of-Apps (Recommended)

```yaml
# argocd/root-bootstrap.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: bootstrap
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/TomJennyDev/devops.git
    path: argocd/bootstrap
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

**Bootstrap script chỉ cần:**
```bash
# ONE kubectl apply
kubectl apply -f argocd/root-bootstrap.yaml

# DONE! ArgoCD manages everything else from Git
```

**Flow:**
```
kubectl apply root-bootstrap.yaml (ONCE)
    ↓
ArgoCD syncs argocd/bootstrap/ from Git
    ↓
ArgoCD creates infrastructure-apps-dev Application
    ↓
ArgoCD creates flowise-dev Application
    ↓
ArgoCD syncs all resources automatically
    ↓
Everything managed from Git!
```

### Approach 2: ApplicationSet (Advanced)

```yaml
# argocd/bootstrap-appset.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: bootstrap-apps
  namespace: argocd
spec:
  generators:
  - git:
      repoURL: https://github.com/TomJennyDev/devops.git
      revision: main
      directories:
      - path: argocd/bootstrap/*
  template:
    metadata:
      name: '{{path.basename}}'
    spec:
      source:
        repoURL: https://github.com/TomJennyDev/devops.git
        path: '{{path}}'
      destination:
        server: https://kubernetes.default.svc
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

## Comparison

| Aspect | CLI (Current ❌) | GitOps (Correct ✅) |
|--------|------------------|---------------------|
| **Single source of truth** | ❌ No | ✅ Git |
| **Drift detection** | ❌ No | ✅ Auto-detect |
| **Self-healing** | ❌ No | ✅ Auto-fix |
| **Audit trail** | ❌ No | ✅ Git history |
| **Rollback** | ❌ Manual | ✅ Git revert |
| **Manual steps** | ❌ Many | ✅ One kubectl |

## Why Bootstrap Script Uses CLI? (Historical Reasons)

### 1. Chicken-and-Egg Problem
```
Need ArgoCD → to deploy apps
But ArgoCD itself → needs to be deployed first
```

**Solution:** 
- Deploy ArgoCD via Helm/kubectl (acceptable)
- Then ONE `kubectl apply` for root app
- Everything else via ArgoCD

### 2. Legacy Pattern
Many tutorials show:
```bash
kubectl apply -f app1.yaml
kubectl apply -f app2.yaml
...
```

But modern GitOps uses:
```bash
kubectl apply -f root-app.yaml  # Once
# ArgoCD handles the rest
```

### 3. Lack of Understanding
Developers think:
> "ArgoCD is just another deployment tool"

But ArgoCD is:
> "Continuous sync from Git to Cluster"

## The ONLY Acceptable kubectl apply

```bash
# 1. Install ArgoCD (one-time)
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 2. Create root app (one-time)
kubectl apply -f argocd/root-bootstrap.yaml

# 3. DONE - Never kubectl apply again!
git push  # ArgoCD auto-syncs
```

## Migration Path

### Current (3 kubectl applies):
```bash
kubectl apply -f projects/applications.yaml        # ❌
kubectl apply -f bootstrap/infrastructure-apps.yaml # ❌
kubectl apply -f bootstrap/flowise-dev.yaml        # ❌
```

### After Migration (1 kubectl apply):
```bash
kubectl apply -f argocd/root-bootstrap.yaml  # ✅
# ArgoCD deploys everything else from Git
```

## Benefits of True GitOps

1. **Git as Single Source of Truth**
   ```bash
   git push  # Update config
   # ArgoCD auto-syncs (no kubectl needed)
   ```

2. **Automatic Drift Detection**
   ```bash
   # Someone manually edits cluster
   kubectl edit deployment flowise-server
   # ArgoCD detects drift and reverts (self-heal)
   ```

3. **Easy Rollback**
   ```bash
   git revert HEAD  # Rollback last change
   git push
   # ArgoCD auto-syncs to previous state
   ```

4. **Full Audit Trail**
   ```bash
   git log argocd/apps/  # See all changes
   git blame ingress.yaml  # Who changed WAF ARN?
   ```

## Recommendation

✅ **Update bootstrap.sh to:**
1. Deploy ArgoCD (Helm/kubectl - acceptable)
2. Apply root-bootstrap.yaml (ONE kubectl apply)
3. Watch ArgoCD sync everything from Git

❌ **Never do:**
```bash
kubectl apply -f app.yaml  # After bootstrap
kubectl edit deployment    # Direct cluster edit
```

✅ **Always do:**
```bash
git commit -m "update"
git push origin main
# Let ArgoCD sync
```

## Implementation

See: `argocd/root-bootstrap.yaml` (created)
Updated: `scripts/bootstrap.sh` (fixed)
