# FLOWISE CONFIGURATION VARIABLES CHECKLIST

## 📋 BIẾN CẦN THAY ĐỔI TRƯỚC KHI DEPLOY

### 🔴 CRITICAL - BẮT BUỘC THAY ĐỔI

#### 1. **Docker Images** (overlays/*/kustomization.yaml)

```yaml
images:
  - name: flowise-server:latest
    newName: <YOUR_ECR_URL>/flowise-server  # ⚠️ THAY ĐỔI
    newTag: v1.0.0                           # ⚠️ THAY ĐỔI
  - name: flowise-ui:latest
    newName: <YOUR_ECR_URL>/flowise-ui      # ⚠️ THAY ĐỔI
    newTag: v1.0.0                           # ⚠️ THAY ĐỔI
```

**Cách lấy ECR URL:**

```bash
# From Terraform output
terraform output ecr_flowise_server_url
terraform output ecr_flowise_ui_url

# Or from AWS CLI
aws ecr describe-repositories --repository-names flowise-server flowise-ui \
  --query 'repositories[*].repositoryUri' --output table
```

---

#### 2. **Admin Credentials** (overlays/*/deployment-patch.yaml)

```yaml
env:
  - name: FLOWISE_USERNAME
    value: "admin"  # ⚠️ THAY ĐỔI username

  - name: FLOWISE_PASSWORD
    value: "dev123"  # ⚠️ THAY ĐỔI password mạnh hơn
```

**Khuyến nghị:**

- Dev: Password đơn giản OK
- Production: Dùng Kubernetes Secret

```bash
kubectl create secret generic flowise-credentials \
  -n flowise-production \
  --from-literal=username=admin \
  --from-literal=password=$(openssl rand -base64 32)
```

---

#### 3. **Secret Key** (overlays/*/deployment-patch.yaml)

```yaml
env:
  - name: FLOWISE_SECRETKEY_OVERWRITE
    value: "dev-secret-key-change-in-prod"  # ⚠️ GENERATE NEW KEY
```

**Generate secret key:**

```bash
openssl rand -hex 32
# Output: abc123def456...
```

---

#### 4. **Domain Name** (overlays/*/ingress.yaml)

```yaml
spec:
  rules:
  - host: flowise-dev.do2506.click  # ⚠️ THAY ĐỔI domain
```

**Environments:**

- Dev: `flowise-dev.do2506.click`
- Staging: `flowise-staging.do2506.click`
- Production: `flowise.do2506.click`

**Sau khi deploy:**

```bash
# Create DNS record
cd scripts
bash update-dns-records.sh flowise-dev
```

---

### 🟡 RECOMMENDED - NÊN THAY ĐỔI

#### 5. **HTTPS/SSL Certificate** (overlays/production/ingress.yaml)

```yaml
annotations:
  # Uncomment for HTTPS
  alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
  alb.ingress.kubernetes.io/ssl-redirect: "443"
  alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:...:certificate/YOUR-CERT-ARN  # ⚠️ THAY ĐỔI
```

**Request ACM certificate:**

```bash
# Request certificate
aws acm request-certificate \
  --domain-name flowise.do2506.click \
  --validation-method DNS \
  --region ap-southeast-1

# Get certificate ARN
aws acm list-certificates --region ap-southeast-1 \
  --query 'CertificateSummaryList[?DomainName==`flowise.do2506.click`].CertificateArn' \
  --output text
```

---

#### 6. **GitHub Repository** (applications/flowise-*.yaml)

```yaml
spec:
  source:
    repoURL: https://github.com/TomJennyDev/devops.git  # ⚠️ THAY ĐỔI nếu fork
    targetRevision: main  # ⚠️ THAY ĐỔI branch nếu cần
```

---

#### 7. **Namespace** (applications/flowise-*.yaml)

```yaml
spec:
  destination:
    namespace: flowise-dev  # ⚠️ THAY ĐỔI theo environment
```

**Naming convention:**

- Dev: `flowise-dev`
- Staging: `flowise-staging`
- Production: `flowise-production`

---

#### 8. **Resources (CPU/Memory)** (overlays/*/deployment-patch.yaml)

```yaml
resources:
  requests:
    cpu: 100m      # ⚠️ Điều chỉnh theo workload
    memory: 256Mi  # ⚠️ Điều chỉnh theo workload
  limits:
    cpu: 500m
    memory: 512Mi
```

**Khuyến nghị:**

- Dev: Requests thấp (100m CPU, 256Mi RAM)
- Production: Requests cao hơn (500m CPU, 1Gi RAM)
- Monitor và adjust theo usage thực tế

---

### 🟢 OPTIONAL - TÙY CHỌN

#### 9. **Database Configuration** (base/deployment-server.yaml)

```yaml
env:
  # PostgreSQL configuration
  - name: DATABASE_TYPE
    value: "postgres"

  - name: DATABASE_HOST
    valueFrom:
      secretKeyRef:
        name: flowise-secrets  # ⚠️ Cần tạo Secret trước
        key: database-host

  - name: DATABASE_NAME
    value: "flowise"  # ⚠️ THAY ĐỔI database name
```

**Nếu dùng external database:**

1. Create RDS PostgreSQL instance
2. Create Kubernetes Secret:

```bash
kubectl create secret generic flowise-secrets \
  -n flowise-dev \
  --from-literal=database-host=<RDS_ENDPOINT> \
  --from-literal=database-user=flowise \
  --from-literal=database-password=<STRONG_PASSWORD>
```

---

#### 10. **Replicas** (overlays/*/deployment-patch.yaml)

```yaml
spec:
  replicas: 1  # ⚠️ THAY ĐỔI số replicas
```

**Khuyến nghị:**

- Dev: 1 replica
- Staging: 2 replicas
- Production: 3+ replicas (HA)

---

#### 11. **ALB Name & Tags** (overlays/*/ingress.yaml)

```yaml
annotations:
  alb.ingress.kubernetes.io/load-balancer-name: flowise-dev-alb  # ⚠️ THAY ĐỔI
  alb.ingress.kubernetes.io/tags: Environment=dev,Application=flowise  # ⚠️ THAY ĐỔI
```

---

## 📝 DEPLOYMENT CHECKLIST

### Before Deploy

- [ ] Update Docker image URLs in `kustomization.yaml`
- [ ] Change admin password in `deployment-patch.yaml`
- [ ] Generate new secret key
- [ ] Update domain name in `ingress.yaml`
- [ ] Request ACM certificate (for HTTPS)
- [ ] Create database secrets (if using external DB)
- [ ] Update GitHub repo URL (if forked)
- [ ] Adjust resource requests/limits

### Deploy Steps

```bash
# 1. Verify Kustomize build
kubectl kustomize argocd/flowise/overlays/dev

# 2. Deploy via ArgoCD
kubectl apply -f argocd/applications/flowise-dev.yaml

# 3. Monitor deployment
kubectl get pods -n flowise-dev -w

# 4. Create DNS record
cd scripts && bash update-dns-records.sh flowise-dev

# 5. Test access
curl http://flowise-dev.do2506.click
```

### After Deploy

- [ ] Verify pods are running
- [ ] Check ALB health checks
- [ ] Test DNS resolution
- [ ] Login to UI with admin credentials
- [ ] Configure GitHub repo in ArgoCD (if needed)
- [ ] Set up monitoring/alerts

---

## 🔧 QUICK COMMANDS

### Get all variables from cluster info

```bash
source environments/dev/cluster-info/cluster-env.sh
echo "Cluster: $EKS_CLUSTER_NAME"
echo "Region: $EKS_REGION"
echo "VPC: $VPC_ID"
```

### Generate secure passwords

```bash
# Password (32 chars)
openssl rand -base64 32

# Secret key (hex)
openssl rand -hex 32
```

### Check Flowise pods

```bash
kubectl get pods -n flowise-dev
kubectl logs -n flowise-dev -l app=flowise,component=server
kubectl logs -n flowise-dev -l app=flowise,component=ui
```

### Get ALB URL

```bash
kubectl get ingress -n flowise-dev flowise-ingress \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

---

## 🚨 SECURITY WARNINGS

1. **NEVER commit secrets to Git!**
   - Use Kubernetes Secrets
   - Use AWS Secrets Manager
   - Use .env files (gitignored)

2. **Always use HTTPS in Production**
   - Request ACM certificate
   - Enable SSL redirect
   - Use strong SSL policy

3. **Rotate credentials regularly**
   - Change admin password every 90 days
   - Rotate secret keys quarterly
   - Update database passwords

4. **Use strong passwords**
   - Minimum 16 characters
   - Mix of upper/lower/numbers/symbols
   - Use password manager

---

## 📚 REFERENCES

- [Flowise Documentation](https://docs.flowiseai.com/)
- [Kustomize Documentation](https://kustomize.io/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [AWS ALB Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
