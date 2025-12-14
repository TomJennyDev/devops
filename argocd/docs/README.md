# 🔄 ArgoCD Configuration for GitHub Workflow

## 📋 Tổng Quan

ArgoCD đã được cấu hình để làm việc với GitHub Actions workflow cho CI/CD tự động.

## 🎯 Kiến Trúc

```
GitHub Actions (Build & Push)
    ↓
ECR (Docker Images)
    ↓
GitHub Actions (Update GitOps Repo)
    ↓
GitOps Repository (Kustomize updated)
    ↓
ArgoCD (Auto Sync or Manual Trigger)
    ↓
EKS Cluster (Deployment)
```

## ✅ Yêu Cầu Đã Setup

### 1. **ArgoCD Installation**
- [x] ArgoCD được cài đặt bằng Helm
- [x] Ingress với ALB đã được cấu hình
- [x] HTTPS với ACM certificate
- [x] gRPC-web enabled cho GitHub Actions

### 2. **Repository Configuration**
- [x] GitOps repository đã được add
- [x] RBAC policies cho CI/CD access
- [x] API token đã được generate

### 3. **Applications**
- [x] flowise-dev
- [x] flowise-staging  
- [x] flowise-production

## 🚀 Quick Start

### **1. Deploy ArgoCD**

```bash
# Install ArgoCD
helm install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --version 7.7.11 \
  -f helm-values/argocd-values.yaml

# Wait for ready
kubectl wait --for=condition=available --timeout=600s \
  deployment/argocd-server -n argocd
```

### **2. Access ArgoCD**

```bash
# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Port forward (for initial setup)
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Login
argocd login localhost:8080 --username admin --insecure
```

### **3. Generate API Token**

```bash
# Generate token for GitHub Actions
argocd account generate-token --account admin --id github-actions

# Save output to GitHub Secret: ARGOCD_AUTH_TOKEN
```

### **4. Add GitOps Repository**

```bash
# Add repository
argocd repo add https://github.com/TomJennyDev/flowise-gitops.git

# For private repo:
argocd repo add https://github.com/TomJennyDev/flowise-gitops.git \
  --username <github-username> \
  --password <github-token>

# Verify
argocd repo list
```

### **5. Deploy Applications**

```bash
# Deploy all applications
kubectl apply -f applications/flowise-apps.yaml

# Verify
argocd app list
kubectl get applications -n argocd
```

### **6. Test Sync**

```bash
# Test sync for dev environment
argocd app get flowise-dev --refresh
argocd app sync flowise-dev --prune --force
argocd app wait flowise-dev --health --timeout 600

# Check status
argocd app get flowise-dev
```

## 🔐 GitHub Secrets Required

Add these secrets to your GitHub repository:

```
ARGOCD_SERVER=argocd.yourdomain.com
ARGOCD_AUTH_TOKEN=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
GITOPS_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
AWS_ACCESS_KEY_ID=AKIAxxxxxxxxxxxxxxxx
AWS_SECRET_ACCESS_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
DEV_ENDPOINT=https://flowise-dev.yourdomain.com
STAGING_ENDPOINT=https://flowise-staging.yourdomain.com
PROD_ENDPOINT=https://flowise.yourdomain.com
```

## 🧪 Testing

### **Test ArgoCD Configuration**

```bash
# Run test script
cd scripts
bash test-argocd-github-integration.sh
```

### **Simulate GitHub Workflow**

```bash
#!/bin/bash
# Simulate what GitHub Actions does

# 1. Login to ArgoCD
argocd login argocd.yourdomain.com \
    --auth-token ${ARGOCD_AUTH_TOKEN} \
    --grpc-web \
    --insecure

# 2. Refresh application (detect changes)
argocd app get flowise-dev --refresh

# 3. Trigger sync
argocd app sync flowise-dev --prune --force

# 4. Wait for completion
argocd app wait flowise-dev --health --timeout 600

# 5. Get status
argocd app get flowise-dev
argocd app resources flowise-dev
```

## 📊 Monitoring

### **Check Application Status**

```bash
# List all applications
argocd app list

# Get specific app
argocd app get flowise-dev

# Check resources
argocd app resources flowise-dev

# View logs
argocd app logs flowise-dev --follow
```

### **Check Sync History**

```bash
# View sync history
argocd app history flowise-dev

# Rollback to previous version
argocd app rollback flowise-dev <revision-id>
```

## 🔧 Troubleshooting

### **Problem: Cannot connect from GitHub Actions**

```bash
# Check if gRPC-web is enabled
kubectl get configmap argocd-cmd-params-cm -n argocd -o yaml

# Should have:
# data:
#   server.enable.gzip: "true"
```

### **Problem: Sync failed**

```bash
# Check application status
argocd app get flowise-dev

# View detailed errors
kubectl describe application flowise-dev -n argocd

# Check ArgoCD logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

### **Problem: Repository connection failed**

```bash
# Test repository connection
argocd repo get https://github.com/TomJennyDev/flowise-gitops.git

# Re-add repository
argocd repo rm https://github.com/TomJennyDev/flowise-gitops.git
argocd repo add https://github.com/TomJennyDev/flowise-gitops.git

# Check repo server logs
kubectl logs -n argocd deployment/argocd-repo-server
```

## 📚 Files Structure

```
argocd/
├── helm-values/
│   └── argocd-values.yaml          # ArgoCD Helm values (configured for GitHub workflow)
├── applications/
│   └── flowise-apps.yaml           # ArgoCD Applications definitions
├── scripts/
│   └── test-argocd-github-integration.sh  # Test script
└── README.md                       # This file
```

## 🎯 GitHub Workflow Integration Points

### **1. Workflow Updates Kustomize**
```yaml
# In GitHub Actions
kustomize edit set image flowise-server=${SERVER_IMAGE}
kustomize edit set image flowise-ui=${UI_IMAGE}
git commit && git push
```

### **2. ArgoCD Detects Change**
- Auto-sync enabled → immediate sync
- Manual sync → GitHub Actions triggers via CLI

### **3. GitHub Actions Triggers Sync**
```yaml
- name: Trigger ArgoCD sync
  run: |
    argocd login ${ARGOCD_SERVER} --auth-token ${ARGOCD_AUTH_TOKEN} --grpc-web
    argocd app sync flowise-${ENV} --prune --force
    argocd app wait flowise-${ENV} --health --timeout 600
```

## 🔄 Update Process

### **Update ArgoCD Configuration**

```bash
# Edit values
nano helm-values/argocd-values.yaml

# Upgrade
helm upgrade argocd argo/argo-cd \
  --namespace argocd \
  --version 7.7.11 \
  -f helm-values/argocd-values.yaml
```

### **Update Applications**

```bash
# Edit applications
nano applications/flowise-apps.yaml

# Apply changes
kubectl apply -f applications/flowise-apps.yaml
```

## 📖 Documentation

- [ArgoCD Installation Guide](../ARGOCD-INSTALLATION.md)
- [GitHub Actions Setup Guide](../../docs/GITHUB-ACTIONS-ARGOCD-SETUP.md)
- [ArgoCD Official Docs](https://argo-cd.readthedocs.io/)

## ✅ Checklist

- [ ] ArgoCD installed and accessible
- [ ] API token generated
- [ ] GitOps repository added
- [ ] Applications created (dev, staging, production)
- [ ] GitHub Secrets configured
- [ ] Test sync successful
- [ ] GitHub workflow tested

---

**Last Updated:** 2025-12-05  
**Maintained By:** DevOps Team
