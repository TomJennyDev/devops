# 🚀 HƯỚNG DẪN CÀI ĐẶT ARGOCD BẰNG HELM

## 📋 Mục Lục

1. [Yêu Cầu](#yêu-cầu)
2. [Cài Đặt ArgoCD](#cài-đặt-argocd)
3. [Cấu Hình Ingress với ALB](#cấu-hình-ingress-với-alb)
4. [Truy Cập ArgoCD](#truy-cập-argocd)
5. [Cấu Hình Repository](#cấu-hình-repository)
6. [Deploy Applications](#deploy-applications)
7. [Troubleshooting](#troubleshooting)

---

## ✅ Yêu Cầu

### 1. **EKS Cluster đã được deploy**

```bash
cd terraform-eks/environments/dev
terraform apply
```

### 2. **kubectl đã được cấu hình**

```bash
aws eks update-kubeconfig --region us-west-2 --name dev-eks-cluster

# Verify connection
kubectl get nodes
```

### 3. **Helm đã được cài đặt**

```bash
# Windows (PowerShell)
choco install kubernetes-helm

# Hoặc download từ: https://github.com/helm/helm/releases
# Verify
helm version
```

### 4. **AWS Load Balancer Controller đã được deploy**

```bash
# Kiểm tra
kubectl get deployment -n kube-system aws-load-balancer-controller
```

### 5. **ACM Certificate đã được tạo** (cho HTTPS)

```bash
# Tạo bằng Terraform hoặc AWS Console
# Lưu lại ARN: arn:aws:acm:us-west-2:123456789:certificate/xxx
```

---

## 🎯 Cài Đặt ArgoCD

### **Bước 1: Thêm Helm Repository**

```bash
# Add ArgoCD Helm repo
helm repo add argo https://argoproj.github.io/argo-helm

# Update repos
helm repo update

# Verify
helm search repo argo-cd
```

### **Bước 2: Tạo Namespace**

```bash
kubectl create namespace argocd
```

### **Bước 3: Tạo Values File**

Tạo file `argocd/helm-values/argocd-values.yaml`:

```yaml
# ============================================
# ARGOCD HELM VALUES
# ============================================

global:
  domain: argocd.example.com  # ⚠️ THAY ĐỔI domain của bạn

# ============================================
# ARGOCD SERVER CONFIGURATION
# ============================================
server:
  replicas: 2

  # Expose ArgoCD qua LoadBalancer (NLB)
  service:
    type: LoadBalancer
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: "external"
      service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "ip"
      service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
      service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "ssl"

  # Hoặc expose qua ALB Ingress (Recommended)
  ingress:
    enabled: true
    ingressClassName: alb
    annotations:
      # ALB Configuration
      alb.ingress.kubernetes.io/scheme: internet-facing
      alb.ingress.kubernetes.io/target-type: ip
      alb.ingress.kubernetes.io/backend-protocol: HTTPS

      # SSL/TLS Configuration
      alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-west-2:ACCOUNT_ID:certificate/CERT_ID  # ⚠️ THAY ĐỔI
      alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
      alb.ingress.kubernetes.io/ssl-redirect: '443'

      # Health Check
      alb.ingress.kubernetes.io/healthcheck-path: /healthz
      alb.ingress.kubernetes.io/healthcheck-port: '8080'
      alb.ingress.kubernetes.io/healthcheck-protocol: HTTP

      # Tags
      alb.ingress.kubernetes.io/tags: Environment=dev,Application=argocd

    hosts:
      - argocd.example.com  # ⚠️ THAY ĐỔI

    tls:
      - secretName: argocd-tls
        hosts:
          - argocd.example.com

  # Resource limits
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 250m
      memory: 256Mi

  # Metrics
  metrics:
    enabled: true
    serviceMonitor:
      enabled: true

# ============================================
# ARGOCD REPO SERVER
# ============================================
repoServer:
  replicas: 2
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 250m
      memory: 256Mi

# ============================================
# ARGOCD APPLICATION CONTROLLER
# ============================================
controller:
  replicas: 1
  resources:
    limits:
      cpu: 1000m
      memory: 1Gi
    requests:
      cpu: 500m
      memory: 512Mi

  metrics:
    enabled: true
    serviceMonitor:
      enabled: true

# ============================================
# REDIS (Cache)
# ============================================
redis:
  enabled: true
  resources:
    limits:
      cpu: 200m
      memory: 256Mi
    requests:
      cpu: 100m
      memory: 128Mi

# ============================================
# ARGOCD CONFIGS
# ============================================
configs:
  # Repository credentials
  repositories:
    # DevOps repo (system apps)
    devops-repo:
      url: https://github.com/TomJennyDev/devops.git
      type: git
      name: devops

    # GitOps repo (application manifests) - QUAN TRỌNG cho GitHub Workflow
    gitops-repo:
      url: https://github.com/TomJennyDev/flowise-gitops.git
      type: git
      name: flowise-gitops
      # Nếu private repo, thêm credentials:
      # username: <github-username>
      # password: <github-token>

  # Admin password (bcrypt hash)
  # Generate: htpasswd -nbBC 10 "" YOUR_PASSWORD | tr -d ':\n' | sed 's/$2y/$2a/'
  secret:
    # Default: admin / admin123
    argocdServerAdminPassword: "$2a$10$rRyBsGSHK6.uc8fntPwVIuLVHgsAhAX7TcdrqW/XGN2opqjr9cTPq"

  # Server configuration
  params:
    server.insecure: false  # Enforce HTTPS

    # ⚠️ QUAN TRỌNG: Enable gRPC Web cho GitHub Actions
    # GitHub Actions workflow cần gRPC web để kết nối
    server.enable.gzip: true

    # Timeout settings (cho workflow chờ sync)
    timeout.reconciliation: 180s
    timeout.hard.reconciliation: 0

# ============================================
# NOTIFICATIONS (Optional)
# ============================================
notifications:
  enabled: false

# ============================================
# APPLICATION SET CONTROLLER
# ============================================
applicationSet:
  enabled: true
  replicas: 1

# ============================================
# RBAC Configuration
# ============================================
rbac:
  create: true

  # ⚠️ QUAN TRỌNG: Policy cho GitHub Actions API access
  policy.default: role:readonly
  policy.csv: |
    # Admin role (full access)
    p, role:admin, applications, *, */*, allow
    p, role:admin, clusters, *, *, allow
    p, role:admin, repositories, *, *, allow
    p, role:admin, projects, *, *, allow
    p, role:admin, accounts, *, *, allow
    p, role:admin, gpgkeys, *, *, allow
    p, role:admin, certificates, *, *, allow

    # CI/CD role (cho GitHub Actions)
    p, role:cicd, applications, get, */*, allow
    p, role:cicd, applications, sync, */*, allow
    p, role:cicd, applications, refresh, */*, allow
    p, role:cicd, applications, override, */*, allow
    p, role:cicd, repositories, get, *, allow

    # Bind admin role to admin user
    g, admin, role:admin

  scopes: '[accounts:apiKey]'

# ============================================
# SERVICE ACCOUNT
# ============================================
serviceAccount:
  create: true
  name: argocd-server
  annotations: {}
  automountServiceAccountToken: true
```

### **Bước 4: Install ArgoCD**

```bash
# Install với custom values
helm install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --version 7.7.11 \
  -f argocd/helm-values/argocd-values.yaml

# Hoặc dùng file values riêng cho từng environment
helm install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --version 7.7.11 \
  -f argocd/helm-values/argocd-dev-values.yaml
```

### **Bước 5: Verify Installation**

```bash
# Check pods
kubectl get pods -n argocd

# Check services
kubectl get svc -n argocd

# Check ingress
kubectl get ingress -n argocd

# Check ALB (nếu dùng Ingress)
kubectl get ingress argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

**Expected Output:**

```
NAME                                       READY   STATUS    RESTARTS   AGE
argocd-application-controller-0            1/1     Running   0          2m
argocd-applicationset-controller-xxx       1/1     Running   0          2m
argocd-dex-server-xxx                      1/1     Running   0          2m
argocd-notifications-controller-xxx        1/1     Running   0          2m
argocd-redis-xxx                           1/1     Running   0          2m
argocd-repo-server-xxx                     1/1     Running   0          2m
argocd-server-xxx                          1/1     Running   0          2m
```

---

## 🌐 Cấu Hình Ingress với ALB

### **Option 1: Tạo Ingress Riêng (Khuyến nghị)**

Tạo file `argocd/manifests/ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server
  namespace: argocd
  annotations:
    # ALB Configuration
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/backend-protocol: HTTPS

    # SSL/TLS
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-west-2:123456789:certificate/xxx  # ⚠️ THAY ĐỔI
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/ssl-redirect: '443'
    alb.ingress.kubernetes.io/ssl-policy: ELBSecurityPolicy-TLS13-1-2-2021-06

    # Health Check
    alb.ingress.kubernetes.io/healthcheck-path: /healthz
    alb.ingress.kubernetes.io/healthcheck-port: '8080'
    alb.ingress.kubernetes.io/healthcheck-protocol: HTTP
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: '30'
    alb.ingress.kubernetes.io/healthcheck-timeout-seconds: '5'
    alb.ingress.kubernetes.io/healthy-threshold-count: '2'
    alb.ingress.kubernetes.io/unhealthy-threshold-count: '2'

    # Additional Settings
    alb.ingress.kubernetes.io/load-balancer-attributes: idle_timeout.timeout_seconds=300
    alb.ingress.kubernetes.io/tags: Environment=dev,Application=argocd,ManagedBy=kubectl

    # CORS (nếu cần)
    alb.ingress.kubernetes.io/actions.ssl-redirect: |
      {
        "Type": "redirect",
        "RedirectConfig": {
          "Protocol": "HTTPS",
          "Port": "443",
          "StatusCode": "HTTP_301"
        }
      }

spec:
  ingressClassName: alb
  rules:
    - host: argocd.yourdomain.com  # ⚠️ THAY ĐỔI
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: argocd-server
                port:
                  number: 443

  tls:
    - hosts:
        - argocd.yourdomain.com
```

**Apply Ingress:**

```bash
kubectl apply -f argocd/manifests/ingress.yaml

# Get ALB DNS
kubectl get ingress argocd-server -n argocd
```

### **Option 2: Port Forward (Development)**

```bash
# Port forward ArgoCD server
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Access: https://localhost:8080
```

---

## 🔐 Truy Cập ArgoCD

### **1. Lấy Admin Password**

```bash
# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

# Hoặc dùng kubectl get secret
kubectl get secret argocd-initial-admin-secret -n argocd -o yaml
```

### **2. Login qua Web UI**

```bash
# Nếu dùng Port Forward
https://localhost:8080

# Nếu dùng ALB Ingress
https://argocd.yourdomain.com

# Credentials:
# Username: admin
# Password: <password từ secret>
```

### **3. Login qua CLI**

```bash
# Install ArgoCD CLI
# Windows (PowerShell)
choco install argocd-cli

# Hoặc download từ: https://github.com/argoproj/argo-cd/releases

# Login (Port Forward)
argocd login localhost:8080 --username admin --password <password> --insecure

# Login (ALB)
argocd login argocd.yourdomain.com --username admin --password <password>

# Change password
argocd account update-password
```

### **4. Đổi Admin Password**

```bash
# Via CLI
argocd account update-password

# Via Web UI
User Info → Update Password
```

### **5. Tạo API Token cho GitHub Actions** ⚠️ **QUAN TRỌNG**

```bash
# Login to ArgoCD first
argocd login argocd.yourdomain.com --username admin

# Generate API token (không hết hạn)
argocd account generate-token --account admin --id github-actions

# Output:
# eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJhcmdvY2QiLCJzdWIiOiJhZG1pbjphcGlLZXkiLCJuYmYiOjE3MDE...

# ⚠️ LƯU TOKEN NÀY vào GitHub Secret: ARGOCD_AUTH_TOKEN
```

**Tạo Token với thời hạn (optional):**

```bash
# Token hết hạn sau 30 ngày
argocd account generate-token --account admin --id github-actions --expires-in 720h

# Verify token
argocd account get-user-info
```

**Lưu vào GitHub Secrets:**

```
Repository → Settings → Secrets and variables → Actions
→ New repository secret

Name: ARGOCD_AUTH_TOKEN
Value: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

---

## 📦 Cấu Hình Repository

### **1. Add Git Repository qua CLI**

```bash
# ⚠️ QUAN TRỌNG: Add GitOps repository (cho GitHub Workflow)
argocd repo add https://github.com/TomJennyDev/flowise-gitops.git

# Nếu là private repository, cần credentials:
argocd repo add https://github.com/TomJennyDev/flowise-gitops.git \
  --username <github-username> \
  --password <github-personal-access-token>

# Add DevOps repo (system apps - optional)
argocd repo add https://github.com/TomJennyDev/devops.git

# Add private repo với SSH
argocd repo add git@github.com:TomJennyDev/flowise-gitops.git \
  --ssh-private-key-path ~/.ssh/id_rsa

# List repos
argocd repo list

# Verify connection
argocd repo get https://github.com/TomJennyDev/flowise-gitops.git
```

### **2. Add Repository qua Web UI**

```
Settings → Repositories → Connect Repo
→ Choose connection method (HTTPS/SSH)
→ Fill in credentials
→ Connect
```

### **3. Add Repository qua Values File** (Khuyến nghị)

```yaml
configs:
  repositories:
    # System apps repo
    devops-repo:
      url: https://github.com/TomJennyDev/devops.git
      type: git
      name: devops

    # ⚠️ GitOps repo - QUAN TRỌNG cho GitHub Workflow
    gitops-repo:
      url: https://github.com/TomJennyDev/flowise-gitops.git
      type: git
      name: flowise-gitops
      # Nếu private repo:
      # username: <github-username>
      # password: <github-token>
```

**Update Helm values và upgrade:**

```bash
# Edit values file
nano argocd/helm-values/argocd-values.yaml

# Upgrade ArgoCD
helm upgrade argocd argo/argo-cd \
  --namespace argocd \
  --version 7.7.11 \
  -f argocd/helm-values/argocd-values.yaml

# Verify repositories
argocd repo list
```

---

## 🚀 Deploy Applications

### **1. Tạo ArgoCD Applications cho GitHub Workflow** ⚠️ **QUAN TRỌNG**

**Tạo Application cho Dev Environment:**

```bash
# Create flowise-dev application
argocd app create flowise-dev \
  --repo https://github.com/TomJennyDev/flowise-gitops.git \
  --path overlays/dev \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace flowise-dev \
  --sync-policy automated \
  --auto-prune \
  --self-heal \
  --project default

# Hoặc dùng YAML manifest (khuyến nghị)
cat <<EOF | kubectl apply -f -
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
EOF

# Verify
argocd app get flowise-dev
kubectl get application flowise-dev -n argocd
```

**Tạo Applications cho Staging & Production:**

```bash
# Staging
argocd app create flowise-staging \
  --repo https://github.com/TomJennyDev/flowise-gitops.git \
  --path overlays/staging \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace flowise-staging \
  --sync-policy automated \
  --auto-prune \
  --self-heal

# Production
argocd app create flowise-production \
  --repo https://github.com/TomJennyDev/flowise-gitops.git \
  --path overlays/production \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace flowise-prod \
  --sync-policy automated \
  --auto-prune \
  --self-heal

# List all applications
argocd app list
```

### **2. Deploy App of Apps (System Apps)**

```bash
# Apply App of Apps cho system apps (Prometheus, etc.)
kubectl apply -f argocd/app-of-apps-kustomize-dev.yaml

# Verify
kubectl get applications -n argocd

# Check sync status
argocd app list
argocd app get app-of-apps-dev
```

### **3. Deploy Individual Application**

```bash
# Deploy Prometheus
kubectl apply -f argocd/system-apps-kustomize/prometheus/overlays/dev/kustomization.yaml

# Sync manually
argocd app sync prometheus

# Watch sync progress
argocd app sync prometheus --watch
```

### **4. Test GitHub Workflow Integration**

```bash
# Manually trigger app sync (simulate GitHub Actions)
argocd app get flowise-dev --refresh
argocd app sync flowise-dev --prune --force

# Wait for sync to complete
argocd app wait flowise-dev --health --timeout 600

# Check application status
argocd app get flowise-dev

# Expected output:
# Name:               flowise-dev
# Project:            default
# Server:             https://kubernetes.default.svc
# Namespace:          flowise-dev
# URL:                https://argocd.yourdomain.com/applications/flowise-dev
# Repo:               https://github.com/TomJennyDev/flowise-gitops.git
# Target:             main
# Path:               overlays/dev
# SyncWindow:         Sync Allowed
# Sync Policy:        Automated (Prune)
# Sync Status:        Synced to main (abc1234)
# Health Status:      Healthy
```

### **5. Create Application via CLI**

```bash
argocd app create my-app \
  --repo https://github.com/TomJennyDev/devops.git \
  --path argocd/system-apps-kustomize/prometheus/overlays/dev \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace monitoring \
  --sync-policy automated \
  --auto-prune \
  --self-heal
```

  --auto-prune \
  --self-heal

```

---

## 🔧 Update ArgoCD

### **1. Update Values**

```bash
# Edit values file
nano argocd/helm-values/argocd-values.yaml

# Upgrade
helm upgrade argocd argo/argo-cd \
  --namespace argocd \
  --version 7.7.11 \
  -f argocd/helm-values/argocd-values.yaml
```

### **2. Upgrade to New Version**

```bash
# Check available versions
helm search repo argo-cd --versions

# Upgrade to new version
helm upgrade argocd argo/argo-cd \
  --namespace argocd \
  --version 7.8.0 \
  -f argocd/helm-values/argocd-values.yaml

# Verify
helm list -n argocd
kubectl get pods -n argocd
```

---

## 🗑️ Uninstall ArgoCD

```bash
# Delete all applications first
argocd app delete --all

# Uninstall Helm release
helm uninstall argocd -n argocd

# Delete namespace
kubectl delete namespace argocd

# Clean up CRDs (nếu cần)
kubectl delete crd applications.argoproj.io
kubectl delete crd applicationsets.argoproj.io
kubectl delete crd appprojects.argoproj.io
```

---

## 🐛 Troubleshooting

### **1. ArgoCD Server không khởi động**

```bash
# Check logs
kubectl logs -n argocd deployment/argocd-server

# Check events
kubectl get events -n argocd --sort-by='.lastTimestamp'

# Restart pods
kubectl rollout restart deployment argocd-server -n argocd
```

### **2. ALB không tạo được**

```bash
# Check AWS Load Balancer Controller
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Check Ingress events
kubectl describe ingress argocd-server -n argocd

# Verify IAM permissions
aws iam get-role --role-name dev-eks-cluster-aws-load-balancer-controller
```

### **3. Certificate không valid**

```bash
# Check ACM certificate
aws acm describe-certificate --certificate-arn <arn>

# Verify DNS validation
aws route53 list-resource-record-sets --hosted-zone-id <zone-id>

# Update Ingress annotation
kubectl annotate ingress argocd-server -n argocd \
  alb.ingress.kubernetes.io/certificate-arn=<new-arn> --overwrite
```

### **4. Application không sync được**

```bash
# Check application status
argocd app get <app-name>

# View sync errors
kubectl describe application <app-name> -n argocd

# Manual sync
argocd app sync <app-name> --force

# Hard refresh
argocd app get <app-name> --hard-refresh
```

### **5. Repository connection failed**

```bash
# Test connection
argocd repo get https://github.com/TomJennyDev/flowise-gitops.git

# Re-add repository
argocd repo rm https://github.com/TomJennyDev/flowise-gitops.git
argocd repo add https://github.com/TomJennyDev/flowise-gitops.git

# Check repo server logs
kubectl logs -n argocd deployment/argocd-repo-server
```

### **6. GitHub Actions Cannot Connect to ArgoCD**

```bash
# Check if gRPC-web is enabled
kubectl get configmap argocd-cmd-params-cm -n argocd -o yaml

# Should have:
# data:
#   server.enable.gzip: "true"

# Test connection from local (simulate GitHub Actions)
argocd login argocd.yourdomain.com \
  --auth-token ${ARGOCD_AUTH_TOKEN} \
  --grpc-web \
  --insecure

# Check server logs
kubectl logs -n argocd deployment/argocd-server --tail=100

# Verify Ingress allows gRPC
kubectl describe ingress argocd-server -n argocd
```

### **7. ArgoCD Cannot Update Application (GitHub Workflow)**

```bash
# Check RBAC permissions
kubectl get configmap argocd-rbac-cm -n argocd -o yaml

# Test API access
argocd app get flowise-dev --auth-token ${ARGOCD_AUTH_TOKEN}

# Manual sync to test
argocd app sync flowise-dev --auth-token ${ARGOCD_AUTH_TOKEN}

# Check application controller logs
kubectl logs -n argocd deployment/argocd-application-controller --tail=200
```

---

## 🔧 Tích Hợp GitHub Workflow

### **Checklist cho GitHub Actions Integration:**

```bash
# 1. Verify ArgoCD is accessible
curl -k https://argocd.yourdomain.com/healthz

# 2. Test API token
argocd login argocd.yourdomain.com --auth-token ${ARGOCD_AUTH_TOKEN} --grpc-web

# 3. Verify GitOps repository is added
argocd repo list | grep flowise-gitops

# 4. Verify applications exist
argocd app list | grep flowise

# 5. Test sync from CLI (simulate GitHub Actions)
argocd app get flowise-dev --refresh
argocd app sync flowise-dev --prune --force
argocd app wait flowise-dev --health --timeout 600

# 6. Check application resources
argocd app resources flowise-dev

# Expected workflow:
# GitHub Actions → Update kustomization.yaml → Push to GitOps repo
# → ArgoCD detects change → Auto sync (or manual via CLI)
# → Deploy to K8s → Health check
```

### **Test Script cho GitHub Workflow:**

```bash
#!/bin/bash
set -e

ARGOCD_SERVER="argocd.yourdomain.com"
ARGOCD_AUTH_TOKEN="<your-token>"
APP_NAME="flowise-dev"

echo "🔐 Logging in to ArgoCD..."
argocd login ${ARGOCD_SERVER} \
    --auth-token ${ARGOCD_AUTH_TOKEN} \
    --grpc-web \
    --insecure

echo "🔄 Refreshing application..."
argocd app get ${APP_NAME} --refresh > /dev/null

echo "🚀 Triggering sync..."
argocd app sync ${APP_NAME} --prune --force

echo "⏳ Waiting for deployment..."
argocd app wait ${APP_NAME} --health --timeout 600

echo "✅ Deployment completed!"
argocd app get ${APP_NAME}
```

---

## 📚 Tài Liệu Tham Khảo

- **ArgoCD Documentation**: <https://argo-cd.readthedocs.io/>
- **Helm Chart**: <https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd>
- **AWS Load Balancer Controller**: <https://kubernetes-sigs.github.io/aws-load-balancer-controller/>
- **Best Practices**: <https://argo-cd.readthedocs.io/en/stable/operator-manual/>

---

## ✅ Checklist Triển Khai

### **Cơ Bản:**

- [ ] EKS Cluster đã được tạo
- [ ] kubectl đã được cấu hình
- [ ] Helm đã được cài đặt
- [ ] AWS Load Balancer Controller đã được deploy
- [ ] ACM Certificate đã được tạo và validated
- [ ] Values file đã được cấu hình đúng
- [ ] ArgoCD đã được install thành công
- [ ] Ingress đã tạo ALB thành công
- [ ] DNS đã được cấu hình trỏ về ALB
- [ ] Truy cập được ArgoCD Web UI
- [ ] Đã đổi admin password

### **GitHub Workflow Integration:** ⚠️ **QUAN TRỌNG**

- [ ] GitOps repository đã được add vào ArgoCD
- [ ] API Token đã được generate
- [ ] API Token đã được lưu vào GitHub Secret `ARGOCD_AUTH_TOKEN`
- [ ] ArgoCD Server URL đã được lưu vào GitHub Secret `ARGOCD_SERVER`
- [ ] gRPC-web đã được enable trong ArgoCD config
- [ ] RBAC policy đã được cấu hình cho CI/CD access
- [ ] ArgoCD Applications đã được tạo cho từng environment:
  - [ ] flowise-dev
  - [ ] flowise-staging
  - [ ] flowise-production
- [ ] Auto-sync policy đã được enable
- [ ] Prune và self-heal đã được enable
- [ ] Test sync từ CLI thành công
- [ ] Verify application health status

### **Testing:**

```bash
# Complete verification
argocd login argocd.yourdomain.com --auth-token ${ARGOCD_AUTH_TOKEN} --grpc-web
argocd repo list | grep flowise-gitops
argocd app list | grep flowise
argocd app get flowise-dev
argocd app sync flowise-dev --dry-run
```

---

**🎉 Hoàn Thành!** ArgoCD đã sẵn sàng để deploy applications!
