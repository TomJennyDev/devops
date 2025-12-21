# KUBERNETES NAMESPACE ARCHITECTURE

> **Last Updated**: December 20, 2025  
> **Cluster**: EKS 1.34 on AWS (ap-southeast-1)  
> **Nodes**: 2× t3.large (2 vCPU, 8GB RAM each)

---

## 📊 NAMESPACE OVERVIEW

Dự án này có **7 namespaces chính**:

1. **kube-system** - Kubernetes system components
2. **argocd** - GitOps control plane
3. **monitoring** - Observability stack (Prometheus/Grafana)
4. **flowise-dev** - Flowise application (development)
5. **flowise-staging** - Flowise application (staging)
6. **flowise-production** - Flowise application (production)
7. **default** - Default namespace for testing

---

## 1️⃣ NAMESPACE: `kube-system`

**Purpose**: Kubernetes system components và AWS integrations

### Components:

| Component | Type | Pods | CPU Request | Memory Request | Description |
|-----------|------|------|-------------|----------------|-------------|
| **CoreDNS** | Deployment | 2 | 100m/pod | 70Mi/pod | Cluster DNS resolution |
| **kube-proxy** | DaemonSet | 2 (1/node) | 100m/pod | 128Mi/pod | Network proxy & iptables |
| **vpc-cni** | DaemonSet | 2 (1/node) | 25m/pod | 80Mi/pod | AWS VPC CNI plugin |
| **aws-node** | DaemonSet | 2 (1/node) | 25m/pod | 80Mi/pod | AWS networking daemon |
| **ebs-csi-node** | DaemonSet | 2 (1/node) | 50m/pod | 128Mi/pod | EBS volume driver |
| **ebs-csi-controller** | Deployment | 2 | 50m/pod | 128Mi/pod | EBS volume provisioner |
| **aws-load-balancer-controller** | Deployment | 2 | 100m/pod | 256Mi/pod | ALB/NLB management |

**Total Resources**:
- Pods: ~12
- CPU: ~550m
- Memory: ~1.2Gi

**Managed By**: Terraform (EKS addons + Helm)

---

## 2️⃣ NAMESPACE: `argocd`

**Purpose**: GitOps control plane for continuous deployment

### Components:

| Component | Type | Pods | CPU Request | Memory Request | Storage | Description |
|-----------|------|------|-------------|----------------|---------|-------------|
| **argocd-server** | Deployment | 2 | 250m/pod | 256Mi/pod | - | Web UI & API server |
| **argocd-repo-server** | Deployment | 2 | 250m/pod | 512Mi/pod | - | Git repository sync |
| **argocd-application-controller** | StatefulSet | 1 | 500m | 1Gi | - | App reconciliation |
| **argocd-dex-server** | Deployment | 1 | 50m | 64Mi | - | SSO/OAuth provider |
| **argocd-redis** | Deployment | 1 | 100m | 128Mi | - | Cache & session store |
| **argocd-applicationset-controller** | Deployment | 1 | 100m | 128Mi | - | ApplicationSet management |
| **argocd-notifications-controller** | Deployment | 1 | 100m | 128Mi | - | Notification delivery |

**Total Resources**:
- Pods: ~9
- CPU: ~1600m
- Memory: ~2.2Gi

**Resource Quotas** (Terraform):
- CPU Requests: 1500m
- Memory Requests: 2Gi
- CPU Limits: 3000m
- Memory Limits: 4Gi
- Max Pods: 30

**Access**:
- Domain: `argocd.do2506.click`
- Protocol: HTTPS (ALB + ACM certificate)

**Managed By**: Helm Chart + ArgoCD (self-managed)

---

## 3️⃣ NAMESPACE: `monitoring`

**Purpose**: Observability stack (metrics, visualization, alerting)

### Components:

| Component | Type | Pods | CPU Request | Memory Request | Storage | Description |
|-----------|------|------|-------------|----------------|---------|-------------|
| **prometheus-server** | StatefulSet | 1 | 200m | 512Mi | 20Gi PVC | Metrics collection & storage |
| **grafana** | Deployment | 1 | 100m | 256Mi | 10Gi PVC | Dashboards & visualization |
| **alertmanager** | StatefulSet | 1 | 50m | 128Mi | 5Gi PVC | Alert routing & silencing |
| **node-exporter** | DaemonSet | 2 (1/node) | 50m/pod | 64Mi/pod | - | Host metrics collector |
| **kube-state-metrics** | Deployment | 1 | 50m | 128Mi | - | K8s object metrics |
| **prometheus-operator** | Deployment | 1 | 100m | 256Mi | - | CRD operator |

**Total Resources**:
- Pods: ~7
- CPU: ~650m
- Memory: ~1.5Gi
- Storage: 35Gi (PVCs)

**Resource Quotas** (Terraform):
- CPU Requests: 800m
- Memory Requests: 2Gi
- CPU Limits: 1500m
- Memory Limits: 4Gi
- Max Pods: 30

**Prometheus Config**:
- Retention: 15 days
- Scrape Interval: 30s
- Storage: AWS EBS GP2

**Grafana**:
- Admin: admin/admin123 (⚠️ Change in production)
- Timezone: Asia/Singapore
- Default dashboards: Enabled

**Managed By**: Helm (kube-prometheus-stack) + ArgoCD

---

## 4️⃣ NAMESPACE: `flowise-dev`

**Purpose**: Flowise application - Development environment

### Components:

| Component | Type | Pods | CPU Request | Memory Request | Storage | Description |
|-----------|------|------|-------------|----------------|---------|-------------|
| **flowise-server** | Deployment | 2 | 200m/pod | 512Mi/pod | Shared PVC | Backend API (Node.js) |
| **flowise-ui** | Deployment | 2 | 100m/pod | 256Mi/pod | - | Frontend (React/Vite) |
| **flowise-storage** | PVC | - | - | - | 10Gi | Persistent storage |
| **flowise-ingress** | Ingress | - | - | - | - | ALB with WAF |
| **flowise-server-monitor** | ServiceMonitor | - | - | - | - | Prometheus metrics |

**Total Resources**:
- Pods: 4
- CPU: 600m
- Memory: 1.5Gi
- Storage: 10Gi

**Ingress Configuration**:
- Domain: `flowise-dev.do2506.click`
- ALB: `flowise-dev-alb`
- SSL/TLS: ACM certificate
- WAF: `my-eks-dev-dev-waf` (attached)
- Routes:
  - `/` → flowise-ui:80
  - `/api` → flowise-server:3000

**WAF Protection**:
- ✅ SQL Injection protection
- ✅ XSS protection
- ✅ OWASP Top 10
- ✅ Rate limiting (2000 req/5min)
- ✅ Known bad inputs
- ✅ Linux OS exploits

**Monitoring**:
- Metrics: `http://flowise-server:3000/api/v1/metrics`
- ServiceMonitor: Auto-discovered by Prometheus
- Scrape Interval: 30s

**Environment Variables**:
- Admin: admin/admin123 (⚠️ Change)
- JWT Secret: change-me-in-production (⚠️ Change)
- Database: SQLite (file-based)

**Managed By**: ArgoCD (GitOps)

---

## 5️⃣ NAMESPACE: `flowise-staging`

**Purpose**: Flowise application - Staging environment

### Components:

| Component | Type | Pods | CPU Request | Memory Request | Storage | Description |
|-----------|------|------|-------------|----------------|---------|-------------|
| **flowise-server** | Deployment | 2 | 200m/pod | 512Mi/pod | 10Gi PVC | Backend API |
| **flowise-ui** | Deployment | 2 | 100m/pod | 256Mi/pod | - | Frontend |
| **flowise-ingress** | Ingress | - | - | - | - | ALB with SSL |

**Total Resources**:
- Pods: 4
- CPU: 600m
- Memory: 1.5Gi
- Storage: 10Gi

**Ingress Configuration**:
- Domain: `flowise-staging.do2506.click`
- ALB: `flowise-staging-alb`

**Managed By**: ArgoCD (GitOps)

---

## 6️⃣ NAMESPACE: `flowise-production`

**Purpose**: Flowise application - Production environment

### Components:

| Component | Type | Pods | CPU Request | Memory Request | Storage | Description |
|-----------|------|------|-------------|----------------|---------|-------------|
| **flowise-server** | Deployment | 3 | 300m/pod | 1Gi/pod | 20Gi PVC | Backend API |
| **flowise-ui** | Deployment | 3 | 200m/pod | 512Mi/pod | - | Frontend |
| **flowise-ingress** | Ingress | - | - | - | - | ALB with SSL |

**Total Resources**:
- Pods: 6
- CPU: 1500m
- Memory: 4.5Gi
- Storage: 20Gi

**Ingress Configuration**:
- Domain: `flowise.do2506.click` or `flowise-prod.do2506.click`
- ALB: `flowise-prod-alb`

**Managed By**: ArgoCD (GitOps)

---

## 7️⃣ NAMESPACE: `default`

**Purpose**: Default namespace for ad-hoc testing and development

### Resource Quotas (Terraform):
- CPU Requests: 1000m
- Memory Requests: 2Gi
- CPU Limits: 2000m
- Memory Limits: 4Gi
- Max Pods: 30
- Storage: 50Gi

**Managed By**: Manual deployments / Testing

---

## 🏗️ WORKLOAD CLASSIFICATION

### **Node-level Components** (DaemonSet)
Chạy 1 pod trên mỗi node (2 pods total):

- `kube-proxy` (kube-system)
- `vpc-cni` / `aws-node` (kube-system)
- `ebs-csi-node` (kube-system)
- `node-exporter` (monitoring)

**Total**: 8 pods (4 types × 2 nodes)

---

### **Control Plane Components**
Kubernetes và infrastructure management:

- CoreDNS, EBS CSI Controller (kube-system)
- AWS Load Balancer Controller (kube-system)
- ArgoCD stack (argocd)
- Prometheus Operator (monitoring)

**Total**: ~20 pods

---

### **Application Workloads**
Business applications và observability:

- Flowise apps (dev/staging/prod)
- Prometheus Server, Grafana, AlertManager (monitoring)

**Total**: ~15-20 pods

---

## 📈 CLUSTER RESOURCE SUMMARY

### **Hardware Capacity**:
| Resource | Value |
|----------|-------|
| Nodes | 2× t3.large |
| Total vCPU | 4 cores |
| Total Memory | 16 GB |
| Instance Type | t3.large |
| Availability Zones | ap-southeast-1a, ap-southeast-1b |

### **Resource Allocation**:
| Metric | Value | % of Allocatable |
|--------|-------|------------------|
| **System Reserved** | ~800m CPU, ~2Gi RAM | - |
| **Allocatable** | ~3200m CPU, ~14Gi RAM | 100% |
| **Total Pods (Dev)** | ~36-40 pods | - |
| **CPU Requests** | ~5350m | 167% ⚠️ |
| **Memory Requests** | ~9.9Gi | 71% |
| **Total Storage (PVCs)** | ~125Gi EBS GP2 | - |

> ⚠️ **Note**: CPU overcommit ở 167% là chấp nhận được vì:
> - Không phải tất cả pods chạy đồng thời ở max capacity
> - Kubernetes scheduler sẽ evict pods khi cần
> - Dev environment không cần strict guarantees

### **Storage Breakdown**:
- Prometheus: 20Gi
- Grafana: 10Gi
- AlertManager: 5Gi
- Flowise Dev: 10Gi
- Flowise Staging: 10Gi
- Flowise Production: 20Gi
- Default namespace: Up to 50Gi
- **Total**: ~125Gi

---

## 🔐 SECURITY & NETWORKING

### **WAF (Web Application Firewall)**:
- **Scope**: REGIONAL (ap-southeast-1)
- **Attached to**: ALB (flowise-dev-alb)
- **Rules**:
  1. AWS Managed Core Rule Set (OWASP Top 10)
  2. Known Bad Inputs
  3. SQL Injection Protection
  4. Linux OS Protection
  5. Rate Limiting (2000 req/5min per IP)

### **Network Architecture**:
```
Internet
  ↓
WAF (ap-southeast-1)
  ↓
ALB (Application Load Balancer)
  ↓
Kubernetes Ingress
  ↓
Service (ClusterIP)
  ↓
Pods
```

### **SSL/TLS**:
- Certificate: ACM (AWS Certificate Manager)
- Domain: `*.do2506.click`
- Protocol: TLS 1.2+
- Redirect: HTTP → HTTPS (forced)

---

## 📊 MONITORING & OBSERVABILITY

### **Metrics Collection**:
- **Prometheus**: Collects metrics từ tất cả namespaces
- **ServiceMonitor**: Auto-discovery via Prometheus Operator
- **Exporters**:
  - Node Exporter (host metrics)
  - Kube State Metrics (K8s objects)
  - Flowise Server (application metrics)

### **Visualization**:
- **Grafana**: Pre-configured dashboards
- **Access**: Port-forward hoặc Ingress (nếu enabled)
- **Dashboards**:
  - Kubernetes cluster overview
  - Node metrics
  - Pod metrics
  - Application metrics

### **Alerting**:
- **AlertManager**: Routes alerts đến Slack/Email
- **Rules**: Prometheus alerting rules
- **Integration**: Webhook, SNS, PagerDuty

---

## 🚀 DEPLOYMENT WORKFLOW

### **GitOps Flow** (ArgoCD):
```
1. Developer push code → GitHub
2. ArgoCD detects changes
3. ArgoCD syncs Kubernetes manifests
4. Kubernetes creates/updates resources
5. Prometheus scrapes metrics
6. Grafana visualizes data
```

### **Namespace Creation Order**:
1. `kube-system` - Tự động (Kubernetes)
2. `argocd` - Terraform hoặc manual
3. `monitoring` - ArgoCD Application
4. `flowise-dev` - ArgoCD Application
5. `flowise-staging` - ArgoCD Application
6. `flowise-production` - ArgoCD Application

---

## 📝 RESOURCE LIMITS (Terraform Managed)

### **LimitRange** per Namespace:

| Namespace | Container CPU Default | Container Memory Default | Pod Max CPU | Pod Max Memory |
|-----------|----------------------|-------------------------|-------------|----------------|
| **default** | 100m-300m | 256Mi-512Mi | 2000m | 2Gi |
| **argocd** | 300m-800m | 512Mi-1Gi | 1500m | 2Gi |
| **monitoring** | 200m-500m | 512Mi-1Gi | 1000m | 2Gi |

### **ResourceQuota** per Namespace:

| Namespace | CPU Requests | Memory Requests | Max Pods | Storage |
|-----------|-------------|----------------|----------|---------|
| **default** | 1000m | 2Gi | 30 | 50Gi |
| **argocd** | 1500m | 2Gi | 30 | 30Gi |
| **monitoring** | 800m | 2Gi | 30 | 100Gi |

---

## 🎯 BEST PRACTICES

### **Resource Management**:
✅ Luôn set resource requests & limits  
✅ Sử dụng PodDisruptionBudgets cho HA  
✅ Enable horizontal pod autoscaling (HPA)  
✅ Monitor resource usage qua Grafana  

### **Security**:
✅ WAF enabled cho public endpoints  
✅ Network policies cho namespace isolation  
✅ RBAC cho access control  
✅ Secrets management (Kubernetes Secrets hoặc AWS Secrets Manager)  

### **High Availability**:
✅ Multiple replicas cho critical components  
✅ Pod anti-affinity để spread across nodes  
✅ Health checks (liveness/readiness probes)  
✅ PVCs với backup strategy  

### **Cost Optimization**:
✅ Single NAT Gateway (dev env)  
✅ t3.large instances (cost effective)  
✅ Spot instances cho non-critical workloads (staging)  
✅ Right-sizing resources based on actual usage  

---

## 🔧 MAINTENANCE

### **Scaling Nodes**:
```bash
# Update terraform.tfvars
node_group_desired_size = 3
node_group_min_size = 2
node_group_max_size = 5

# Apply
cd terraform-eks/environments/dev
terraform apply
```

### **Upgrading EKS**:
```bash
# Update cluster version in terraform.tfvars
cluster_version = "1.35"

# Apply (will trigger rolling update)
terraform apply
```

### **Backup Strategy**:
- **EBS Snapshots**: Daily snapshots của PVCs
- **Git Repository**: GitOps - all configs in Git
- **Secrets**: AWS Secrets Manager backup

---

## 📚 REFERENCES

- **Kubernetes Docs**: https://kubernetes.io/docs/
- **EKS Best Practices**: https://aws.github.io/aws-eks-best-practices/
- **ArgoCD**: https://argo-cd.readthedocs.io/
- **Prometheus**: https://prometheus.io/docs/
- **Grafana**: https://grafana.com/docs/

---

**Generated**: December 20, 2025  
**Cluster**: my-eks-dev  
**Region**: ap-southeast-1  
**Environment**: Development
