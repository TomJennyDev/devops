# GitHub Actions ArgoCD Integration Setup

Hướng dẫn setup ArgoCD để hoạt động với GitHub Actions workflow.

## Prerequisites

- ✅ ArgoCD đã deployed (xem [ARGOCD-DEPLOYMENT.md](./ARGOCD-DEPLOYMENT.md))
- ✅ GitHub repository: `TomJennyDev/flowise-gitops` (chứa Kustomize overlays)
- ✅ GitHub repository: `TomJennyDev/Flowise` (source code)

## 1. ArgoCD Configuration

### A. Repository Credentials

Nếu `flowise-gitops` là private repo, thêm credentials:

```bash
# Via CLI
argocd login argocd.do2506.click --username admin

# Add repository
argocd repo add https://github.com/TomJennyDev/flowise-gitops.git \
  --username TomJennyDev \
  --password <github-personal-access-token> \
  --name flowise-gitops

# Verify
argocd repo list
```

**Via UI:**
1. Settings → Repositories → Connect Repo
2. Method: HTTPS
3. Project: default
4. Repository URL: `https://github.com/TomJennyDev/flowise-gitops.git`
5. Username: `TomJennyDev`
6. Password: `<github-token>`

### B. Create API Token for GitHub Actions

```bash
# Login
argocd login argocd.do2506.click --username admin

# Create account for CI/CD (if not exists)
argocd account list

# Generate token (expires in 1 year)
argocd account generate-token --account admin --id github-actions

# Or create dedicated CI/CD user
argocd account update-password --account cicd --new-password <secure-password>
argocd account generate-token --account cicd --id github-actions
```

**Save token** → GitHub Secrets as `ARGOCD_AUTH_TOKEN`

## 2. Create ArgoCD Applications

### Dev Environment

```yaml
# argocd/applications/flowise-dev.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: flowise-dev
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  
  source:
    repoURL: https://github.com/TomJennyDev/flowise-gitops.git
    targetRevision: main
    path: overlays/dev
  
  destination:
    server: https://kubernetes.default.svc
    namespace: flowise-dev
  
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

### Staging Environment

```yaml
# argocd/applications/flowise-staging.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: flowise-staging
  namespace: argocd
spec:
  project: default
  
  source:
    repoURL: https://github.com/TomJennyDev/flowise-gitops.git
    targetRevision: main
    path: overlays/staging
  
  destination:
    server: https://kubernetes.default.svc
    namespace: flowise-staging
  
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### Production Environment

```yaml
# argocd/applications/flowise-production.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: flowise-production
  namespace: argocd
spec:
  project: default
  
  source:
    repoURL: https://github.com/TomJennyDev/flowise-gitops.git
    targetRevision: main
    path: overlays/production
  
  destination:
    server: https://kubernetes.default.svc
    namespace: flowise-production
  
  syncPolicy:
    automated:
      prune: true
      selfHeal: false  # Manual approval for production
    syncOptions:
      - CreateNamespace=true
```

**Apply applications:**

```bash
kubectl apply -f argocd/applications/flowise-dev.yaml
kubectl apply -f argocd/applications/flowise-staging.yaml
kubectl apply -f argocd/applications/flowise-production.yaml

# Verify
argocd app list
argocd app get flowise-dev
```

## 3. GitHub Secrets Setup

Add these secrets to GitHub repository:

### Required Secrets

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `AWS_ACCESS_KEY_ID` | `AKIA...` | AWS credentials for ECR |
| `AWS_SECRET_ACCESS_KEY` | `xxx...` | AWS secret key |
| `GITOPS_TOKEN` | `ghp_...` | GitHub PAT with repo access |
| `ARGOCD_SERVER` | `argocd.do2506.click` | ArgoCD server URL |
| `ARGOCD_AUTH_TOKEN` | `eyJ...` | ArgoCD API token (from step 2B) |
| `DEV_ENDPOINT` | `https://flowise-dev.do2506.click` | Dev health check endpoint |
| `STAGING_ENDPOINT` | `https://flowise-staging.do2506.click` | Staging endpoint |
| `PROD_ENDPOINT` | `https://flowise.do2506.click` | Prod endpoint |

### Optional (for OIDC)

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `AWS_ROLE_TO_ASSUME` | `arn:aws:iam::xxx:role/github-actions` | For OIDC auth |

**Add via GitHub UI:**
1. Repository → Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Add each secret above

## 4. GitOps Repository Structure

`flowise-gitops` repository should have:

```
flowise-gitops/
├── base/
│   ├── kustomization.yaml
│   ├── deployment-server.yaml
│   ├── deployment-ui.yaml
│   ├── service-server.yaml
│   ├── service-ui.yaml
│   └── ingress.yaml
└── overlays/
    ├── dev/
    │   ├── kustomization.yaml
    │   ├── namespace.yaml
    │   └── patches/
    ├── staging/
    │   ├── kustomization.yaml
    │   └── patches/
    └── production/
        ├── kustomization.yaml
        └── patches/
```

**Example `overlays/dev/kustomization.yaml`:**

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: flowise-dev

resources:
  - ../../base
  - namespace.yaml

images:
  - name: flowise-server
    newName: 372836560690.dkr.ecr.ap-southeast-1.amazonaws.com/flowise-server
    newTag: abc1234  # Updated by GitHub Actions
  - name: flowise-ui
    newName: 372836560690.dkr.ecr.ap-southeast-1.amazonaws.com/flowise-ui
    newTag: abc1234  # Updated by GitHub Actions

replicas:
  - name: flowise-server
    count: 2
  - name: flowise-ui
    count: 2

commonLabels:
  environment: dev
```

## 5. Verify Workflow

### Test Manual Trigger

```bash
# Go to GitHub Actions
# Click "Deploy to Kubernetes via ArgoCD"
# Click "Run workflow"
# Select:
#   - Environment: dev
#   - Tag: (leave empty for auto-generation)
#   - Node version: 20
# Click "Run workflow"
```

### Monitor Deployment

```bash
# Watch GitHub Actions logs

# Check ArgoCD sync
argocd app get flowise-dev --refresh

# Watch pods
kubectl get pods -n flowise-dev -w

# Check deployment
kubectl get deploy -n flowise-dev
kubectl get svc -n flowise-dev
kubectl get ing -n flowise-dev
```

### Verify Application

```bash
# Health check
curl https://flowise-dev.do2506.click/api/v1/health

# Check logs
kubectl logs -n flowise-dev deployment/flowise-server --tail=50
kubectl logs -n flowise-dev deployment/flowise-ui --tail=50
```

## 6. Troubleshooting

### ArgoCD CLI cannot login

```bash
# Check server is accessible
curl -k https://argocd.do2506.click

# Login with insecure flag (for self-signed cert or HTTP)
argocd login argocd.do2506.click --insecure --username admin

# Or use token directly
argocd login argocd.do2506.click \
  --auth-token $ARGOCD_AUTH_TOKEN \
  --grpc-web \
  --insecure
```

### GitHub Actions cannot sync app

**Error:** `permission denied`

**Fix:** Check RBAC permissions

```bash
# Check account
argocd account list

# Check token
argocd account get admin

# Regenerate token if needed
argocd account generate-token --account admin --id github-actions-new
```

### Application out of sync

```bash
# Force refresh
argocd app get flowise-dev --refresh --hard-refresh

# Manual sync
argocd app sync flowise-dev --force --prune

# Check diff
argocd app diff flowise-dev
```

### Images not updating

**Check Kustomization:**

```bash
# In gitops repo
cd overlays/dev
cat kustomization.yaml

# Verify images section exists and has correct format
```

**GitHub Actions should update:**

```bash
kustomize edit set image flowise-server=ECR_URL:TAG
kustomize edit set image flowise-ui=ECR_URL:TAG
```

### Health check fails

```bash
# Check pods
kubectl get pods -n flowise-dev

# Check service
kubectl get svc -n flowise-dev

# Check ingress
kubectl get ing -n flowise-dev

# Check ALB
kubectl describe ing -n flowise-dev flowise-ingress

# Test internal
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://flowise-server.flowise-dev.svc.cluster.local:3000/api/v1/health
```

## 7. Workflow Sequence

```
┌─────────────────────────────────────────────────────┐
│  1. Developer pushes code to main branch            │
│     OR manually triggers workflow                   │
└────────────────────┬────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────┐
│  2. GitHub Actions:                                 │
│     - Build Docker images                           │
│     - Push to ECR with tag (SHA-based)             │
│     - Tag: abc1234, latest, full-sha               │
└────────────────────┬────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────┐
│  3. GitHub Actions:                                 │
│     - Checkout flowise-gitops repo                  │
│     - Update overlays/{env}/kustomization.yaml      │
│     - Set new image tags via kustomize              │
│     - Commit & push to gitops repo                  │
└────────────────────┬────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────┐
│  4. GitHub Actions:                                 │
│     - Login to ArgoCD via CLI                       │
│     - Trigger app refresh: argocd app refresh       │
│     - Trigger sync: argocd app sync --force         │
│     - Wait for healthy: argocd app wait --health    │
└────────────────────┬────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────┐
│  5. ArgoCD:                                         │
│     - Detects change in gitops repo                 │
│     - Pulls new kustomization.yaml                  │
│     - Renders manifests with new image tags         │
│     - Applies to Kubernetes cluster                 │
│     - Kubernetes pulls new images from ECR          │
│     - Rolling update deployments                    │
└────────────────────┬────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────┐
│  6. Health Check:                                   │
│     - Wait 60s for pods to stabilize               │
│     - Curl /api/v1/health endpoint                 │
│     - Retry up to 10 times                         │
│     - Report success or failure                     │
└─────────────────────────────────────────────────────┘
```

## 8. Best Practices

### Image Tagging

- ✅ Use SHA-based tags (immutable)
- ✅ Tag with `latest` for convenience
- ✅ Include full SHA for traceability
- ❌ Don't use only `latest` (can't rollback)

### Sync Policy

**Dev/Staging:** Automated sync with selfHeal
```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
```

**Production:** Manual approval
```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: false  # Require manual sync
```

### Secrets Management

- ✅ Use GitHub Secrets for sensitive data
- ✅ Rotate tokens regularly (every 6 months)
- ✅ Use AWS OIDC instead of access keys (production)
- ❌ Never commit secrets to Git

## Summary

1. ✅ ArgoCD configured with `server.insecure: true` for CLI
2. ✅ Repository added to ArgoCD
3. ✅ API token generated for GitHub Actions
4. ✅ GitHub Secrets configured
5. ✅ ArgoCD Applications created (dev/staging/prod)
6. ✅ GitOps repo structure ready
7. 🔄 Workflow tested and verified

**Ready to deploy!** 🚀
