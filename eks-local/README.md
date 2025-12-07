# 🚀 EKS Local - Kubernetes Development Environment

## 📋 Tổng Quan

Môi trường Kubernetes local để phát triển và test ứng dụng mà **không cần AWS EKS thật** và **không dùng Terraform**.

## 🎯 Công Nghệ Sử dụng

### **Option 1: Kind (Kubernetes in Docker)** ⭐ Recommended
- Nhanh, nhẹ, giống EKS nhất
- Hỗ trợ multi-node cluster
- Dễ setup Ingress Controller

### **Option 2: Minikube**
- Phổ biến, nhiều tài liệu
- Hỗ trợ nhiều driver (Docker, VirtualBox, Hyper-V)
- Built-in addons

### **Option 3: k3d (k3s in Docker)**
- Siêu nhẹ, khởi động nhanh
- Tích hợp sẵn Load Balancer
- Phù hợp cho CI/CD

## 📦 Cài Đặt

### **Prerequisites**

```bash
# Install Docker Desktop
# Download: https://www.docker.com/products/docker-desktop

# Install kubectl
choco install kubernetes-cli

# Install Helm
choco install kubernetes-helm
```

### **Install Kind (Recommended)**

```bash
# Windows (PowerShell)
choco install kind

# Verify
kind version
```

### **Install Minikube (Alternative)**

```bash
# Windows (PowerShell)
choco install minikube

# Verify
minikube version
```

### **Install k3d (Alternative)**

```bash
# Windows (PowerShell)
choco install k3d

# Verify
k3d version
```

## 🚀 Quick Start

### **Sử dụng Scripts**

```bash
# 1. Tạo cluster
./scripts/create-cluster.sh

# 2. Setup Ingress Controller
./scripts/setup-ingress.sh

# 3. Deploy ArgoCD
./scripts/deploy-argocd.sh

# 4. Deploy sample app
./scripts/deploy-sample-app.sh

# 5. Verify
kubectl get nodes
kubectl get pods -A
```

### **Manual Setup**

```bash
# Create Kind cluster
kind create cluster --config kind-config.yaml --name dev-cluster

# Install NGINX Ingress
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Wait for ingress
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
```

## 📁 Cấu Trúc

```
eks-local/
├── README.md                    # This file
├── kind-config.yaml            # Kind cluster configuration
├── minikube-config.yaml        # Minikube configuration
├── k3d-config.yaml             # k3d configuration
├── manifests/                  # Kubernetes manifests
│   ├── ingress-nginx/
│   ├── argocd/
│   └── sample-apps/
├── scripts/                    # Setup scripts
│   ├── create-cluster.sh
│   ├── setup-ingress.sh
│   ├── deploy-argocd.sh
│   ├── deploy-sample-app.sh
│   └── cleanup.sh
└── docker-compose/             # Optional: Docker Compose setup
    └── docker-compose.yml
```

## 🔧 Cấu Hình

### **Kind Cluster với 3 nodes**
```yaml
# kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
      - containerPort: 443
        hostPort: 443
  - role: worker
  - role: worker
```

### **Minikube với Addons**
```bash
minikube start --nodes 3 --cpus 4 --memory 8192
minikube addons enable ingress
minikube addons enable metrics-server
```

### **k3d với Load Balancer**
```bash
k3d cluster create dev-cluster \
  --agents 2 \
  --port 8080:80@loadbalancer \
  --port 8443:443@loadbalancer
```

## 📊 So Sánh

| Tính Năng | Kind | Minikube | k3d |
|-----------|------|----------|-----|
| Tốc độ khởi động | ⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐ |
| Tài nguyên | Nhẹ | Trung bình | Rất nhẹ |
| Multi-node | ✅ | ✅ | ✅ |
| Giống EKS | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |
| Ingress | Manual | Built-in | Built-in |
| Load Balancer | MetalLB | Tunnel | Built-in |

## 🎯 Use Cases

### **Development**
```bash
# Quick test với k3d
k3d cluster create dev --agents 1
kubectl apply -f manifests/
```

### **Testing CI/CD**
```bash
# Kind với GitHub Actions config
kind create cluster --config kind-ci-config.yaml
```

### **Demo/Training**
```bash
# Minikube với dashboard
minikube start
minikube dashboard
```

## 🔄 Workflow Integration

### **ArgoCD Local**
```bash
# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Port forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Access: https://localhost:8080
```

### **Connect với GitOps Repo**
```bash
# Add repository
argocd repo add https://github.com/TomJennyDev/flowise-gitops.git

# Create application
argocd app create flowise-dev \
  --repo https://github.com/TomJennyDev/flowise-gitops.git \
  --path overlays/dev \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace flowise-dev
```

## 🐛 Troubleshooting

### **Port đã được sử dụng**
```bash
# Windows
netstat -ano | findstr :80
taskkill /PID <PID> /F
```

### **Docker không chạy**
```bash
# Restart Docker Desktop
# Settings → Resources → Reset to defaults
```

### **Cluster không khởi động**
```bash
# Kind
kind delete cluster --name dev-cluster
kind create cluster --name dev-cluster

# Minikube
minikube delete
minikube start

# k3d
k3d cluster delete dev-cluster
k3d cluster create dev-cluster
```

## 📚 Tài Liệu

- **Kind**: https://kind.sigs.k8s.io/
- **Minikube**: https://minikube.sigs.k8s.io/
- **k3d**: https://k3d.io/
- **kubectl**: https://kubernetes.io/docs/reference/kubectl/

## ✅ Next Steps

1. ✅ Chọn công nghệ (Kind/Minikube/k3d)
2. ✅ Tạo cluster local
3. ✅ Setup Ingress Controller
4. ✅ Deploy ArgoCD
5. ✅ Deploy sample application
6. ✅ Test workflow với GitOps repo

---

**💡 Tip:** Sử dụng Kind cho development, k3d cho CI/CD, Minikube cho demo/training.
