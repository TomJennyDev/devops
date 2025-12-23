# ArgoCD Bootstrap Pattern - GitOps Architecture

## 🎯 Overview

This document explains how we use **App-of-Apps pattern** to bootstrap the entire infrastructure with a single command.

## 🏗️ Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         YOU (Developer)                         │
│                                                                 │
│                    Run ONCE: ./scripts/bootstrap.sh            │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                    STEP 1: Deploy ArgoCD                        │
│                                                                 │
│  • Helm install ArgoCD                                          │
│  • Create namespace: argocd                                     │
│  • Wait for ArgoCD server to be ready                           │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                STEP 2: Create ArgoCD Projects                   │
│                                                                 │
│  • kubectl apply argocd/projects/infrastructure.yaml            │
│  • kubectl apply argocd/projects/applications.yaml              │
│                                                                 │
│  Purpose: Organize apps into logical groups                     │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│              STEP 3: Deploy Bootstrap Apps (App-of-Apps)        │
│                                                                 │
│  • kubectl apply argocd/bootstrap/infrastructure-apps-dev.yaml  │
│  • kubectl apply argocd/bootstrap/flowise-dev.yaml              │
│                                                                 │
│  🎯 THIS IS WHERE THE MAGIC HAPPENS!                            │
│  ArgoCD now manages all child applications automatically        │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                  ArgoCD Auto-Deploys Everything                 │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  infrastructure-apps-dev (App-of-Apps)                   │  │
│  │  ├─ aws-load-balancer-controller                         │  │
│  │  │  └─ Deploys ALB Controller to kube-system             │  │
│  │  │                                                        │  │
│  │  └─ prometheus-dev                                        │  │
│  │     └─ Deploys Prometheus to monitoring namespace        │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  flowise-dev (Application)                               │  │
│  │  └─ Deploys Flowise to flowise-dev namespace             │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  🔄 ArgoCD continuously watches Git repository                  │
│  🔄 Any Git push → ArgoCD auto-syncs → Changes deployed        │
└─────────────────────────────────────────────────────────────────┘
```

## 📂 Repository Structure

```
argocd/
├── bootstrap/                      # 🎯 Bootstrap Layer (You apply these)
│   ├── infrastructure-apps-dev.yaml   # App-of-Apps for infrastructure
│   ├── flowise-dev.yaml               # Application manifest
│   ├── flowise-production.yaml
│   └── flowise-staging.yaml
│
├── projects/                       # 🏢 ArgoCD Projects (Organizational)
│   ├── applications.yaml              # Project: applications
│   └── infrastructure.yaml            # Project: infrastructure
│
├── infrastructure/                 # 🛠️ Infrastructure Apps (Auto-deployed)
│   ├── aws-load-balancer-controller/
│   │   ├── base/
│   │   │   ├── kustomization.yaml
│   │   │   ├── namespace.yaml
│   │   │   └── helm-chart.yaml
│   │   └── overlays/
│   │       └── dev/
│   │           └── kustomization.yaml
│   │
│   └── prometheus/
│       ├── base/
│       └── overlays/
│           └── dev/
│
└── apps/                           # 📦 Application Apps (Auto-deployed)
    └── flowise/
        ├── base/
        └── overlays/
            ├── dev/
            ├── staging/
            └── production/
```

## 🔄 GitOps Workflow

### Initial Bootstrap (One Time)

```bash
# Run this ONCE to bootstrap everything
./scripts/bootstrap.sh
```

**What happens:**
1. ✅ ArgoCD installed
2. ✅ Projects created
3. ✅ App-of-Apps deployed
4. ✅ ArgoCD auto-deploys all child apps

### Day-to-Day Development (GitOps Pattern)

```bash
# 1. Make changes to your infrastructure/app manifests
vim argocd/infrastructure/prometheus/overlays/dev/values.yaml

# 2. Commit and push
git add .
git commit -m "feat: increase prometheus retention to 30d"
git push

# 3. ArgoCD automatically detects the change and syncs!
# (No kubectl apply needed! 🎉)
```

**ArgoCD will:**
- 🔍 Detect Git changes (every 3 minutes by default)
- 🔄 Auto-sync if `automated: {}` is enabled
- ✅ Apply changes to cluster
- 📊 Show sync status in UI

## 📋 App-of-Apps Pattern Explained

### What is App-of-Apps?

**App-of-Apps** is an ArgoCD pattern where:
- One "parent" Application manages multiple "child" Applications
- You only need to apply the parent
- ArgoCD auto-creates and manages all children

### Example: infrastructure-apps-dev.yaml

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: infrastructure-apps-dev
  namespace: argocd
spec:
  project: infrastructure

  # Parent app watches this path
  source:
    repoURL: https://github.com/TomJennyDev/devops.git
    targetRevision: main
    path: argocd/infrastructure  # 👈 Contains child app manifests

  destination:
    server: https://kubernetes.default.svc
    namespace: argocd

  syncPolicy:
    automated:  # 👈 Auto-sync enabled
      prune: true
      selfHeal: true
```

**What happens:**
1. ArgoCD reads `argocd/infrastructure/`
2. Finds Kustomize/Helm definitions
3. Auto-creates child Applications:
   - `aws-load-balancer-controller`
   - `prometheus-dev`
4. Each child deploys to its own namespace
5. All managed automatically!

## 🎯 Benefits of This Pattern

### 1. Single Source of Truth
- Everything defined in Git
- No manual `kubectl apply` needed
- Audit trail via Git history

### 2. Declarative Infrastructure
- Desired state in Git
- ArgoCD ensures actual state matches
- Self-healing if drift detected

### 3. Easy Rollback
```bash
git revert <commit>
git push
# ArgoCD auto-reverts the deployment!
```

### 4. Environment Promotion
```bash
# Promote staging to production
cp argocd/apps/flowise/overlays/staging/kustomization.yaml \
   argocd/apps/flowise/overlays/production/kustomization.yaml
git push
# ArgoCD auto-deploys to production!
```

### 5. Disaster Recovery
```bash
# Lost entire cluster? Just run:
./scripts/bootstrap.sh
# Everything rebuilds from Git! 🔥
```

## 🛠️ Adding New Applications

### Step 1: Create Application Manifests

```bash
# Create new app structure
mkdir -p argocd/apps/myapp/{base,overlays/dev}
```

### Step 2: Define Kubernetes Resources

```yaml
# argocd/apps/myapp/base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - service.yaml
  - ingress.yaml
```

### Step 3: Add to App-of-Apps

```yaml
# Create argocd/bootstrap/myapp-dev.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp-dev
  namespace: argocd
spec:
  project: applications
  source:
    repoURL: https://github.com/TomJennyDev/devops.git
    targetRevision: main
    path: argocd/apps/myapp/overlays/dev
  destination:
    server: https://kubernetes.default.svc
    namespace: myapp-dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### Step 4: Apply Bootstrap Manifest

```bash
kubectl apply -f argocd/bootstrap/myapp-dev.yaml

# Or just push to Git and ArgoCD auto-syncs (if main app-of-apps watches bootstrap/)
git add .
git commit -m "feat: add myapp to cluster"
git push
```

**Done!** ArgoCD will:
1. Create `myapp-dev` namespace
2. Deploy all resources
3. Watch for Git changes
4. Auto-sync on updates

## 🔍 Monitoring and Troubleshooting

### Check ArgoCD Applications

```bash
# List all apps
kubectl get applications -n argocd

# Describe specific app
kubectl describe application infrastructure-apps-dev -n argocd

# Watch sync status
kubectl get applications -n argocd -w
```

### ArgoCD CLI Commands

```bash
# List apps
argocd app list

# Get app details
argocd app get infrastructure-apps-dev

# Sync manually (if auto-sync disabled)
argocd app sync infrastructure-apps-dev

# Show app diff
argocd app diff flowise-dev
```

### Check Sync Status in UI

1. Port-forward ArgoCD:
   ```bash
   kubectl port-forward svc/argocd-server -n argocd 8080:443
   ```

2. Open: https://localhost:8080

3. View:
   - 🟢 Green = Synced and Healthy
   - 🟡 Yellow = Syncing or Progressing
   - 🔴 Red = Failed or Degraded

### Common Issues

#### 1. App Out of Sync
```bash
# Check what's different
argocd app diff flowise-dev

# Force sync
argocd app sync flowise-dev --force
```

#### 2. App Stuck in Progressing
```bash
# Check events
kubectl get events -n flowise-dev --sort-by='.lastTimestamp'

# Check pods
kubectl get pods -n flowise-dev
kubectl describe pod <pod-name> -n flowise-dev
```

#### 3. Git Repository Not Accessible
```bash
# Check ArgoCD repo credentials
argocd repo list

# Re-add repo
argocd repo add https://github.com/TomJennyDev/devops.git \
  --username <username> \
  --password <token>
```

## 📚 Advanced Patterns

### Multi-Environment App-of-Apps

```yaml
# argocd/bootstrap/root-app-dev.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root-app-dev
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/TomJennyDev/devops.git
    targetRevision: main
    path: argocd/bootstrap  # 👈 Watches bootstrap directory
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

**Result:** Single `kubectl apply` deploys ALL environments!

### Sync Waves (Ordered Deployment)

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"  # Deploy after wave 0
```

**Use case:** Deploy database before app

### Helm Values Override

```yaml
source:
  helm:
    values: |
      replicaCount: 3
      resources:
        limits:
          memory: "1Gi"
```

### Kustomize with Remote Bases

```yaml
source:
  kustomize:
    images:
      - myapp=myapp:v2.0.0  # Override image tag
```

## 🎓 Best Practices

1. **Always use `automated` sync policy** for GitOps workflow
2. **Enable `selfHeal`** to fix manual changes
3. **Enable `prune`** to remove deleted resources
4. **Use `CreateNamespace=true`** to auto-create namespaces
5. **Organize apps by project** (infrastructure vs applications)
6. **Use overlays** for environment-specific configs
7. **Set resource limits** in production overlays
8. **Use sync waves** for deployment order
9. **Test in dev** before promoting to staging/prod
10. **Document changes** in Git commit messages

## 🚀 Next Steps

1. ✅ Run `./scripts/bootstrap.sh` to deploy everything
2. ✅ Access ArgoCD UI and explore the app tree
3. ✅ Make a test change and push to Git
4. ✅ Watch ArgoCD auto-sync the change
5. ✅ Add your own application using the pattern above

**Happy GitOps-ing!** 🎉
