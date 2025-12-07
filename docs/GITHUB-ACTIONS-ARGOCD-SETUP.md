# 🚀 HƯỚNG DẪN SETUP GITHUB ACTIONS + ARGOCD WORKFLOW

## 📋 Mục Lục
1. [Tổng Quan Workflow](#tổng-quan-workflow)
2. [Kiến Trúc CI/CD](#kiến-trúc-cicd)
3. [Prerequisites](#prerequisites)
4. [Setup AWS Resources](#setup-aws-resources)
5. [Setup GitHub Secrets](#setup-github-secrets)
6. [Setup GitOps Repository](#setup-gitops-repository)
7. [Setup ArgoCD](#setup-argocd)
8. [Deploy Workflow File](#deploy-workflow-file)
9. [Testing & Verification](#testing--verification)
10. [Troubleshooting](#troubleshooting)

---

## 🎯 Tổng Quan Workflow

### **Workflow Này Làm Gì?**

```
Code Push → Build Docker Images → Push to ECR → Update GitOps → ArgoCD Sync → Deploy to K8s
```

**5 Jobs chính:**
1. **set-env**: Xác định environment, tag version, overlay path
2. **build-server**: Build & push Flowise Server image
3. **build-ui**: Build & push Flowise UI image
4. **update-gitops-and-deploy**: Update Kustomize → Trigger ArgoCD sync
5. **health-check**: Kiểm tra health endpoint sau deployment

### **Workflow Triggers:**
- **Manual**: `workflow_dispatch` với options (environment, tag, node version)
- **Auto**: Push to `main` branch (auto deploy to production)

---

## 🏗️ Kiến Trúc CI/CD

```
┌─────────────────────────────────────────────────────────────────┐
│                        GITHUB ACTIONS                            │
│  ┌──────────┐   ┌──────────┐   ┌──────────────────────────┐   │
│  │ Build    │   │ Build    │   │ Update GitOps Repo       │   │
│  │ Server   │   │ UI       │   │ + Trigger ArgoCD Sync    │   │
│  │ Image    │   │ Image    │   │                          │   │
│  └────┬─────┘   └────┬─────┘   └────────┬─────────────────┘   │
│       │              │                   │                      │
└───────┼──────────────┼───────────────────┼──────────────────────┘
        │              │                   │
        ▼              ▼                   ▼
   ┌────────────────────────┐     ┌───────────────────┐
   │     AWS ECR            │     │   GitOps Repo     │
   │  ┌──────┐  ┌──────┐   │     │  (Kustomize)      │
   │  │Server│  │  UI  │   │     │   overlays/       │
   │  │Image │  │Image │   │     │   ├── dev/        │
   │  └──────┘  └──────┘   │     │   ├── staging/    │
   └────────────────────────┘     │   └── prod/       │
                                  └─────────┬─────────┘
                                            │
                                            ▼
                                  ┌───────────────────┐
                                  │     ARGOCD        │
                                  │  (Auto Sync)      │
                                  └─────────┬─────────┘
                                            │
                                            ▼
                                  ┌───────────────────┐
                                  │   EKS CLUSTER     │
                                  │  ┌────────────┐   │
                                  │  │  Flowise   │   │
                                  │  │   Pods     │   │
                                  │  └────────────┘   │
                                  └───────────────────┘
```

---

## ✅ Prerequisites

### **1. AWS Account**
- AWS Account với quyền tạo ECR, EKS, IAM
- AWS CLI đã được cài đặt và cấu hình

### **2. GitHub Repository**
- **App Repo**: Repository chứa source code Flowise
- **GitOps Repo**: Repository riêng để lưu Kubernetes manifests

### **3. EKS Cluster**
- EKS Cluster đã được tạo (bằng Terraform trong repo này)
- AWS Load Balancer Controller đã được cài
- kubectl có thể access cluster

### **4. Tools**
```bash
# Install required tools
choco install awscli
choco install kubernetes-helm
choco install kubectl
choco install argocd-cli
choco install kustomize

# Verify installation
aws --version
helm version
kubectl version
argocd version
kustomize version
```

---

## 🔧 Setup AWS Resources

### **Bước 1: Tạo ECR Repositories**

```bash
# Set variables
AWS_REGION="ap-southeast-1"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create ECR repositories
aws ecr create-repository \
  --repository-name flowise-server \
  --region ${AWS_REGION} \
  --image-scanning-configuration scanOnPush=true \
  --encryption-configuration encryptionType=AES256

aws ecr create-repository \
  --repository-name flowise-ui \
  --region ${AWS_REGION} \
  --image-scanning-configuration scanOnPush=true \
  --encryption-configuration encryptionType=AES256

# Set lifecycle policy (keep only last 10 images)
cat > lifecycle-policy.json <<EOF
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Keep only 10 images",
      "selection": {
        "tagStatus": "any",
        "countType": "imageCountMoreThan",
        "countNumber": 10
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
EOF

aws ecr put-lifecycle-policy \
  --repository-name flowise-server \
  --lifecycle-policy-text file://lifecycle-policy.json \
  --region ${AWS_REGION}

aws ecr put-lifecycle-policy \
  --repository-name flowise-ui \
  --lifecycle-policy-text file://lifecycle-policy.json \
  --region ${AWS_REGION}

echo "✅ ECR repositories created:"
echo "  ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/flowise-server"
echo "  ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/flowise-ui"
```

### **Bước 2: Tạo IAM Role cho GitHub Actions**

**Option A: Sử dụng Access Keys (Đơn giản nhưng kém bảo mật)**

```bash
# Create IAM user
aws iam create-user --user-name github-actions-flowise

# Attach policies
aws iam attach-user-policy \
  --user-name github-actions-flowise \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser

# Create access key
aws iam create-access-key --user-name github-actions-flowise

# Save output:
# AWS_ACCESS_KEY_ID: AKIAxxxxxxxxxxxxxxxx
# AWS_SECRET_ACCESS_KEY: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

**Option B: Sử dụng OIDC (Khuyến nghị - Bảo mật cao)**

```bash
# Create OIDC provider for GitHub
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1

# Create trust policy
cat > github-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:TomJennyDev/flowise:*"
        }
      }
    }
  ]
}
EOF

# Create IAM role
aws iam create-role \
  --role-name github-actions-flowise-role \
  --assume-role-policy-document file://github-trust-policy.json

# Create permission policy
cat > github-permissions-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "*"
    }
  ]
}
EOF

# Attach policy to role
aws iam put-role-policy \
  --role-name github-actions-flowise-role \
  --policy-name ECRPushPull \
  --policy-document file://github-permissions-policy.json

# Get role ARN
aws iam get-role --role-name github-actions-flowise-role --query 'Role.Arn'
# Output: arn:aws:iam::123456789012:role/github-actions-flowise-role
```

---

## 🔐 Setup GitHub Secrets

### **Bước 3: Cấu hình GitHub Secrets**

**Vào GitHub Repository → Settings → Secrets and variables → Actions → New repository secret**

#### **AWS Credentials**

**Nếu dùng Access Keys:**
```
AWS_ACCESS_KEY_ID = AKIAxxxxxxxxxxxxxxxx
AWS_SECRET_ACCESS_KEY = xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

**Nếu dùng OIDC (Recommended):**
```
AWS_ROLE_TO_ASSUME = arn:aws:iam::123456789012:role/github-actions-flowise-role
```

#### **GitOps Repository Token**
```bash
# Tạo GitHub Personal Access Token
# Settings → Developer settings → Personal access tokens → Generate new token
# Permissions: repo (full control)

GITOPS_TOKEN = ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

#### **ArgoCD Credentials**
```bash
# Get ArgoCD server URL
kubectl get ingress argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Generate auth token
argocd login argocd.yourdomain.com --username admin --password <password>
argocd account generate-token --account admin

ARGOCD_SERVER = argocd.yourdomain.com
ARGOCD_AUTH_TOKEN = eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

#### **Health Check Endpoints**
```
DEV_ENDPOINT = https://flowise-dev.yourdomain.com
STAGING_ENDPOINT = https://flowise-staging.yourdomain.com
PROD_ENDPOINT = https://flowise.yourdomain.com
```

### **Tổng Hợp Secrets:**
```
✅ AWS_ACCESS_KEY_ID (nếu dùng access key)
✅ AWS_SECRET_ACCESS_KEY (nếu dùng access key)
✅ AWS_ROLE_TO_ASSUME (nếu dùng OIDC - recommended)
✅ GITOPS_TOKEN
✅ ARGOCD_SERVER
✅ ARGOCD_AUTH_TOKEN
✅ DEV_ENDPOINT
✅ STAGING_ENDPOINT
✅ PROD_ENDPOINT
```

---

## 📦 Setup GitOps Repository

### **Bước 4: Tạo GitOps Repository Structure**

```bash
# Clone or create new repo
git clone https://github.com/TomJennyDev/flowise-gitops.git
cd flowise-gitops

# Create directory structure
mkdir -p base overlays/{dev,staging,production}
```

### **Bước 5: Tạo Base Manifests**

**`base/deployment-server.yaml`:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: flowise-server
  labels:
    app: flowise
    component: server
spec:
  replicas: 2
  selector:
    matchLabels:
      app: flowise
      component: server
  template:
    metadata:
      labels:
        app: flowise
        component: server
    spec:
      containers:
        - name: server
          image: flowise-server:latest  # Will be overridden by Kustomize
          ports:
            - containerPort: 3000
              name: http
          env:
            - name: PORT
              value: "3000"
            - name: DATABASE_TYPE
              value: "postgres"
            - name: DATABASE_HOST
              valueFrom:
                secretKeyRef:
                  name: flowise-secrets
                  key: database-host
            - name: DATABASE_PORT
              value: "5432"
            - name: DATABASE_USER
              valueFrom:
                secretKeyRef:
                  name: flowise-secrets
                  key: database-user
            - name: DATABASE_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: flowise-secrets
                  key: database-password
            - name: DATABASE_NAME
              valueFrom:
                secretKeyRef:
                  name: flowise-secrets
                  key: database-name
          resources:
            requests:
              cpu: 250m
              memory: 512Mi
            limits:
              cpu: 1000m
              memory: 1Gi
          livenessProbe:
            httpGet:
              path: /api/v1/health
              port: 3000
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /api/v1/health
              port: 3000
            initialDelaySeconds: 10
            periodSeconds: 5
```

**`base/deployment-ui.yaml`:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: flowise-ui
  labels:
    app: flowise
    component: ui
spec:
  replicas: 2
  selector:
    matchLabels:
      app: flowise
      component: ui
  template:
    metadata:
      labels:
        app: flowise
        component: ui
    spec:
      containers:
        - name: ui
          image: flowise-ui:latest  # Will be overridden by Kustomize
          ports:
            - containerPort: 8080
              name: http
          env:
            - name: VITE_API_URL
              value: "http://flowise-server:3000"
          resources:
            requests:
              cpu: 100m
              memory: 256Mi
            limits:
              cpu: 500m
              memory: 512Mi
          livenessProbe:
            httpGet:
              path: /
              port: 8080
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 5
```

**`base/service.yaml`:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: flowise-server
  labels:
    app: flowise
    component: server
spec:
  type: ClusterIP
  ports:
    - port: 3000
      targetPort: 3000
      protocol: TCP
      name: http
  selector:
    app: flowise
    component: server
---
apiVersion: v1
kind: Service
metadata:
  name: flowise-ui
  labels:
    app: flowise
    component: ui
spec:
  type: ClusterIP
  ports:
    - port: 8080
      targetPort: 8080
      protocol: TCP
      name: http
  selector:
    app: flowise
    component: ui
```

**`base/ingress.yaml`:**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: flowise-ingress
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/ssl-redirect: '443'
    alb.ingress.kubernetes.io/healthcheck-path: /api/v1/health
spec:
  ingressClassName: alb
  rules:
    - host: flowise.example.com  # Will be overridden
      http:
        paths:
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: flowise-server
                port:
                  number: 3000
          - path: /
            pathType: Prefix
            backend:
              service:
                name: flowise-ui
                port:
                  number: 8080
```

**`base/kustomization.yaml`:**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment-server.yaml
  - deployment-ui.yaml
  - service.yaml
  - ingress.yaml

commonLabels:
  app: flowise
```

### **Bước 6: Tạo Overlays cho từng Environment**

**`overlays/dev/kustomization.yaml`:**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: flowise-dev

bases:
  - ../../base

images:
  - name: flowise-server
    newName: 123456789012.dkr.ecr.ap-southeast-1.amazonaws.com/flowise-server
    newTag: latest
  - name: flowise-ui
    newName: 123456789012.dkr.ecr.ap-southeast-1.amazonaws.com/flowise-ui
    newTag: latest

replicas:
  - name: flowise-server
    count: 1
  - name: flowise-ui
    count: 1

patchesStrategicMerge:
  - ingress-patch.yaml

commonLabels:
  environment: dev
```

**`overlays/dev/ingress-patch.yaml`:**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: flowise-ingress
  annotations:
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:ap-southeast-1:123456789012:certificate/dev-cert-id
spec:
  rules:
    - host: flowise-dev.yourdomain.com
```

**`overlays/staging/kustomization.yaml`:**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: flowise-staging

bases:
  - ../../base

images:
  - name: flowise-server
    newName: 123456789012.dkr.ecr.ap-southeast-1.amazonaws.com/flowise-server
    newTag: latest
  - name: flowise-ui
    newName: 123456789012.dkr.ecr.ap-southeast-1.amazonaws.com/flowise-ui
    newTag: latest

replicas:
  - name: flowise-server
    count: 2
  - name: flowise-ui
    count: 2

patchesStrategicMerge:
  - ingress-patch.yaml

commonLabels:
  environment: staging
```

**`overlays/staging/ingress-patch.yaml`:**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: flowise-ingress
  annotations:
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:ap-southeast-1:123456789012:certificate/staging-cert-id
spec:
  rules:
    - host: flowise-staging.yourdomain.com
```

**`overlays/production/kustomization.yaml`:**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: flowise-prod

bases:
  - ../../base

images:
  - name: flowise-server
    newName: 123456789012.dkr.ecr.ap-southeast-1.amazonaws.com/flowise-server
    newTag: latest
  - name: flowise-ui
    newName: 123456789012.dkr.ecr.ap-southeast-1.amazonaws.com/flowise-ui
    newTag: latest

replicas:
  - name: flowise-server
    count: 3
  - name: flowise-ui
    count: 3

patchesStrategicMerge:
  - ingress-patch.yaml
  - resources-patch.yaml

commonLabels:
  environment: production
```

**`overlays/production/ingress-patch.yaml`:**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: flowise-ingress
  annotations:
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:ap-southeast-1:123456789012:certificate/prod-cert-id
spec:
  rules:
    - host: flowise.yourdomain.com
```

**`overlays/production/resources-patch.yaml`:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: flowise-server
spec:
  template:
    spec:
      containers:
        - name: server
          resources:
            requests:
              cpu: 500m
              memory: 1Gi
            limits:
              cpu: 2000m
              memory: 2Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: flowise-ui
spec:
  template:
    spec:
      containers:
        - name: ui
          resources:
            requests:
              cpu: 200m
              memory: 512Mi
            limits:
              cpu: 1000m
              memory: 1Gi
```

### **Bước 7: Commit và Push**

```bash
git add .
git commit -m "Initial GitOps structure"
git push origin main
```

---

## 🎯 Setup ArgoCD

### **Bước 8: Tạo ArgoCD Applications**

**`argocd/flowise-dev-app.yaml`:**
```yaml
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
      - PruneLast=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
  
  revisionHistoryLimit: 10
```

**`argocd/flowise-staging-app.yaml`:**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: flowise-staging
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
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
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
      - PruneLast=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
  
  revisionHistoryLimit: 10
```

**`argocd/flowise-production-app.yaml`:**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: flowise-production
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  
  source:
    repoURL: https://github.com/TomJennyDev/flowise-gitops.git
    targetRevision: main
    path: overlays/production
  
  destination:
    server: https://kubernetes.default.svc
    namespace: flowise-prod
  
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
      - PruneLast=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
  
  revisionHistoryLimit: 10
```

### **Bước 9: Deploy ArgoCD Applications**

```bash
# Update kubeconfig
aws eks update-kubeconfig --region ap-southeast-1 --name dev-eks-cluster

# Apply applications
kubectl apply -f argocd/flowise-dev-app.yaml
kubectl apply -f argocd/flowise-staging-app.yaml
kubectl apply -f argocd/flowise-production-app.yaml

# Verify
kubectl get applications -n argocd

# Check sync status
argocd app list
argocd app get flowise-dev
```

---

## 📝 Deploy Workflow File

### **Bước 10: Tạo Workflow File trong App Repository**

Tạo file `.github/workflows/deploy-to-k8s.yml` với nội dung workflow bạn đã cung cấp.

**Cập nhật các thông tin:**

```yaml
env:
    AWS_REGION: ap-southeast-1  # ⚠️ Thay đổi region của bạn
    GITOPS_REPO: TomJennyDev/flowise-gitops  # ⚠️ Thay đổi GitOps repo
```

### **Bước 11: Commit và Push**

```bash
git add .github/workflows/deploy-to-k8s.yml
git commit -m "Add CI/CD workflow with ArgoCD"
git push origin main
```

---

## 🧪 Testing & Verification

### **Bước 12: Test Manual Trigger**

```bash
# Go to GitHub Actions tab
# → Select "Deploy to Kubernetes via ArgoCD"
# → Click "Run workflow"
# → Select environment: dev
# → Click "Run workflow"
```

### **Bước 13: Monitor Deployment**

**GitHub Actions:**
```
Actions → Deploy to Kubernetes via ArgoCD → Latest run
```

**ArgoCD UI:**
```
https://argocd.yourdomain.com
→ Applications → flowise-dev
→ Check sync status and resource health
```

**kubectl:**
```bash
# Check pods
kubectl get pods -n flowise-dev

# Check deployments
kubectl get deployments -n flowise-dev

# Check ingress
kubectl get ingress -n flowise-dev

# Get ALB DNS
kubectl get ingress flowise-ingress -n flowise-dev -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Check logs
kubectl logs -n flowise-dev -l app=flowise,component=server --tail=100
kubectl logs -n flowise-dev -l app=flowise,component=ui --tail=100
```

### **Bước 14: Test Application**

```bash
# Get endpoint
ENDPOINT=$(kubectl get ingress flowise-ingress -n flowise-dev -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Health check
curl https://${ENDPOINT}/api/v1/health

# Access UI
open https://flowise-dev.yourdomain.com
```

---

## 🐛 Troubleshooting

### **Problem 1: ECR Authentication Failed**

```bash
# Check IAM permissions
aws iam get-user-policy --user-name github-actions-flowise --policy-name ECRPushPull

# Test ECR login locally
aws ecr get-login-password --region ap-southeast-1 | \
  docker login --username AWS --password-stdin \
  123456789012.dkr.ecr.ap-southeast-1.amazonaws.com

# Recreate access key nếu cần
aws iam create-access-key --user-name github-actions-flowise
```

### **Problem 2: ArgoCD Sync Failed**

```bash
# Check ArgoCD application
argocd app get flowise-dev

# View sync errors
kubectl describe application flowise-dev -n argocd

# Manual sync with force
argocd app sync flowise-dev --force --prune

# Check ArgoCD logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

### **Problem 3: Image Pull Error**

```bash
# Check if image exists in ECR
aws ecr describe-images \
  --repository-name flowise-server \
  --region ap-southeast-1

# Verify image tag in kustomization.yaml
cat overlays/dev/kustomization.yaml

# Check pod events
kubectl describe pod -n flowise-dev <pod-name>

# Recreate pods
kubectl rollout restart deployment flowise-server -n flowise-dev
```

### **Problem 4: Ingress/ALB Not Created**

```bash
# Check AWS Load Balancer Controller
kubectl get deployment -n kube-system aws-load-balancer-controller
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Check Ingress events
kubectl describe ingress flowise-ingress -n flowise-dev

# Verify certificate ARN
aws acm list-certificates --region ap-southeast-1

# Check security groups
aws ec2 describe-security-groups \
  --filters "Name=tag:elbv2.k8s.aws/cluster,Values=dev-eks-cluster"
```

### **Problem 5: Health Check Failed**

```bash
# Check pod status
kubectl get pods -n flowise-dev

# Check service endpoints
kubectl get endpoints -n flowise-dev

# Port forward to test directly
kubectl port-forward -n flowise-dev svc/flowise-server 3000:3000
curl http://localhost:3000/api/v1/health

# Check application logs
kubectl logs -n flowise-dev -l component=server --tail=200
```

### **Problem 6: GitOps Update Not Triggered**

```bash
# Check GitHub Actions logs
# Actions → Latest run → update-gitops-and-deploy job

# Verify GITOPS_TOKEN
# Settings → Secrets → GITOPS_TOKEN

# Check GitOps repo for commits
cd flowise-gitops
git log --oneline -n 5

# Manual trigger ArgoCD refresh
argocd app get flowise-dev --refresh
argocd app sync flowise-dev
```

---

## 📊 Monitoring & Observability

### **Setup Prometheus Monitoring**

```bash
# ArgoCD metrics already exposed if you followed setup
kubectl get servicemonitor -n argocd

# Query ArgoCD metrics
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Visit: http://localhost:9090
# Query: argocd_app_sync_total
```

### **Setup Slack Notifications** (Optional)

```yaml
# In ArgoCD values
notifications:
  enabled: true
  notifiers:
    service.slack: |
      token: xoxb-your-slack-token
  subscriptions:
    - recipients:
      - slack:deployments-channel
      triggers:
      - on-deployed
      - on-health-degraded
```

---

## ✅ Checklist Setup Hoàn Chỉnh

- [ ] AWS ECR repositories đã được tạo
- [ ] IAM Role/User cho GitHub Actions đã được tạo
- [ ] GitHub Secrets đã được cấu hình đầy đủ
- [ ] GitOps repository đã được setup với structure đúng
- [ ] ArgoCD Applications đã được deploy
- [ ] Workflow file đã được commit vào app repo
- [ ] Test manual trigger thành công
- [ ] Images được build và push lên ECR
- [ ] Kustomize được update tự động
- [ ] ArgoCD sync thành công
- [ ] Pods running healthy
- [ ] Ingress/ALB được tạo thành công
- [ ] Health check endpoint response OK
- [ ] Application accessible qua domain

---

## 🎓 Best Practices

1. **Secrets Management**: Sử dụng AWS Secrets Manager hoặc External Secrets Operator
2. **Image Scanning**: Enable ECR image scanning
3. **RBAC**: Tạo service account riêng cho ArgoCD với least privilege
4. **Monitoring**: Setup Prometheus + Grafana để monitor deployments
5. **Rollback**: Test rollback strategy với ArgoCD
6. **Branch Protection**: Enable branch protection cho GitOps repo
7. **Code Review**: Require PR review cho production deployments
8. **Backup**: Setup Velero để backup Kubernetes resources

---

## 📚 Tài Liệu Tham Khảo

- **ArgoCD**: https://argo-cd.readthedocs.io/
- **Kustomize**: https://kustomize.io/
- **GitHub Actions**: https://docs.github.com/en/actions
- **AWS ECR**: https://docs.aws.amazon.com/ecr/
- **EKS Best Practices**: https://aws.github.io/aws-eks-best-practices/

---

**🎉 Setup Complete!** Workflow đã sẵn sàng để CI/CD tự động!
