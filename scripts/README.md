# GitOps Deployment Scripts

Scripts để quản lý EKS cluster và triển khai ArgoCD với GitOps pattern.

**Dự án hiện tại:** Development environment với EKS 1.31, 2 worker nodes, WAF protection, ArgoCD GitOps.

---

## 📋 Prerequisites

Trước khi chạy bất kỳ script nào, đảm bảo:

- ✅ AWS CLI configured (`aws configure`)
- ✅ kubectl installed và configured
- ✅ Helm 3 installed
- ✅ **EKS Cluster đã deploy** (qua Terraform trong `terraform-eks/`)
- ✅ Có quyền admin trên EKS cluster
- ✅ ArgoCD CLI installed (optional, cho advanced operations)

**Kiểm tra nhanh:**
```bash
aws sts get-caller-identity  # Check AWS credentials
kubectl get nodes            # Check cluster access
helm version                 # Check Helm
```

---

## 🚀 QUICK START - 3 Cách Deploy

### Option 1: 🎯 ONE-COMMAND BOOTSTRAP (RECOMMENDED)

**Cách nhanh nhất - Deploy toàn bộ infrastructure + apps trong 1 lệnh:**

```bash
cd scripts
./bootstrap.sh
```

**Script này sẽ tự động:**
1. Export cluster information từ Terraform
2. Update kubeconfig để kubectl kết nối cluster
3. Deploy ArgoCD lên cluster
4. Chờ ArgoCD ready (pods, ingress, ALB)
5. Deploy ArgoCD Projects (RBAC cho infrastructure + applications)
6. Deploy Infrastructure App-of-Apps (ALB Controller, Prometheus/Grafana)
7. Deploy Flowise App-of-Apps (Backend + Frontend + Database)
8. Update DNS records (flowise-dev.do2506.click, grafana-dev.do2506.click)
9. Hiển thị ArgoCD credentials và URLs

**Thời gian:** ~15-20 phút (bao gồm chờ ALB provisioning)

**Sau khi chạy xong:**
- ✅ ArgoCD UI: https://argocd.do2506.click
- ✅ Flowise: https://flowise-dev.do2506.click
- ✅ Grafana: https://grafana-dev.do2506.click
- ✅ All apps được ArgoCD quản lý tự động qua Git

---

### Option 2: 📝 STEP-BY-STEP MANUAL (Chi tiết từng bước)

**Dùng khi:** Bạn muốn control từng bước, hiểu rõ quá trình, hoặc troubleshoot

**Thứ tự chạy:**

```bash
cd scripts

# BƯỚC 1: Export cluster info từ Terraform outputs
./export-cluster-info.sh
# Mục đích: Tạo files cluster-info chứa VPC ID, Subnet IDs, OIDC Provider, etc.
# Output: environments/dev/cluster-info/*.yaml|.json|.sh

# BƯỚC 2: Update kubeconfig để kubectl connect
./update-kubeconfig.sh
# Mục đích: Configure kubectl để kết nối EKS cluster
# Verify: kubectl get nodes (should show 2 nodes)

# BƯỚC 3: Deploy ArgoCD
./deploy-argocd.sh
# Mục đích: Deploy ArgoCD lên cluster với Helm
# Thời gian: 5-10 phút (chờ ALB tạo)
# Output: ArgoCD URL, admin password

# BƯỚC 4: Get ArgoCD authentication token
./get-argocd-token.sh
source ~/.argocd-credentials.env
# Mục đích: Tạo token để ArgoCD CLI và GitHub Actions sử dụng
# Output: ~/.argocd-credentials.env với ARGOCD_SERVER, ARGOCD_AUTH_TOKEN

# BƯỚC 5: Deploy ArgoCD Projects (RBAC)
./deploy-projects.sh
# Mục đích: Tạo Projects để phân quyền (infrastructure, applications)
# Output: 2 ArgoCD Projects

# BƯỚC 6: Deploy Infrastructure App-of-Apps
./deploy-infrastructure.sh dev
# Mục đích: Deploy ALB Controller + Prometheus/Grafana qua ArgoCD
# Thời gian: 5-10 phút
# Namespace: kube-system (ALB), monitoring (Prometheus)

# BƯỚC 7: Deploy Flowise Application
./deploy-flowise.sh dev
# Mục đích: Deploy Flowise Backend + Frontend + PostgreSQL
# Thời gian: 5-10 phút
# Namespace: flowise-dev

# BƯỚC 8: Update DNS records
./update-flowise-dns.sh dev
./update-monitoring-dns.sh dev
# Mục đích: Point custom domains to ALB hostnames
# Domains: flowise-dev.do2506.click, grafana-dev.do2506.click

# BƯỚC 9: Verify health (optional)
./check-flowise-health.sh
# Mục đích: Check Flowise pods, service, ingress status
```

**Total time:** ~20-25 phút

---

### Option 3: 🔧 SELECTIVE DEPLOYMENT (Deploy từng phần)

**Dùng khi:** Chỉ muốn deploy/update specific components

```bash
# Deploy only ArgoCD
./deploy-argocd.sh

# Deploy only Flowise (ArgoCD must exist)
./deploy-flowise.sh dev

# Deploy only Monitoring (ArgoCD must exist)
./deploy-infrastructure.sh dev

# Update only DNS
./update-flowise-dns.sh dev
./update-monitoring-dns.sh dev
```

---

## � CHI TIẾT TỪNG SCRIPT

### 🔧 Setup & Configuration Scripts

#### 1. `export-cluster-info.sh`

**Mục đích:** Export thông tin cluster từ Terraform outputs ra nhiều formats

**Khi nào dùng:**
- Sau khi chạy `terraform apply`
- Khi cần refresh cluster information
- Trước khi deploy ArgoCD hoặc apps

**Usage:**
```bash
./export-cluster-info.sh
```

**Output files:** (trong `environments/dev/cluster-info/`)
- `terraform-outputs.json` - Raw Terraform outputs
- `cluster-info.yaml` - Structured YAML format
- `cluster-env.sh` - Environment variables (source-able)
- `argocd-cluster-values.yaml` - Helm values cho ArgoCD
- `cluster-info-configmap.yaml` - Kubernetes ConfigMap
- `README.md` - Quick reference

**Thông tin exported:**
- EKS Cluster Name, Region, Version
- VPC ID, Subnet IDs, Security Group IDs
- OIDC Provider ARN (cho IRSA)
- ECR Repository URLs
- NAT Gateway IPs

---

#### 2. `update-kubeconfig.sh`

**Mục đích:** Update kubectl config để connect EKS cluster

**Khi nào dùng:**
- Sau khi cluster được tạo lần đầu
- Khi kubectl không connect được cluster
- Khi switch giữa nhiều clusters

**Usage:**
```bash
./update-kubeconfig.sh
```

**What it does:**
```bash
# Internally runs:
aws eks update-kubeconfig --region <region> --name <cluster-name>
```

**Verify:**
```bash
kubectl config current-context  # Should show EKS cluster ARN
kubectl get nodes               # Should show 2 nodes (t3.large)
```

---

### 🚀 Core Deployment Scripts

#### 3. `deploy-argocd.sh`

**Mục đích:** Deploy ArgoCD lên EKS cluster qua Helm

**Prerequisites:**
- ✅ Cluster exists và kubectl configured
- ✅ Đã chạy `export-cluster-info.sh`

**Usage:**
```bash
./deploy-argocd.sh
```

**What it does:**
1. Verify prerequisites (kubectl, helm, cluster-info)
2. Create `argocd` namespace
3. Install ArgoCD Helm chart với custom values:
   - Enable Ingress với ALB annotations
   - Enable metrics
   - Set resource limits
   - Configure WAF protection
4. Wait for all ArgoCD pods ready (5-10 minutes)
5. Wait for ALB provisioning
6. Get admin password từ Kubernetes secret
7. Display credentials và next steps

**Output:**
```
✅ ArgoCD URL: https://argocd.do2506.click
✅ Username: admin
✅ Password: <random-generated>
✅ ALB DNS: k8s-argocd-argocdse-xxxxx.us-east-1.elb.amazonaws.com
```

**Ingress Configuration:**
- ALB Scheme: internet-facing
- SSL: ACM certificate (*.do2506.click)
- WAF: Protected by Web ACL
- Health check: /healthz

---

#### 4. `deploy-projects.sh`

**Mục đích:** Deploy ArgoCD Projects để phân quyền RBAC

**Prerequisites:**
- ✅ ArgoCD đã deployed

**Usage:**
```bash
./deploy-projects.sh
```

**What it creates:**

**1. Infrastructure Project:**
```yaml
Name: infrastructure
Description: Infrastructure components (ALB, Prometheus, etc.)
Source Repos: https://github.com/TomJennyDev/devops.git
Destinations:
  - kube-system (ALB Controller)
  - monitoring (Prometheus/Grafana)
  - argocd (ArgoCD itself)
Cluster Resources: yes (can create namespaces, CRDs)
```

**2. Applications Project:**
```yaml
Name: applications
Description: Business applications (Flowise, etc.)
Source Repos: https://github.com/TomJennyDev/devops.git
Destinations:
  - flowise-dev
  - flowise-staging
  - flowise-production
Cluster Resources: no (restricted to namespace)
```

**Tại sao cần Projects:**
- 🔒 Security: Phân quyền rõ ràng giữa infrastructure vs apps
- 🎯 Organization: Group related apps together
- 🚫 Isolation: Apps không thể deploy vào namespaces không được phép

---

#### 5. `deploy-infrastructure.sh`

**Mục đích:** Deploy Infrastructure App-of-Apps (ALB Controller + Prometheus/Grafana)

**Prerequisites:**
- ✅ ArgoCD deployed
- ✅ Projects deployed

**Usage:**
```bash
./deploy-infrastructure.sh dev
```

**What it deploys:**

**1. AWS Load Balancer Controller:**
- Namespace: `kube-system`
- Purpose: Manage ALBs from Kubernetes Ingress
- ServiceAccount: Uses IRSA (IAM Role for Service Account)
- Permissions: Create/Delete ALBs, Target Groups, Listeners

**2. Prometheus Stack:**
- Namespace: `monitoring`
- Components:
  - Prometheus Server (metrics collection)
  - Grafana (visualization)
  - AlertManager (alerting)
  - Node Exporter (node metrics)
  - Kube State Metrics (k8s metrics)
- Ingress: grafana-dev.do2506.click
- Storage: 10Gi PVC for Prometheus data

**Deployment time:** 5-10 minutes

**Verify:**
```bash
# Check ALB Controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Check Prometheus
kubectl get pods -n monitoring
kubectl get ingress -n monitoring

# Check Grafana
curl -k https://grafana-dev.do2506.click
```

---

#### 6. `deploy-flowise.sh`

**Mục đích:** Deploy Flowise application (Backend + Frontend + Database)

**Prerequisites:**
- ✅ ArgoCD deployed
- ✅ Projects deployed
- ✅ ALB Controller deployed (from infrastructure)

**Usage:**
```bash
./deploy-flowise.sh dev
```

**What it deploys:**

**1. PostgreSQL Database:**
- Type: StatefulSet
- Storage: 10Gi PVC (EBS gp3)
- Purpose: Store Flowise data (flows, credentials, logs)
- Port: 5432

**2. Flowise Backend:**
- Image: flowiseai/flowise:latest
- Replicas: 2
- Port: 3000
- Environment:
  - DATABASE_TYPE=postgres
  - DATABASE_HOST=flowise-postgres
  - FLOWISE_USERNAME/PASSWORD (from ConfigMap)

**3. Flowise Frontend:**
- Image: nginx:alpine
- Replicas: 2
- Port: 80
- Serves: React SPA connecting to backend API

**4. Services:**
- flowise-backend: ClusterIP (internal)
- flowise-frontend: ClusterIP (internal)
- flowise-postgres: ClusterIP (internal)

**5. Ingress:**
- Host: flowise-dev.do2506.click
- ALB: internet-facing, HTTPS (ACM cert)
- WAF: Protected by Web ACL
- Backend routing: / → frontend, /api → backend

**Deployment time:** 5-10 minutes

**Verify:**
```bash
kubectl get pods -n flowise-dev
kubectl get ingress -n flowise-dev
curl -k https://flowise-dev.do2506.click
```

---

### 🌐 DNS Management Scripts

#### 7. `update-dns-records.sh`

**Mục đích:** Update ALL DNS records (ArgoCD, Flowise, Grafana) to point to ALBs

**Usage:**
```bash
./update-dns-records.sh
```

**What it updates:**
- argocd.do2506.click → ArgoCD ALB
- flowise-dev.do2506.click → Flowise ALB
- grafana-dev.do2506.click → Monitoring ALB

**Internally calls:**
- `update-flowise-dns.sh dev`
- `update-monitoring-dns.sh dev`

---

#### 8. `update-flowise-dns.sh`

**Mục đích:** Update Route53 A record cho Flowise app

**Usage:**
```bash
./update-flowise-dns.sh dev
```

**What it does:**
1. Get ALB hostname từ Flowise ingress
2. Get ALB Hosted Zone ID
3. Update Route53 A record (ALIAS type):
   - Name: flowise-dev.do2506.click
   - Type: A
   - Alias Target: ALB DNS name

**DNS TTL:** 300 seconds (5 minutes propagation)

**Verify:**
```bash
nslookup flowise-dev.do2506.click
dig flowise-dev.do2506.click
```

---

#### 9. `update-monitoring-dns.sh`

**Mục đích:** Update Route53 A record cho Grafana

**Usage:**
```bash
./update-monitoring-dns.sh dev
```

**What it does:**
1. Get monitoring ALB hostname từ Grafana ingress
2. Update Route53 A record:
   - Name: grafana-dev.do2506.click
   - Target: Monitoring ALB

**Verify:**
```bash
nslookup grafana-dev.do2506.click
curl -k https://grafana-dev.do2506.click
```

---

### 🔐 Authentication & Security Scripts

#### 10. `get-argocd-token.sh`

**Mục đích:** Generate ArgoCD authentication token cho CLI và GitHub Actions

**Prerequisites:**
- ✅ ArgoCD deployed và accessible
- ✅ DNS đã configured

**Usage:**
```bash
./get-argocd-token.sh
source ~/.argocd-credentials.env
```

**What it does:**
1. Login to ArgoCD với admin credentials
2. Generate auth token (no expiration)
3. Save to `~/.argocd-credentials.env`:
   ```bash
   export ARGOCD_SERVER="argocd.do2506.click"
   export ARGOCD_AUTH_TOKEN="eyJhbGc..."
   export ARGOCD_OPTS="--insecure"
   ```

**Use cases:**
- ArgoCD CLI commands: `argocd app list`, `argocd app sync`
- GitHub Actions: Deploy apps automatically from CI/CD
- Scripts: Automate ArgoCD operations

**Verify:**
```bash
argocd app list  # Should work without manual login
```

---

#### 11. `update-waf-ingress.sh`

**Mục đích:** Update Ingress annotations với correct WAF Web ACL ARN

**Khi nào dùng:**
- Sau khi recreate WAF (terraform destroy/apply)
- Khi WAF ARN thay đổi
- Khi ingress không tạo được ALB (WAFNonexistentItemException)

**Usage:**
```bash
./update-waf-ingress.sh
```

**What it does:**
1. Get current WAF Web ACL ARN từ Terraform output
2. Find all Ingress resources có WAF annotation
3. Update annotation với correct ARN:
   ```yaml
   alb.ingress.kubernetes.io/wafv2-acl-arn: arn:aws:wafv2:us-east-1:372836560690:regional/webacl/...
   ```
4. Verify ALB creation

**Files updated:**
- `argocd/apps/flowise/overlays/dev/ingress.yaml`
- `argocd/infrastructure/prometheus/overlays/dev/ingress.yaml`

---

### 🗑️ Cleanup Scripts

#### 12. `remove-argocd.sh`

**Mục đích:** Remove ArgoCD và tất cả deployed resources

**⚠️ WARNING:** 
- Sẽ xóa ALL applications (Flowise, Prometheus, etc.)
- Sẽ xóa persistent data (databases, metrics)
- EKS cluster vẫn tồn tại (không xóa)

**Usage:**
```bash
./remove-argocd.sh
```

**What it removes:**
1. All ArgoCD Applications (flowise, prometheus, alb-controller)
2. ArgoCD Projects (infrastructure, applications)
3. ArgoCD namespace (including CRDs, Helm release)
4. Application namespaces:
   - flowise-dev (including PVCs, databases)
   - monitoring (including PVCs, Prometheus data)
5. ALBs (automatically deleted by ALB Controller)
6. Local credentials (~/.argocd-credentials.env)

**What it KEEPS:**
- ✅ EKS Cluster và worker nodes
- ✅ VPC, Subnets, Security Groups
- ✅ Route53 DNS records
- ✅ WAF Web ACL
- ✅ IAM Roles (OIDC, ALB Controller)
- ✅ cert-manager (if deployed separately)

**Deployment time:** 3-5 minutes

**After removal:**
```bash
kubectl get pods -A  # Only kube-system pods remain
kubectl get ingress -A  # No ingresses
kubectl get namespaces  # argocd, flowise-dev, monitoring gone
```

**Re-deploy:**
```bash
./bootstrap.sh  # Start fresh
```

---

### 🔧 Configuration & Update Scripts

#### 13. `update-alb-controller-config.sh`

**Mục đích:** Update ALB Controller Helm values với cluster-specific configs

**Khi nào dùng:**
- Sau khi thay đổi cluster configuration
- Khi update VPC hoặc subnets
- Khi troubleshoot ALB issues

**Usage:**
```bash
./update-alb-controller-config.sh dev
```

**What it updates:**
- Cluster name
- AWS region
- VPC ID
- ServiceAccount annotations (IRSA role ARN)

**File location:**
- `argocd/infrastructure/alb-controller/overlays/dev/values.yaml`

---

### 🏥 Health Check & Monitoring Scripts

#### 14. `check-flowise-health.sh`

**Mục đích:** Comprehensive health check cho Flowise application

**Usage:**
```bash
./check-flowise-health.sh
```

**What it checks:**

**1. Pods Status:**
```bash
✅ flowise-backend-xxx: Running (2/2)
✅ flowise-frontend-xxx: Running (2/2)
✅ flowise-postgres-0: Running (1/1)
```

**2. Services:**
```bash
✅ flowise-backend: ClusterIP (Port 3000)
✅ flowise-frontend: ClusterIP (Port 80)
✅ flowise-postgres: ClusterIP (Port 5432)
```

**3. Ingress:**
```bash
✅ flowise-ingress: ALB DNS assigned
✅ Hosts: flowise-dev.do2506.click
✅ WAF: Protected
```

**4. ALB Status:**
```bash
✅ ALB: Active (k8s-flowised-flowisein-xxxxx)
✅ Target Groups: Healthy
✅ SSL: Certificate valid
```

**5. DNS Resolution:**
```bash
✅ flowise-dev.do2506.click → ALB IP
```

**6. HTTP(S) Check:**
```bash
✅ HTTP 200: Application responding
✅ Response time: <2s
```

**Output format:** Colored text với pass/fail indicators

---

## 🔄 COMMON WORKFLOWS

### Workflow 1: 🆕 First-Time Setup (Hoàn toàn mới)

**Scenario:** Bạn vừa chạy `terraform apply` xong và có EKS cluster mới tinh

**Steps:**
```bash
cd scripts

# 1. Export thông tin cluster
./export-cluster-info.sh

# 2. Configure kubectl
./update-kubeconfig.sh
kubectl get nodes  # Verify: Should see 2 t3.large nodes

# 3. Deploy toàn bộ (recommended)
./bootstrap.sh

# Hoặc manual từng bước:
./deploy-argocd.sh
./get-argocd-token.sh && source ~/.argocd-credentials.env
./deploy-projects.sh
./deploy-infrastructure.sh dev
./deploy-flowise.sh dev
./update-dns-records.sh
```

**Thời gian:** 15-20 phút
**Kết quả:** ArgoCD + Flowise + Grafana hoạt động, tự động sync từ Git

---

### Workflow 2: 🔄 Update Application (Đã có ArgoCD)

**Scenario:** ArgoCD đang chạy, bạn muốn update Flowise hoặc Prometheus config

**Steps:**
```bash
# 1. Edit configs trong Git repo
cd argocd/apps/flowise/overlays/dev
nano deployment.yaml  # Thay đổi image version, replicas, env vars, etc.

# 2. Commit và push
git add .
git commit -m "Update Flowise to v1.2.3"
git push

# 3. ArgoCD tự động detect changes trong ~3 phút
# Hoặc manual sync ngay:
argocd app sync flowise-dev
# Or via UI: Click "Sync" button

# 4. Verify deployment
kubectl get pods -n flowise-dev -w
kubectl rollout status deployment/flowise-backend -n flowise-dev
```

**Thời gian:** 2-5 phút
**Không cần:** Re-run scripts, ArgoCD tự động sync!

---

### Workflow 3: 🗑️ Clean Up và Re-Deploy

**Scenario:** Có issues, muốn xóa sạch và deploy lại từ đầu

**Steps:**
```bash
cd scripts

# 1. Remove toàn bộ ArgoCD và apps
./remove-argocd.sh

# Chờ 3-5 phút cho cleanup

# 2. Verify cleanup
kubectl get pods -A  # Only kube-system pods remain
kubectl get namespaces  # argocd, flowise-dev, monitoring should be gone

# 3. Deploy lại từ đầu
./bootstrap.sh

# Hoặc manual:
./deploy-argocd.sh
./deploy-projects.sh
./deploy-infrastructure.sh dev
./deploy-flowise.sh dev
./update-dns-records.sh
```

**Thời gian:** 20-25 phút (cleanup + redeploy)

---

### Workflow 4: 🔧 Fix WAF ARN Mismatch

**Scenario:** Sau khi `terraform destroy` + `apply`, WAF Web ACL ARN thay đổi, ingress không tạo được ALB

**Lỗi thường gặp:**
```
Failed deploy model due to WAFNonexistentItemException
WAF Web ACL with ARN 'arn:aws:wafv2:...old-arn...' not found
```

**Steps:**
```bash
cd scripts

# 1. Get current WAF ARN từ Terraform
cd ../terraform-eks/environments/dev
terraform output waf_web_acl_arn

# Copy ARN: arn:aws:wafv2:us-east-1:372836560690:regional/webacl/...

# 2. Update ingress files
cd ../../scripts
./update-waf-ingress.sh

# Hoặc manual update:
cd ../argocd/apps/flowise/overlays/dev
nano ingress.yaml
# Update line:
# alb.ingress.kubernetes.io/wafv2-acl-arn: <paste-new-arn>

# 3. Commit và push
git add .
git commit -m "Update WAF ARN after terraform recreate"
git push

# 4. Sync ArgoCD (tự động hoặc manual)
argocd app sync flowise-dev

# 5. Verify ALB creation
kubectl get ingress -n flowise-dev -w
kubectl describe ingress flowise-ingress -n flowise-dev
```

**Thời gian:** 5-10 phút (bao gồm ALB provisioning)

---

### Workflow 5: 🌐 Update DNS Only

**Scenario:** ALB hostname đã thay đổi (sau recreate), cần update Route53

**Steps:**
```bash
cd scripts

# Update tất cả DNS records
./update-dns-records.sh

# Hoặc update từng domain:
./update-flowise-dns.sh dev      # flowise-dev.do2506.click
./update-monitoring-dns.sh dev   # grafana-dev.do2506.click

# Verify DNS propagation (5 minutes TTL)
nslookup flowise-dev.do2506.click
dig flowise-dev.do2506.click

# Test HTTP(S)
curl -k https://flowise-dev.do2506.click
curl -k https://grafana-dev.do2506.click
```

**Thời gian:** 5-10 phút (DNS propagation)

---

### Workflow 6: 🏥 Health Check & Troubleshooting

**Scenario:** Flowise không hoạt động, cần check toàn bộ stack

**Steps:**
```bash
cd scripts

# 1. Comprehensive health check
./check-flowise-health.sh

# 2. Check individual components nếu có issues:

# ArgoCD
kubectl get pods -n argocd
kubectl get applications -n argocd
argocd app list
argocd app get flowise-dev

# Flowise
kubectl get pods -n flowise-dev
kubectl logs -n flowise-dev -l app=flowise-backend --tail=50
kubectl describe pod <pod-name> -n flowise-dev

# Ingress & ALB
kubectl get ingress -n flowise-dev
kubectl describe ingress flowise-ingress -n flowise-dev
aws elbv2 describe-load-balancers --query 'LoadBalancers[?contains(LoadBalancerName, `flowise`)]'

# WAF
aws wafv2 list-web-acls --scope REGIONAL --region us-east-1
aws wafv2 list-resources-for-web-acl --web-acl-arn <arn> --resource-type APPLICATION_LOAD_BALANCER

# DNS
nslookup flowise-dev.do2506.click
dig flowise-dev.do2506.click +short

# Database connection
kubectl exec -it flowise-postgres-0 -n flowise-dev -- psql -U flowise -c '\l'
```

**Common Issues:**

| Issue | Cause | Solution |
|-------|-------|----------|
| ALB not created | WAF ARN mismatch | Run `./update-waf-ingress.sh` |
| DNS not resolving | Route53 not updated | Run `./update-flowise-dns.sh dev` |
| Pods CrashLoopBackOff | DB connection failed | Check postgres pod, secrets |
| ArgoCD app OutOfSync | Git changes not synced | `argocd app sync <app-name>` |
| 502 Bad Gateway | Backend not ready | Check backend pods logs |

---

### Workflow 7: 📊 Add New Application

**Scenario:** Muốn deploy thêm app mới (ví dụ: n8n, langflow, etc.)

**Steps:**
```bash
# 1. Tạo app manifests
cd argocd/apps
mkdir -p myapp/base myapp/overlays/dev

# 2. Create Kustomize structure
# base/deployment.yaml
# base/service.yaml
# base/kustomization.yaml
# overlays/dev/ingress.yaml
# overlays/dev/kustomization.yaml

# 3. Create ArgoCD Application
nano argocd/bootstrap/myapp-dev.yaml
```

```yaml
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

```bash
# 4. Deploy
kubectl apply -f argocd/bootstrap/myapp-dev.yaml

# 5. Verify
argocd app get myapp-dev
kubectl get pods -n myapp-dev

# 6. Update DNS (nếu có ingress)
# Add script hoặc manual update Route53
```

---

### Workflow 8: 🚨 Rollback Application

**Scenario:** Deployment mới có bug, cần rollback version cũ

**Option 1: Via ArgoCD (Recommended)**
```bash
# List sync history
argocd app history flowise-dev

# Rollback to specific revision
argocd app rollback flowise-dev <revision-number>

# Example:
argocd app rollback flowise-dev 5
```

**Option 2: Via Kubectl**
```bash
# Rollback deployment
kubectl rollout undo deployment/flowise-backend -n flowise-dev

# Check status
kubectl rollout status deployment/flowise-backend -n flowise-dev

# View history
kubectl rollout history deployment/flowise-backend -n flowise-dev
```

**Option 3: Via Git**
```bash
# Revert git commit
git log --oneline  # Find commit hash
git revert <commit-hash>
git push

# ArgoCD sẽ tự động sync về version cũ
```

---

## 📁 RELATED DIRECTORIES

```
d:\devops\gitops\
│
├── scripts/                    # ← Scripts trong README này
│   ├── bootstrap.sh           # Master deployment script
│   ├── deploy-argocd.sh       # Deploy ArgoCD
│   ├── deploy-projects.sh     # Deploy Projects (RBAC)
│   ├── deploy-infrastructure.sh  # Deploy ALB + Prometheus
│   ├── deploy-flowise.sh      # Deploy Flowise app
│   ├── remove-argocd.sh       # Cleanup script
│   ├── export-cluster-info.sh # Export Terraform outputs
│   ├── update-kubeconfig.sh   # Configure kubectl
│   ├── get-argocd-token.sh    # Generate auth token
│   ├── update-dns-records.sh  # Update all DNS
│   ├── update-flowise-dns.sh  # Update Flowise DNS
│   ├── update-monitoring-dns.sh  # Update Grafana DNS
│   ├── update-waf-ingress.sh  # Update WAF ARN
│   ├── update-alb-controller-config.sh  # Update ALB config
│   ├── check-flowise-health.sh  # Health check
│   └── README.md              # This file
│
├── terraform-eks/             # Infrastructure as Code
│   ├── main.tf                # Root module
│   ├── modules/               # Reusable modules (VPC, EKS, WAF, etc.)
│   ├── environments/
│   │   └── dev/
│   │       ├── main.tf
│   │       ├── backend.tf     # S3 state management
│   │       ├── terraform.tfvars  # Dev-specific values
│   │       └── cluster-info/  # ← Generated by export-cluster-info.sh
│   │           ├── terraform-outputs.json
│   │           ├── cluster-info.yaml
│   │           ├── cluster-env.sh
│   │           └── argocd-cluster-values.yaml
│   └── README.md              # Terraform documentation
│
├── argocd/                    # ArgoCD manifests (GitOps source)
│   ├── bootstrap/             # ArgoCD Applications
│   │   ├── infrastructure-apps-dev.yaml  # App-of-Apps for infra
│   │   └── flowise-dev.yaml              # App-of-Apps for Flowise
│   ├── projects/              # ArgoCD Projects (RBAC)
│   │   ├── infrastructure.yaml
│   │   └── applications.yaml
│   ├── infrastructure/        # Infrastructure components
│   │   ├── alb-controller/
│   │   │   ├── base/
│   │   │   └── overlays/dev/
│   │   └── prometheus/
│   │       ├── base/
│   │       └── overlays/dev/
│   ├── apps/                  # Business applications
│   │   └── flowise/
│   │       ├── base/
│   │       │   ├── deployment.yaml
│   │       │   ├── service.yaml
│   │       │   └── kustomization.yaml
│   │       └── overlays/dev/
│   │           ├── ingress.yaml
│   │           ├── configmap.yaml
│   │           └── kustomization.yaml
│   ├── config/                # Shared configurations
│   │   ├── argocd/            # ArgoCD Helm values
│   │   ├── prometheus/        # Prometheus configs
│   │   └── shared/            # Shared ConfigMaps
│   └── docs/                  # ArgoCD documentation
│
└── docs/                      # Project documentation
    ├── ARGOCD-DEPLOYMENT.md
    ├── TERRAFORM-DEPLOYMENT.md
    ├── NAMESPACE-ARCHITECTURE.md
    ├── WAF-DEPLOYMENT.md
    └── ...
```

---

## 🔍 TROUBLESHOOTING GUIDE

### Issue 1: ArgoCD không accessible sau deploy

**Symptoms:**
```bash
curl https://argocd.do2506.click
# curl: (6) Could not resolve host: argocd.do2506.click
```

**Diagnosis:**
```bash
# Check ArgoCD pods
kubectl get pods -n argocd
# All pods should be Running

# Check ingress
kubectl get ingress -n argocd
# Should have ALB hostname assigned

# Check ALB status
kubectl describe ingress argocd-server -n argocd
# Look for errors in Events section

# Check DNS
nslookup argocd.do2506.click
# Should return ALB IP
```

**Solutions:**

**A. ALB not created:**
```bash
# Check WAF ARN in ingress
kubectl get ingress argocd-server -n argocd -o yaml | grep wafv2

# Update WAF ARN nếu sai
cd scripts
./update-waf-ingress.sh
```

**B. DNS not configured:**
```bash
cd scripts
./update-dns-records.sh

# Wait 5 minutes for DNS propagation
nslookup argocd.do2506.click
```

**C. ALB Controller not installed:**
```bash
# Check ALB Controller pod
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# If not exists, deploy via infrastructure
cd scripts
./deploy-infrastructure.sh dev
```

---

### Issue 2: Applications OutOfSync trong ArgoCD

**Symptoms:**
```bash
argocd app list
# NAME         STATUS     HEALTH
# flowise-dev  OutOfSync  Degraded
```

**Diagnosis:**
```bash
# Check sync details
argocd app get flowise-dev

# Check diff
argocd app diff flowise-dev
```

**Solutions:**

**A. Manual sync:**
```bash
argocd app sync flowise-dev

# Force sync với prune
argocd app sync flowise-dev --prune --force
```

**B. Check auto-sync policy:**
```bash
# View application spec
kubectl get application flowise-dev -n argocd -o yaml

# Should have:
# syncPolicy:
#   automated:
#     prune: true
#     selfHeal: true
```

**C. Git credentials issue:**
```bash
# Check ArgoCD can access Git repo
argocd repo list

# If private repo, add SSH key hoặc token
argocd repo add https://github.com/TomJennyDev/devops.git \
  --username <github-username> \
  --password <github-token>
```

---

### Issue 3: Pods CrashLoopBackOff

**Symptoms:**
```bash
kubectl get pods -n flowise-dev
# NAME                        READY   STATUS             RESTARTS
# flowise-backend-xxx         0/2     CrashLoopBackOff   5
```

**Diagnosis:**
```bash
# Check logs
kubectl logs -n flowise-dev flowise-backend-xxx -c flowise
kubectl logs -n flowise-dev flowise-backend-xxx -c flowise --previous

# Check events
kubectl describe pod flowise-backend-xxx -n flowise-dev

# Check resource limits
kubectl top pods -n flowise-dev
```

**Solutions:**

**A. Database connection issue:**
```bash
# Check postgres pod
kubectl get pods -n flowise-dev -l app=postgres

# Test connection từ backend pod
kubectl exec -it flowise-backend-xxx -n flowise-dev -- sh
nc -zv flowise-postgres 5432

# Check database logs
kubectl logs -n flowise-dev flowise-postgres-0
```

**B. Environment variables missing:**
```bash
# Check ConfigMap
kubectl get configmap -n flowise-dev
kubectl describe configmap flowise-config -n flowise-dev

# Check secrets
kubectl get secrets -n flowise-dev
```

**C. Image pull issues:**
```bash
# Check image pull status
kubectl describe pod flowise-backend-xxx -n flowise-dev | grep -A5 "Events"

# If ImagePullBackOff:
# - Check image name/tag trong deployment.yaml
# - Check Docker Hub rate limits
# - Consider using ECR instead
```

---

### Issue 4: 502 Bad Gateway từ ALB

**Symptoms:**
```bash
curl https://flowise-dev.do2506.click
# <html><body><h1>502 Bad Gateway</h1></body></html>
```

**Diagnosis:**
```bash
# Check target groups health
aws elbv2 describe-target-health \
  --target-group-arn $(aws elbv2 describe-target-groups \
    --query 'TargetGroups[?contains(TargetGroupName, `flowise`)].TargetGroupArn' \
    --output text)

# Check backend pods
kubectl get pods -n flowise-dev -l app=flowise-backend
kubectl logs -n flowise-dev -l app=flowise-backend --tail=50

# Check service
kubectl get svc flowise-backend -n flowise-dev
kubectl describe svc flowise-backend -n flowise-dev
```

**Solutions:**

**A. Pods not ready:**
```bash
# Wait for pods to become ready
kubectl get pods -n flowise-dev -w

# Check readiness probe
kubectl describe pod flowise-backend-xxx -n flowise-dev | grep -A10 "Readiness"
```

**B. Service selector mismatch:**
```bash
# Check service selector
kubectl get svc flowise-backend -n flowise-dev -o yaml | grep -A5 "selector"

# Check pod labels
kubectl get pods -n flowise-dev --show-labels
```

**C. Target Group health check failing:**
```bash
# Check ingress health check config
kubectl get ingress flowise-ingress -n flowise-dev -o yaml | grep health

# Should have:
# alb.ingress.kubernetes.io/healthcheck-path: /health
# alb.ingress.kubernetes.io/healthcheck-port: "3000"
```

---

### Issue 5: WAF blocking legitimate requests

**Symptoms:**
```bash
curl https://flowise-dev.do2506.click
# <html><body><h1>403 Forbidden</h1></body></html>
```

**Diagnosis:**
```bash
# Check WAF logs trong CloudWatch
aws logs tail /aws/wafv2/logs --follow

# Check WAF metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/WAFV2 \
  --metric-name BlockedRequests \
  --dimensions Name=WebACL,Value=my-eks-dev-waf \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum
```

**Solutions:**

**A. Temporarily disable WAF rule:**
```bash
# Get WAF Web ACL ID
aws wafv2 list-web-acls --scope REGIONAL --region us-east-1

# Update specific rule to COUNT instead of BLOCK
# (requires Terraform or AWS Console)
```

**B. Remove WAF annotation từ ingress:**
```bash
cd argocd/apps/flowise/overlays/dev
nano ingress.yaml

# Comment out hoặc remove line:
# alb.ingress.kubernetes.io/wafv2-acl-arn: ...

git add .
git commit -m "Temporarily disable WAF for troubleshooting"
git push

argocd app sync flowise-dev
```

**C. Whitelist IP address:**
```bash
# Add IP set rule trong WAF (via Terraform)
# See terraform-eks/modules/waf/main.tf
```

---

### Issue 6: DNS không resolve sau update

**Symptoms:**
```bash
nslookup flowise-dev.do2506.click
# Server:  8.8.8.8
# ** server can't find flowise-dev.do2506.click: NXDOMAIN
```

**Diagnosis:**
```bash
# Check Route53 hosted zone
aws route53 list-hosted-zones

# Check A record exists
aws route53 list-resource-record-sets \
  --hosted-zone-id <zone-id> \
  --query "ResourceRecordSets[?Name=='flowise-dev.do2506.click.']"

# Check ALB exists
aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[?contains(LoadBalancerName, `flowise`)]'
```

**Solutions:**

**A. Update DNS record:**
```bash
cd scripts
./update-flowise-dns.sh dev

# Verify sau 5 phút
nslookup flowise-dev.do2506.click
```

**B. Flush DNS cache:**
```bash
# Linux
sudo systemd-resolve --flush-caches

# macOS
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder

# Windows
ipconfig /flushdns
```

**C. Use ALB DNS directly:**
```bash
# Get ALB hostname
kubectl get ingress flowise-ingress -n flowise-dev -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Test với ALB hostname
curl -k https://<alb-hostname>
```

---

### Issue 7: Terraform state lock khi deploy infrastructure

**Symptoms:**
```bash
cd terraform-eks/environments/dev
terraform apply
# Error: Error acquiring the state lock
# Lock ID: 7646495c-e840-53cc-51ae-4645b0ce61c3
```

**Diagnosis:**
```bash
# Check DynamoDB lock table
aws dynamodb scan --table-name terraform-state-lock-dev

# Check when lock was created (timestamp)
```

**Solutions:**

**A. Wait cho lock expire (nếu process đang chạy):**
```bash
# Check nếu có terraform process đang chạy
ps aux | grep terraform

# Nếu có, chờ process complete
```

**B. Force unlock (nếu process đã bị interrupt):**
```bash
terraform force-unlock 7646495c-e840-53cc-51ae-4645b0ce61c3

# Confirm: yes

# Then retry
terraform apply
```

**C. Check S3 state file integrity:**
```bash
# List state versions
aws s3api list-object-versions \
  --bucket terraform-state-372836560690-dev \
  --prefix eks/terraform.tfstate

# Download current state
aws s3 cp s3://terraform-state-372836560690-dev/eks/terraform.tfstate .

# Verify JSON format
cat terraform.tfstate | jq .
```

---

## 💡 TIPS & BEST PRACTICES

### 1. Git Workflow với ArgoCD

**DO:**
- ✅ Always commit và push changes trước khi sync ArgoCD
- ✅ Use meaningful commit messages: `"Update Flowise to v1.2.3 - Add new env vars"`
- ✅ Create feature branches cho major changes: `git checkout -b feature/add-redis`
- ✅ Test changes trong dev trước khi merge to main

**DON'T:**
- ❌ Không edit resources directly với kubectl (ArgoCD sẽ revert)
- ❌ Không skip commit messages
- ❌ Không push secrets vào Git (use Secrets Manager hoặc Sealed Secrets)

---

### 2. ArgoCD Sync Strategies

**Auto-Sync (Recommended for Dev):**
```yaml
syncPolicy:
  automated:
    prune: true      # Delete resources not in Git
    selfHeal: true   # Auto-revert manual kubectl changes
```

**Manual Sync (Recommended for Prod):**
```yaml
syncPolicy: {}  # No automated sync, manual only
```

**Mixed Approach:**
```yaml
syncPolicy:
  automated:
    prune: false     # Keep manual resources
    selfHeal: true   # But fix drift
  syncOptions:
    - CreateNamespace=true
```

---

### 3. Resource Management

**Set proper limits:**
```yaml
resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

**Monitor usage:**
```bash
kubectl top pods -n flowise-dev
kubectl top nodes
```

**Scale applications:**
```bash
# Via kubectl (temporary - ArgoCD will revert)
kubectl scale deployment flowise-backend -n flowise-dev --replicas=3

# Via Git (permanent)
# Edit argocd/apps/flowise/overlays/dev/deployment.yaml
# replicas: 3
# Commit, push, ArgoCD syncs
```

---

### 4. Backup & Disaster Recovery

**Backup ArgoCD applications:**
```bash
# Export all applications
kubectl get applications -n argocd -o yaml > argocd-apps-backup.yaml

# Export all projects
kubectl get appprojects -n argocd -o yaml > argocd-projects-backup.yaml
```

**Backup Terraform state:**
```bash
# S3 versioning is enabled, but can download manually:
aws s3 cp s3://terraform-state-372836560690-dev/eks/terraform.tfstate \
  ./terraform.tfstate.backup-$(date +%Y%m%d)
```

**Backup Kubernetes resources:**
```bash
# Backup all resources trong namespace
kubectl get all -n flowise-dev -o yaml > flowise-backup.yaml

# Backup PVCs
kubectl get pvc -n flowise-dev -o yaml > flowise-pvcs-backup.yaml
```

**Restore:**
```bash
# Re-deploy ArgoCD
./bootstrap.sh

# Or apply backups
kubectl apply -f argocd-apps-backup.yaml
kubectl apply -f flowise-backup.yaml
```

---

### 5. Security Best Practices

**Secrets Management:**
```bash
# DON'T commit secrets to Git
# DO use Kubernetes Secrets
kubectl create secret generic db-password \
  -n flowise-dev \
  --from-literal=password=<secure-password>

# Or use AWS Secrets Manager + External Secrets Operator
# Or use Sealed Secrets (encrypted in Git)
```

**IAM Roles:**
```bash
# Use IRSA (IAM Roles for Service Accounts) instead of access keys
# Already configured for ALB Controller:
kubectl get sa aws-load-balancer-controller -n kube-system -o yaml
# Should have eks.amazonaws.com/role-arn annotation
```

**Network Policies:**
```yaml
# Restrict pod-to-pod communication
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: flowise-netpol
  namespace: flowise-dev
spec:
  podSelector:
    matchLabels:
      app: flowise-backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: flowise-frontend
    ports:
    - protocol: TCP
      port: 3000
```

---

### 6. Monitoring & Alerts

**Access Grafana:**
```bash
# URL: https://grafana-dev.do2506.click
# Username: admin
# Password: (get from secret)
kubectl get secret -n monitoring prometheus-grafana \
  -o jsonpath="{.data.admin-password}" | base64 --decode
```

**Useful Dashboards:**
- Kubernetes Cluster Monitoring
- Pod Resource Usage
- Ingress Traffic
- ArgoCD Application Health

**Set up alerts:**
```yaml
# In Prometheus AlertManager config
# See argocd/infrastructure/prometheus/base/alertmanager-config.yaml
```

---

## 📚 ADDITIONAL RESOURCES

### Documentation

- **ArgoCD:** https://argo-cd.readthedocs.io/
- **Terraform EKS:** [terraform-eks/README.md](../terraform-eks/README.md)
- **Project Architecture:** [argocd/docs/ARCHITECTURE.md](../argocd/docs/ARCHITECTURE.md)
- **ArgoCD Structure:** [docs/argocd/structure-overview.md](../docs/argocd/structure-overview.md)

### AWS Documentation

- **EKS Best Practices:** https://aws.github.io/aws-eks-best-practices/
- **ALB Controller:** https://kubernetes-sigs.github.io/aws-load-balancer-controller/
- **WAF v2:** https://docs.aws.amazon.com/waf/latest/developerguide/

### Tools

- **kubectl:** https://kubernetes.io/docs/reference/kubectl/
- **Helm:** https://helm.sh/docs/
- **ArgoCD CLI:** https://argo-cd.readthedocs.io/en/stable/cli_installation/
- **AWS CLI:** https://aws.amazon.com/cli/

---

## 🆘 GET HELP

### Check Script Logs

```bash
# Scripts có verbose output, check terminal history
# Hoặc redirect to file:
./bootstrap.sh 2>&1 | tee bootstrap.log
```

### Common Commands

```bash
# Cluster info
kubectl cluster-info
kubectl get nodes
kubectl get namespaces

# ArgoCD
argocd app list
argocd app get <app-name>
argocd app sync <app-name>
argocd app logs <app-name>

# Pods
kubectl get pods -A
kubectl logs <pod-name> -n <namespace>
kubectl describe pod <pod-name> -n <namespace>
kubectl exec -it <pod-name> -n <namespace> -- sh

# Ingress & ALB
kubectl get ingress -A
kubectl describe ingress <ingress-name> -n <namespace>
aws elbv2 describe-load-balancers

# DNS
nslookup <domain>
dig <domain> +short
```

### Contact

- **GitHub Issues:** https://github.com/TomJennyDev/devops/issues
- **Project Lead:** TomJennyDev

---

**Last Updated:** January 9, 2026
**Version:** 2.0
**Project:** GitOps EKS Deployment với ArgoCD + WAF + Flowise
