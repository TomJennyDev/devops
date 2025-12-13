# 📝 Configuration Variables - Quick Reference

> **Last Updated:** 2025-12-13  
> **Purpose:** Tổng hợp tất cả các biến cần thay đổi trước khi deploy

---

## 🔴 CRITICAL - PHẢI THAY ĐỔI

### 1. ArgoCD Values (`argocd-values.yaml`)

#### **Domain Configuration**
```yaml
# Line 16
global:
  domain: argocd.do2506.click  # ⚠️ THAY ĐỔI domain của bạn
```
- **Mục đích:** Domain chính cho ArgoCD UI
- **Cần thay đổi:** Nếu bạn có domain khác
- **Ví dụ:** `argocd.yourdomain.com`

#### **Repository URL**
```yaml
# Line 42-44
configs:
  repositories:
    devops:
      url: https://github.com/TomJennyDev/devops.git
      type: git
      name: devops
```
- **Mục đích:** Git repository chứa manifests
- **Hiện tại:** Public repo không cần credentials
- **Nếu private repo:** Thêm credentials qua ArgoCD CLI:
  ```bash
  argocd repo add https://github.com/YOUR-USERNAME/devops.git \
    --username <github-username> \
    --password <github-token>
  ```

#### **Admin Password**
```yaml
# Line 128
configs:
  secret:
    argocdServerAdminPassword: "123"
```
- **Mục đích:** Password cho admin user
- **⚠️ BẮT BUỘC đổi cho production!**
- **Hiện tại:** Default = `123` (dùng tạm cho dev)
- **Cách tạo secure password:**
  ```bash
  # Install htpasswd (Windows Git Bash)
  htpasswd -nbBC 10 "" YOUR_STRONG_PASSWORD | tr -d ':\n' | sed 's/$2y/$2a/'
  ```

#### **SSL Certificate ARN**
```yaml
# Line 170
server:
  ingress:
    annotations:
      alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:ap-southeast-1:372836560690:certificate/202c49bd-24b1-4513-a6dd-0379d106fe9a
```
- **Mục đích:** ACM certificate cho HTTPS
- **Hiện tại:** Certificate ARN đã có (issued)
- **Kiểm tra:** 
  ```bash
  aws acm describe-certificate \
    --certificate-arn arn:aws:acm:ap-southeast-1:372836560690:certificate/202c49bd-24b1-4513-a6dd-0379d106fe9a \
    --region ap-southeast-1
  ```
- **Nếu cần request mới:**
  ```bash
  aws acm request-certificate \
    --domain-name argocd.do2506.click \
    --validation-method DNS \
    --region ap-southeast-1
  ```

#### **Ingress Host**
```yaml
# Line 195
server:
  ingress:
    hosts:
      - argocd.do2506.click  # ⚠️ THAY ĐỔI

# Line 198-200
    tls:
      - secretName: argocd-tls
        hosts:
          - argocd.do2506.click
```
- **Mục đích:** Hostname cho ArgoCD UI
- **Phải khớp với:** Domain và certificate ARN ở trên

---

## 🟡 RECOMMENDED - NÊN THAY ĐỔI

### 2. Resource Limits

#### **Server Replicas**
```yaml
# Line 134
server:
  replicas: 2  # HA: 2 replicas
```
- **Hiện tại:** 2 replicas cho High Availability
- **Phù hợp với:** 2-node cluster (t3.medium)
- **Giảm xuống 1 nếu:** Chỉ có 1 node hoặc muốn tiết kiệm tài nguyên

#### **Repo Server Replicas**
```yaml
# Line 233
repoServer:
  replicas: 2
```
- **Hiện tại:** 2 replicas
- **Có thể giảm xuống 1 cho dev environment**

#### **Resource Requests/Limits**
```yaml
# Server (Line 204-210)
server:
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 250m
      memory: 256Mi

# Repo Server (Line 255-260)
repoServer:
  resources:
    limits:
      cpu: 1000m
      memory: 1Gi
    requests:
      cpu: 500m
      memory: 512Mi

# Controller (Line 288-293)
controller:
  resources:
    limits:
      cpu: 1500m
      memory: 2Gi
    requests:
      cpu: 1000m
      memory: 1Gi
```
- **Hiện tại:** Optimized cho 2-node t3.medium cluster
- **Tổng requests:** ~2.35 vCPU, ~3.4Gi memory
- **Cluster capacity:** 2 nodes × 2 vCPU × 4Gi = 4 vCPU, 8Gi total
- **Headroom:** ~40% còn lại cho workload apps

---

## 🟢 OPTIONAL - TÙY CHỌN

### 3. Monitoring & Metrics

```yaml
# Line 212-217, 263-268, 295-300
metrics:
  enabled: true
  serviceMonitor:
    enabled: true
    additionalLabels:
      release: prometheus
```
- **Mục đích:** Prometheus metrics scraping
- **Yêu cầu:** Prometheus Operator đã được cài
- **Set false nếu:** Không dùng Prometheus

### 4. Redis HA

```yaml
# Line 337
redis-ha:
  enabled: false  # Set to true for production high availability
```
- **Hiện tại:** Single Redis instance
- **Enable cho production:** High availability Redis cluster
- **Yêu cầu:** Ít nhất 3 nodes

### 5. Notifications

```yaml
# Line 377
notifications:
  enabled: false
```
- **Mục đích:** Slack/Email notifications
- **Enable nếu:** Muốn nhận thông báo về deployments
- **Ví dụ config:**
  ```yaml
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

## 📋 Flowise Application Configuration

### 6. Flowise Ingress - Dev Environment

**File:** `argocd/flowise/overlays/dev/ingress.yaml`

```yaml
# Line 15-17 (CHANGED: HTTPS disabled for dev)
# SSL/TLS configuration - DISABLED for dev (HTTP only)
# ⚠️ ENABLE HTTPS: Uncomment below lines after requesting ACM certificate
alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
```
- **Status:** ✅ HTTP-only cho dev testing
- **Certificate ARN:** Không cần cho dev
- **Access URL:** `http://flowise-dev.do2506.click`

### 7. Flowise Ingress - Staging/Production

**File:** `argocd/flowise/overlays/staging/ingress.yaml`  
**File:** `argocd/flowise/overlays/production/ingress.yaml`

```yaml
# Line 11-13
alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
alb.ingress.kubernetes.io/ssl-redirect: "443"
# ⚠️ TODO: Request ACM certificate and update ARN below
alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:ap-southeast-1:372836560690:certificate/YOUR-CERT-ARN
```
- **Status:** ⚠️ Cần request ACM certificate
- **Action required:**
  ```bash
  # Request certificate
  aws acm request-certificate \
    --domain-name flowise-staging.do2506.click \
    --validation-method DNS \
    --region ap-southeast-1
  
  # Add DNS validation record to Route53
  # Wait for validation (~5-30 minutes)
  # Update certificate ARN in ingress.yaml
  ```

---

## 🔧 AWS Load Balancer Controller

### 8. ALB Controller Values

**File:** `argocd/system-apps-kustomize/aws-load-balancer-controller/overlays/dev/values.yaml`

```yaml
# Line 3-5
clusterName: my-eks-dev
vpcId: vpc-0e6ca42c7851c46c4
region: ap-southeast-1

# Line 9-16
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::372836560690:role/my-eks-dev-aws-load-balancer-controller

# Line 18-19
iamRoleArn: arn:aws:iam::372836560690:role/my-eks-dev-aws-load-balancer-controller
awsAccountId: "372836560690"
```
- **Status:** ✅ Đã được auto-generate từ Terraform
- **Update script:** `scripts/update-alb-controller-config.sh dev`
- **Chạy khi:** Có thay đổi trong Terraform outputs

---

## 🚀 Deployment Checklist

### Pre-Deployment
- [ ] Đã chạy `terraform apply` thành công
- [ ] Cluster nodes đang Running (check: `kubectl get nodes`)
- [ ] Đã export Terraform outputs (`scripts/export-cluster-info.sh`)
- [ ] Đã update ALB Controller config (`scripts/update-alb-controller-config.sh dev`)
- [ ] Certificate ARN đã được validate (nếu dùng HTTPS)

### Deployment Order
1. [ ] **cert-manager** (required for ALB Controller)
   ```bash
   kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
   kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s
   ```

2. [ ] **ArgoCD** (GitOps platform)
   ```bash
   cd /d/devops/gitops/scripts
   bash deploy-argocd.sh
   ```

3. [ ] **AWS Load Balancer Controller** (via ArgoCD)
   ```bash
   kubectl apply -k argocd/system-apps-kustomize/aws-load-balancer-controller/overlays/dev/
   kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=aws-load-balancer-controller -n kube-system --timeout=300s
   ```

4. [ ] **Flowise Application** (after ALB Controller ready)
   ```bash
   kubectl apply -f argocd/applications/flowise-dev.yaml
   ```

### Post-Deployment
- [ ] ArgoCD UI accessible: `https://argocd.do2506.click` (hoặc `http://` nếu chưa có cert)
- [ ] Flowise UI accessible: `http://flowise-dev.do2506.click`
- [ ] Check ALB created in AWS Console
- [ ] Update Route53 DNS records pointing to ALB

---

## 📞 Quick Commands

```bash
# Check cluster status
kubectl get nodes
kubectl get pods -A

# Check ArgoCD
kubectl get pods -n argocd
kubectl get ingress -n argocd

# Check ALB Controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=50

# Check Flowise
kubectl get pods -n flowise-dev
kubectl get ingress -n flowise-dev

# Get ALB DNS
kubectl get ingress -A -o jsonpath='{.items[*].status.loadBalancer.ingress[0].hostname}'

# ArgoCD login
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Then: https://localhost:8080
# User: admin
# Pass: 123 (default, đổi sau!)
```

---

## 🔐 Security Notes

### ⚠️ QUAN TRỌNG - Production Security

1. **Đổi admin password ngay!**
   - Default password `123` CHỈ dùng cho dev
   - Generate secure password với htpasswd
   - Update `argocdServerAdminPassword` trong values.yaml

2. **Private repository credentials**
   - Nếu repo là private, add credentials vào ArgoCD
   - Dùng GitHub Personal Access Token
   - KHÔNG commit token vào Git

3. **Certificate management**
   - Dùng ACM certificate cho production
   - Enable SSL redirect
   - Set proper TLS policy (TLS 1.3)

4. **IAM roles**
   - ALB Controller role đã được Terraform tạo
   - Verify trust policy chỉ cho phép đúng ServiceAccount
   - Không hardcode AWS credentials

5. **Resource limits**
   - Set proper limits để prevent resource exhaustion
   - Monitor actual usage và adjust
   - Enable HPA (Horizontal Pod Autoscaler) cho production

---

## 📚 Related Documentation

- [ARCHITECTURE.md](../ARCHITECTURE.md) - Overall architecture
- [GETTING-STARTED.md](../GETTING-STARTED.md) - Step-by-step guide
- [IAM-ROLE-CREATION-FLOW.md](../../docs/IAM-ROLE-CREATION-FLOW.md) - IRSA mechanism
- [README.md](../system-apps-kustomize/aws-load-balancer-controller/README.md) - ALB Controller setup

---

**💡 Pro Tips:**

1. Luôn test trên dev environment trước
2. Dùng `kubectl diff` để preview changes trước khi apply
3. Enable ArgoCD auto-sync sau khi verify manually sync OK
4. Backup ArgoCD configuration: `argocd admin export`
5. Monitor logs khi deploy lần đầu để catch errors sớm
