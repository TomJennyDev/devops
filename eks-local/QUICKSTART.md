# 🚀 Quick Start Guide - EKS Local

## 📦 Prerequisites

```bash
# Install on Windows
choco install docker-desktop
choco install kubernetes-cli
choco install kubernetes-helm
choco install kind
```

## ⚡ Quick Setup (5 phút)

### **Bước 1: Tạo Cluster**
```bash
cd eks-local/scripts
bash create-cluster.sh
```

### **Bước 2: Setup Ingress**
```bash
bash setup-ingress.sh
```

### **Bước 3: Deploy ArgoCD**
```bash
bash deploy-argocd.sh
```

### **Bước 4: Deploy Sample App**
```bash
bash deploy-sample-app.sh
```

### **Bước 5: Access Applications**
```bash
# Add to hosts file (C:\Windows\System32\drivers\etc\hosts)
127.0.0.1 argocd.local
127.0.0.1 demo.local

# Access
# ArgoCD: https://argocd.local
# Demo App: http://demo.local
```

## 🎯 Use Cases

### **Development**
```bash
# Create cluster
./scripts/create-cluster.sh

# Deploy your app
kubectl apply -f your-manifests/

# Test with port-forward
kubectl port-forward svc/your-service 8080:80
```

### **Testing ArgoCD Workflow**
```bash
# Deploy ArgoCD
./scripts/deploy-argocd.sh

# Port forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Login (password from script output)
argocd login localhost:8080 --username admin --insecure

# Add repo
argocd repo add https://github.com/TomJennyDev/flowise-gitops.git

# Create app
argocd app create flowise-dev \
  --repo https://github.com/TomJennyDev/flowise-gitops.git \
  --path overlays/dev \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace flowise-dev \
  --sync-policy automated
```

### **CI/CD Testing**
```bash
# Create cluster for CI
kind create cluster --name ci-cluster

# Run your tests
kubectl apply -f test-manifests/
kubectl wait --for=condition=ready pod -l app=test

# Cleanup
kind delete cluster --name ci-cluster
```

## 🔧 Common Commands

```bash
# Cluster management
kind get clusters                # List clusters
kubectl config get-contexts      # List contexts
kubectl config use-context kind-dev-cluster  # Switch context

# Deploy & manage
kubectl apply -f manifest.yaml   # Deploy
kubectl get pods -A              # List all pods
kubectl logs -f pod-name         # View logs
kubectl describe pod pod-name    # Detailed info

# Port forwarding
kubectl port-forward svc/service-name 8080:80
kubectl port-forward pod/pod-name 8080:80

# Cleanup
./scripts/cleanup.sh             # Remove everything
kind delete cluster --name dev-cluster  # Just remove cluster
```

## 📊 Resource Requirements

| Setup | CPU | Memory | Disk |
|-------|-----|--------|------|
| Minimal (1 worker) | 2 cores | 4 GB | 20 GB |
| Standard (2 workers) | 4 cores | 8 GB | 30 GB |
| Full (3 workers + apps) | 6 cores | 12 GB | 50 GB |

## 🐛 Troubleshooting

### Cluster không khởi động
```bash
# Check Docker
docker info

# Delete and recreate
kind delete cluster --name dev-cluster
./scripts/create-cluster.sh
```

### Port 80/443 đã được dùng
```bash
# Windows: Find and kill process
netstat -ano | findstr :80
taskkill /PID <PID> /F
```

### Ingress không hoạt động
```bash
# Check ingress controller
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller

# Reinstall
kubectl delete namespace ingress-nginx
./scripts/setup-ingress.sh
```

## 🎓 Next Steps

1. ✅ Deploy sample apps
2. ✅ Test ArgoCD workflow
3. ✅ Deploy your real applications
4. ✅ Test CI/CD pipeline locally
5. ✅ Learn Kubernetes concepts

## 📚 Documentation

- [Kind Documentation](https://kind.sigs.k8s.io/docs/)
- [Kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [ArgoCD Getting Started](https://argo-cd.readthedocs.io/en/stable/getting_started/)

---

**💡 Tip:** Use this local environment for development and testing before deploying to AWS EKS!
