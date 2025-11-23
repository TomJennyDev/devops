# ArgoCD Applications for EKS

This directory contains ArgoCD Application manifests for deploying system components and applications to the EKS cluster.

## 📋 Architecture

```
Terraform (Infrastructure)
    ↓
    ↓ Creates EKS Cluster + IAM Roles
    ↓
ArgoCD (Application Deployment)
    ↓
    ├── System Apps (this folder)
    │   ├── AWS Load Balancer Controller
    │   ├── External DNS
    │   ├── Cert Manager
    │   └── Metrics Server
    │
    └── Your Applications
        ├── Backend Services
        ├── Frontend Apps
        └── Databases
```

## 🚀 Setup

### Step 1: Apply Terraform Infrastructure

```bash
cd environments/dev  # or staging/prod
terraform init
terraform apply
```

### Step 2: Install ArgoCD

```bash
# Configure kubectl
aws eks update-kubeconfig --region <region> --name <cluster-name>

# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Expose ArgoCD UI (LoadBalancer)
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Get ArgoCD URL
kubectl get svc argocd-server -n argocd
```

### Step 3: Deploy System Applications

```bash
# Deploy App-of-Apps (installs all system components)
kubectl apply -f argocd/app-of-apps.yaml

# Or deploy individual apps
kubectl apply -f argocd/system-apps/
```

## 📁 Directory Structure

```
argocd/
├── README.md                           # This file
├── app-of-apps.yaml                    # ArgoCD App-of-Apps pattern
└── system-apps/                        # System-level applications
    ├── aws-load-balancer-controller.yaml
    ├── external-dns.yaml
    └── metrics-server.yaml
```

## 🔧 System Applications

### 1. AWS Load Balancer Controller
- **Purpose**: Creates ALB/NLB for Kubernetes Ingress/Service
- **Required**: IAM role created by Terraform (IRSA)
- **Auto-sync**: Enabled
- **SSL/TLS**: Use AWS ACM certificates

### 2. Metrics Server
- **Purpose**: Required for HPA (Horizontal Pod Autoscaler)
- **Auto-sync**: Enabled

### 3. External DNS (Optional)
- **Purpose**: Automatically creates Route53 DNS records
- **Required**: IAM role for Route53 access
- **Auto-sync**: Enabled

## 💡 SSL/TLS Certificates

This setup uses **AWS Certificate Manager (ACM)** instead of cert-manager:

```yaml
# Ingress example with ACM certificate
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:region:account:certificate/xxx
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/ssl-redirect: '443'
spec:
  ingressClassName: alb
  rules:
    - host: example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-service
                port:
                  number: 80
```

## 🎯 Best Practices

### ✅ DO:
- Use ArgoCD for ALL application deployments
- Use App-of-Apps pattern for system components
- Enable auto-sync for system apps
- Use manual sync for production apps
- Store manifests in Git

### ❌ DON'T:
- Don't use Terraform for Helm charts
- Don't use `kubectl apply` directly
- Don't store secrets in Git (use Sealed Secrets/External Secrets)
- Don't deploy without PR review

## 📚 Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [App-of-Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
