# ArgoCD Directory Structure

## 📂 Overview

Enterprise-grade GitOps repository structure for ArgoCD deployment management.

```
argocd/
├── bootstrap/          # ArgoCD Applications & App-of-Apps patterns
├── projects/           # ArgoCD Projects for RBAC
├── infrastructure/     # System-level components
├── apps/              # Business applications
├── config/            # Centralized configurations
└── docs/              # Documentation
```

---

## 📁 Directory Details

### `bootstrap/`

ArgoCD Application CRDs and App-of-Apps patterns for automated deployment.

```
bootstrap/
├── app-of-apps-dev.yaml           # Dev environment app-of-apps
├── app-of-apps-staging.yaml       # Staging environment
├── app-of-apps-prod.yaml          # Production environment
├── flowise-dev.yaml               # Flowise dev application
├── flowise-staging.yaml           # Flowise staging
└── flowise-production.yaml        # Flowise production
```

**Usage:**

```bash
# Deploy app-of-apps (bootstraps all apps in environment)
kubectl apply -f argocd/bootstrap/app-of-apps-dev.yaml

# Or deploy individual app
kubectl apply -f argocd/bootstrap/flowise-dev.yaml
```

---

### `projects/`

ArgoCD Projects for RBAC and resource isolation.

```
projects/
├── infrastructure.yaml  # Project for system components
└── applications.yaml    # Project for business apps
```

**Features:**

- ✅ RBAC policies (admin, developer, readonly roles)
- ✅ Source repo whitelisting
- ✅ Destination namespace restrictions
- ✅ Cluster/namespace resource controls

**Apply:**

```bash
kubectl apply -f argocd/projects/
```

---

### `infrastructure/`

System-level Kubernetes components (controllers, operators, monitoring).

```
infrastructure/
├── aws-load-balancer-controller/
│   ├── base/                    # Base Helm Application
│   └── overlays/
│       ├── dev/
│       ├── staging/
│       └── production/
│
└── prometheus/
    ├── base/
    └── overlays/
        ├── dev/
        ├── staging/
        └── prod/
```

**Belongs to:** `infrastructure` ArgoCD Project  
**Characteristics:**

- Deployed to system namespaces (`kube-system`, `monitoring`)
- Cluster-scoped resources allowed
- Restricted access (infra team only)

---

### `apps/`

Business applications and microservices.

```
apps/
└── flowise/
    ├── base/
    │   ├── deployment-server.yaml
    │   ├── deployment-ui.yaml
    │   ├── service-*.yaml
    │   └── kustomization.yaml
    └── overlays/
        ├── dev/
        │   ├── deployment-patch.yaml
        │   ├── ingress.yaml
        │   └── kustomization.yaml
        ├── staging/
        └── production/
```

**Belongs to:** `applications` ArgoCD Project  
**Characteristics:**

- Deployed to app namespaces (`flowise-*`, `app-*`)
- Namespace-scoped resources only
- Developer access allowed

**Add new app:**

```bash
mkdir -p apps/new-app/{base,overlays/{dev,staging,production}}
# Create manifests...
# Create Application CRD in bootstrap/
```

---

### `config/`

Centralized configuration management (Helm values, shared configs).

```
config/
├── argocd/
│   └── values.yaml              # ArgoCD Helm values
├── prometheus/
│   ├── dev-values.yaml
│   ├── staging-values.yaml
│   └── prod-values.yaml
└── shared/
    └── common-labels.yaml       # Shared labels/annotations
```

**Purpose:**

- Single source of truth for configs
- Environment-specific overrides
- Shared across multiple apps

**Usage in Application:**

```yaml
spec:
  source:
    helm:
      valueFiles:
        - ../../config/prometheus/dev-values.yaml
```

---

### `docs/`

Documentation files.

```
docs/
├── ARCHITECTURE.md
├── GETTING-STARTED.md
├── DEPLOYMENT-GUIDE.md
└── ...
```

---

## 🚀 Deployment Workflow

### 1. Initial Setup (One-time)

```bash
# Deploy ArgoCD Projects (RBAC)
kubectl apply -f argocd/projects/

# Deploy App-of-Apps (bootstraps all infrastructure + apps)
kubectl apply -f argocd/bootstrap/app-of-apps-dev.yaml
```

### 2. Deploy Individual App

```bash
# Deploy Flowise to dev
kubectl apply -f argocd/bootstrap/flowise-dev.yaml

# ArgoCD will automatically:
# - Clone repo
# - Read argocd/apps/flowise/overlays/dev/
# - Build Kustomize
# - Deploy to flowise-dev namespace
```

### 3. Update Application

```bash
# Make changes to manifests
vim argocd/apps/flowise/overlays/dev/deployment-patch.yaml

# Commit and push
git add argocd/apps/flowise/
git commit -m "Update flowise resources"
git push

# ArgoCD auto-syncs (if enabled)
# Or manual sync via UI/CLI
```

---

## 🔄 GitOps Flow

```
┌─────────────┐
│ Developer   │
│ pushes code │
└──────┬──────┘
       │
       ▼
┌─────────────────┐
│ GitHub Repo     │
│ argocd/apps/... │
└──────┬──────────┘
       │
       ▼
┌─────────────────┐
│ ArgoCD detects  │
│ changes & syncs │
└──────┬──────────┘
       │
       ▼
┌─────────────────┐
│ Kubernetes      │
│ resources       │
│ updated         │
└─────────────────┘
```

---

## 📋 Common Tasks

### Add New Environment

```bash
# 1. Create overlay
mkdir -p argocd/apps/flowise/overlays/qa

# 2. Create Application CRD
cp argocd/bootstrap/flowise-dev.yaml argocd/bootstrap/flowise-qa.yaml
# Edit: change name, namespace, path

# 3. Add to app-of-apps (optional)
```

### Add New Application

```bash
# 1. Create directory structure
mkdir -p argocd/apps/new-app/{base,overlays/{dev,staging,production}}

# 2. Create base manifests
# deployment.yaml, service.yaml, etc.

# 3. Create overlays with kustomization.yaml

# 4. Create Application CRDs
# argocd/bootstrap/new-app-dev.yaml

# 5. Add to projects if needed
```

### Update Helm Values

```bash
# Centralized config
vim argocd/config/prometheus/dev-values.yaml

# Commit & push
git add argocd/config/
git commit -m "Update prometheus config"
git push

# ArgoCD syncs automatically
```

---

## 🔐 Security Best Practices

1. **Use ArgoCD Projects for RBAC**
   - Separate `infrastructure` and `applications` projects
   - Define roles (admin, developer, readonly)
   - Whitelist source repos

2. **Secrets Management**
   - Never commit secrets to Git
   - Use Kubernetes Secrets
   - Consider Sealed Secrets or External Secrets Operator

3. **Resource Isolation**
   - Deploy to dedicated namespaces
   - Use resource quotas
   - Implement network policies

4. **Access Control**
   - Limit cluster-scoped resources
   - Namespace-scoped for apps
   - Audit trail via Git commits

---

## 📚 References

- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
- [GitOps Principles](https://opengitops.dev/)
- [Kustomize Documentation](https://kustomize.io/)
- [App of Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)

---

## 🆘 Troubleshooting

### Application stuck in "OutOfSync"

```bash
# Force sync
kubectl patch application -n argocd flowise-dev -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"syncStrategy":{"hook":{}}}}}' --type merge

# Or via CLI
argocd app sync flowise-dev --force
```

### Path not found error

```bash
# Verify path in Application CRD
kubectl get application -n argocd flowise-dev -o yaml | grep path

# Check repo structure
ls -la argocd/apps/flowise/overlays/dev/
```

### RBAC denied

```bash
# Check project permissions
kubectl get appproject -n argocd applications -o yaml

# Verify user roles
kubectl get rolebinding -n argocd
```
