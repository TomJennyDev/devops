# 🚀 Getting Started - ArgoCD Prometheus Stack

Hướng dẫn này dành cho **người mới bắt đầu** muốn deploy Prometheus + Grafana monitoring stack lên EKS cluster bằng ArgoCD.

## 📖 Đọc theo thứ tự này

### Bước 1: Hiểu cơ bản (15 phút đọc)

```
1. Đọc file này (GETTING-STARTED.md) ← BẠN ĐANG Ở ĐÂY
2. Đọc PROMETHEUS-README.md (overview về stack)
3. Đọc SOURCES.md (để biết nguồn tài liệu chính thức)
```

### Bước 2: Chuẩn bị môi trường (30 phút)

```
4. Cài đặt tools cần thiết
5. Verify cluster access
6. Deploy ArgoCD (nếu chưa có)
```

### Bước 3: Deploy monitoring stack (15 phút)

```
7. Deploy Prometheus + Grafana
8. Verify deployment
9. Access Grafana dashboard
```

---

## 🎯 Bước 1: Hiểu cơ bản

### Cấu trúc Repository

```
argocd/
├── 📘 GETTING-STARTED.md          ← File này - Bắt đầu từ đây
├── 📘 PROMETHEUS-README.md        ← Chi tiết về Prometheus stack
├── 📘 SOURCES.md                  ← Tài liệu tham khảo
│
├── 🎯 app-of-apps-kustomize-dev.yaml       ← DEPLOY FILE NÀY để cài dev
├── 🎯 app-of-apps-kustomize-staging.yaml   ← DEPLOY FILE NÀY để cài staging
├── 🎯 app-of-apps-kustomize-prod.yaml      ← DEPLOY FILE NÀY để cài prod
│
├── system-apps-kustomize/
│   └── prometheus/
│       ├── base/                  ← Template chung
│       │   ├── application.yaml   ← ArgoCD Application definition
│       │   └── kustomization.yaml
│       └── overlays/              ← Cấu hình theo môi trường
│           ├── dev/               ← Dev overrides
│           ├── staging/           ← Staging overrides
│           └── prod/              ← Prod overrides
│
└── helm-values/
    └── prometheus/
        ├── dev-values.yaml        ← Prometheus config cho Dev
        ├── staging-values.yaml    ← Prometheus config cho Staging
        ├── prod-values.yaml       ← Prometheus config cho Prod
        ├── default-values-reference.yaml  ← Full chart options (5000+ dòng)
        └── README.md              ← Hướng dẫn customize values
```

### Cách nó hoạt động (GitOps Flow)

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Bạn deploy app-of-apps-kustomize-dev.yaml               │
│    kubectl apply -f app-of-apps-kustomize-dev.yaml         │
└────────────────────────┬────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. ArgoCD đọc file và tạo Application                       │
│    - Trỏ đến: system-apps-kustomize/prometheus/overlays/dev│
└────────────────────────┬────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. Kustomize build từ base + dev overlay                   │
│    - Base: application.yaml template                        │
│    - Dev overlay: patch để dùng dev-values.yaml            │
└────────────────────────┬────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. ArgoCD tải Helm chart và apply dev-values.yaml          │
│    - Chart: prometheus-community/kube-prometheus-stack     │
│    - Values: helm-values/prometheus/dev-values.yaml        │
└────────────────────────┬────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ 5. Helm deploy vào cluster                                  │
│    - Prometheus Server (metrics collection)                │
│    - Grafana (dashboards)                                   │
│    - AlertManager (alerts)                                  │
│    - Node Exporter (node metrics)                           │
│    - Kube State Metrics (K8s metrics)                       │
└─────────────────────────────────────────────────────────────┘
```

---

## ⚙️ Bước 2: Chuẩn bị môi trường

### 2.1. Cài đặt tools cần thiết

```bash
# Kubectl (Kubernetes CLI)
# MacOS
brew install kubectl

# Windows
choco install kubernetes-cli

# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Verify
kubectl version --client
```

```bash
# ArgoCD CLI (Optional nhưng recommended)
# MacOS
brew install argocd

# Windows
choco install argocd-cli

# Linux
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd

# Verify
argocd version --client
```

```bash
# Git (để clone repo)
git --version
```

### 2.2. Verify cluster access

```bash
# Check kết nối tới EKS cluster
kubectl cluster-info

# Xem nodes
kubectl get nodes

# Kiểm tra namespaces
kubectl get namespaces
```

**Nếu không kết nối được:**

```bash
# Update kubeconfig cho EKS
aws eks update-kubeconfig --region ap-southeast-1 --name my-eks-dev
```

### 2.3. Deploy ArgoCD (nếu chưa có)

```bash
# Kiểm tra ArgoCD đã có chưa
kubectl get namespace argocd

# Nếu chưa có, cài ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Đợi ArgoCD ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Lấy admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
# Save password này!

# Port-forward để access ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Mở browser: https://localhost:8080
# Username: admin
# Password: (từ command trên)
```

---

## 🚀 Bước 3: Deploy Prometheus Stack

### 3.1. Clone repository

```bash
# Clone repo về máy
git clone https://github.com/TomJennyDev/devops.git
cd devops/argocd
```

### 3.2. Deploy cho Dev environment

```bash
# Deploy Prometheus + Grafana stack
kubectl apply -f app-of-apps-kustomize-dev.yaml

# Output:
# application.argoproj.io/system-apps-dev-kustomize created
```

### 3.3. Verify deployment

```bash
# Xem ArgoCD Application
kubectl get applications -n argocd

# Output mẫu:
# NAME                        SYNC STATUS   HEALTH STATUS
# system-apps-dev-kustomize   Synced        Healthy
# prometheus-dev              Synced        Progressing

# Xem pods trong monitoring namespace
kubectl get pods -n monitoring

# Output mẫu (sau vài phút):
# NAME                                                     READY   STATUS    RESTARTS
# prometheus-kube-prometheus-prometheus-0                  2/2     Running   0
# prometheus-grafana-xxx                                   3/3     Running   0
# prometheus-kube-state-metrics-xxx                        1/1     Running   0
# prometheus-prometheus-node-exporter-xxx                  1/1     Running   0
# alertmanager-prometheus-kube-prometheus-alertmanager-0   2/2     Running   0
```

**Nếu pods không ready:**

```bash
# Xem logs để debug
kubectl logs -n monitoring prometheus-kube-prometheus-prometheus-0 -c prometheus

# Xem events
kubectl get events -n monitoring --sort-by='.lastTimestamp'
```

### 3.4. Access Grafana

```bash
# Port-forward Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Mở browser: http://localhost:3000

# Login:
Username: admin
Password: admin123  # (Dev environment - xem file dev-values.yaml)
```

### 3.5. Explore Grafana Dashboards

1. **Kubernetes / Compute Resources / Cluster**
   - Xem tổng quan CPU/Memory của cluster

2. **Kubernetes / Compute Resources / Namespace (Pods)**
   - Xem resources theo namespace

3. **Kubernetes / Compute Resources / Pod**
   - Chi tiết từng pod

4. **Node Exporter / Nodes**
   - Metrics của worker nodes

---

## 📊 Bước 4: Test & Verify

### 4.1. Test Prometheus Query

```bash
# Port-forward Prometheus UI
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Mở browser: http://localhost:9090

# Thử query:
# 1. Container CPU usage:
rate(container_cpu_usage_seconds_total[5m])

# 2. Pod memory usage:
container_memory_usage_bytes{namespace="monitoring"}

# 3. Node CPU usage:
100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```

### 4.2. Test AlertManager

```bash
# Port-forward AlertManager
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-alertmanager 9093:9093

# Mở browser: http://localhost:9093

# Xem active alerts (nếu có)
```

### 4.3. Verify ArgoCD Sync

```bash
# ArgoCD CLI
argocd app list

# Xem chi tiết app
argocd app get prometheus-dev

# Xem sync history
argocd app history prometheus-dev
```

---

## 🔧 Bước 5: Customize (Optional)

### 5.1. Thay đổi Grafana password

```bash
# Edit file: argocd/helm-values/prometheus/dev-values.yaml

# Tìm dòng:
grafana:
  adminPassword: "admin123"  # ← Đổi password này

# Sau đó commit và push
git add argocd/helm-values/prometheus/dev-values.yaml
git commit -m "chore: Update Grafana password"
git push

# ArgoCD sẽ tự động sync (automated sync enabled)
```

### 5.2. Tăng retention

```bash
# Edit file: argocd/helm-values/prometheus/dev-values.yaml

# Tìm dòng:
prometheus:
  prometheusSpec:
    retention: 7d  # ← Đổi thành 15d hoặc 30d

# Commit và push như trên
```

### 5.3. Enable Ingress (expose Grafana ra ngoài)

```bash
# Edit file: argocd/helm-values/prometheus/dev-values.yaml

# Tìm section:
grafana:
  ingress:
    enabled: false  # ← Đổi thành true
    ingressClassName: alb  # Nếu dùng AWS ALB Controller
    hosts:
      - grafana-dev.example.com  # ← Đổi domain của bạn
```

---

## 🆘 Troubleshooting

### Vấn đề: Pods không start

```bash
# Check pod status
kubectl describe pod -n monitoring <pod-name>

# Xem logs
kubectl logs -n monitoring <pod-name>

# Common issues:
# 1. Insufficient resources → Tăng node capacity
# 2. Storage issues → Check PVC
# 3. Image pull issues → Check network/credentials
```

### Vấn đề: ArgoCD Application OutOfSync

```bash
# Hard refresh
argocd app get prometheus-dev --hard-refresh

# Manual sync
argocd app sync prometheus-dev

# Force sync (xóa và tạo lại)
argocd app sync prometheus-dev --force
```

### Vấn đề: Không access được Grafana

```bash
# Check service
kubectl get svc -n monitoring | grep grafana

# Check pods
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana

# Check logs
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana
```

### Vấn đề: Không có metrics trong Grafana

```bash
# Check Prometheus targets
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Mở: http://localhost:9090/targets
# Tất cả targets phải UP

# Check ServiceMonitors
kubectl get servicemonitors -n monitoring
```

---

## 📚 Học thêm

### Đọc tiếp theo

1. **PROMETHEUS-README.md**
   - Chi tiết về các components
   - Environment configurations
   - Common operations
   - Customization guide

2. **helm-values/prometheus/README.md**
   - Cách customize Helm values
   - Reference từ default-values-reference.yaml
   - Best practices

3. **SOURCES.md**
   - Tài liệu chính thức
   - API references
   - Best practices links

### Official Documentation

- **ArgoCD**: <https://argo-cd.readthedocs.io/en/stable/getting_started/>
- **Prometheus**: <https://prometheus.io/docs/prometheus/latest/getting_started/>
- **Grafana**: <https://grafana.com/docs/grafana/latest/getting-started/>
- **Kustomize**: <https://kubectl.docs.kubernetes.io/guides/introduction/kustomize/>

### Video Tutorials

- **ArgoCD Tutorial**: <https://www.youtube.com/results?search_query=argocd+tutorial>
- **Prometheus Monitoring**: <https://www.youtube.com/results?search_query=prometheus+kubernetes>
- **Grafana Dashboards**: <https://www.youtube.com/results?search_query=grafana+kubernetes+dashboard>

---

## ✅ Checklist hoàn thành

Sau khi làm xong guide này, bạn nên có:

- [ ] Tools đã cài đặt (kubectl, argocd CLI)
- [ ] Kết nối được tới EKS cluster
- [ ] ArgoCD đã deploy và access được
- [ ] Prometheus stack đã deploy thành công
- [ ] Access được Grafana dashboard
- [ ] Thấy metrics trong Prometheus
- [ ] Hiểu cấu trúc repository
- [ ] Biết cách customize values
- [ ] Biết cách troubleshoot cơ bản

---

## 🎓 Next Steps

### Deploy sang Staging/Prod

```bash
# Staging
kubectl apply -f app-of-apps-kustomize-staging.yaml

# Production (manual sync)
kubectl apply -f app-of-apps-kustomize-prod.yaml
argocd app sync system-apps-prod-kustomize  # Manual sync
```

### Thêm Custom Dashboards

1. Vào Grafana → Dashboards → Import
2. Paste Grafana dashboard ID từ: <https://grafana.com/grafana/dashboards/>
3. Recommended dashboards:
   - **1860** - Node Exporter Full
   - **6417** - Kubernetes Cluster Monitoring
   - **315** - Kubernetes Cluster Monitoring (via Prometheus)

### Setup Alerts

- Edit `alertmanager.config` trong values files
- Add Slack/Email receivers
- Test alerts

### Add More Applications

- Copy `prometheus/` structure
- Create new app folders
- Add to app-of-apps files

---

**Cần help?** Tham khảo:

- File PROMETHEUS-README.md (troubleshooting section)
- Official docs trong SOURCES.md
- GitHub issues của các projects

**Good luck! 🚀**
