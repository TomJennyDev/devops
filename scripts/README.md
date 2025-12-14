# GitOps Deployment Scripts

Utility scripts for EKS cluster management and ArgoCD deployment with enterprise GitOps structure.

## 📋 Prerequisites

- AWS CLI configured
- kubectl installed
- Helm 3 installed
- Terraform (for cluster deployment)
- ArgoCD CLI (optional, for advanced operations)

## 🚀 Quick Start

### Complete Deployment Workflow

```bash
# 1. Export cluster information
bash scripts/export-cluster-info.sh

# 2. Deploy ArgoCD
bash scripts/deploy-argocd.sh

# 3. Update DNS records
bash scripts/update-dns-records.sh

# 4. Generate auth token
bash scripts/get-argocd-token.sh

# 5. Deploy ArgoCD Projects (RBAC)
bash scripts/deploy-projects.sh

# 6. Deploy Infrastructure Components
bash scripts/deploy-infrastructure.sh dev

# 7. Deploy Flowise Application
bash scripts/deploy-flowise.sh dev
```

---

## 📚 Scripts Documentation

### 1. `export-cluster-info.sh`

Export Terraform outputs to multiple formats for ArgoCD and other tools.

**Usage:**
```bash
bash scripts/export-cluster-info.sh
```

**Output Location:** `environments/dev/cluster-info/`

**Generated Files:**
- `terraform-outputs.json` - Raw Terraform outputs
- `cluster-info.yaml` - Structured cluster information
- `cluster-env.sh` - Environment variables
- `argocd-cluster-values.yaml` - Helm values for ArgoCD
- `cluster-info-configmap.yaml` - Kubernetes ConfigMap
- `README.md` - Quick reference

---

### 2. `deploy-argocd.sh`

Automated ArgoCD deployment on EKS cluster using Helm.

**Prerequisites:**
- Run `export-cluster-info.sh` first
- kubectl configured for EKS cluster
- Helm 3 installed

**Usage:**
```bash
bash scripts/deploy-argocd.sh
```

**What it does:**
1. Verify prerequisites (kubectl, helm)
2. Check/Install cert-manager
3. Create ArgoCD namespace
4. Deploy ArgoCD via Helm
5. Wait for all components to be ready
6. Retrieve admin credentials
7. Display next steps

**Output:**
- ArgoCD URL
- Admin credentials
- ALB DNS
- Next steps instructions

---

### 3. `update-dns-records.sh`

Update Route53 DNS records to point to ArgoCD ALB.

**Usage:**
```bash
bash scripts/update-dns-records.sh
```

**What it does:**
- Get ALB DNS from ArgoCD ingress
- Update Route53 A record (ALIAS)
- Verify DNS propagation

---

### 4. `get-argocd-token.sh`

Generate ArgoCD authentication token for API access and GitHub Actions.

**Usage:**
```bash
bash scripts/get-argocd-token.sh
source ~/.argocd-credentials.env
```

**Output:**
- `~/.argocd-credentials.env` - Environment variables file
- Exports: `ARGOCD_SERVER`, `ARGOCD_AUTH_TOKEN`

---

### 5. `deploy-projects.sh` ⭐ NEW

Deploy ArgoCD Projects for RBAC (must run after ArgoCD deployment).

**Usage:**
```bash
bash scripts/deploy-projects.sh
```

**What it does:**
1. Verify ArgoCD is installed
2. Deploy Infrastructure Project
3. Deploy Applications Project
4. Verify deployment

**Projects Created:**
- `infrastructure` - System components (ALB, Prometheus)
- `applications` - Business apps (Flowise)

---

### 6. `deploy-infrastructure.sh` ⭐ NEW

Deploy Infrastructure App-of-Apps (ALB Controller + Prometheus).

**Usage:**
```bash
bash scripts/deploy-infrastructure.sh [env]

# Examples:
bash scripts/deploy-infrastructure.sh dev
bash scripts/deploy-infrastructure.sh staging
bash scripts/deploy-infrastructure.sh prod
```

**What it deploys:**
- AWS Load Balancer Controller (kube-system namespace)
- Prometheus + Grafana Stack (monitoring namespace)

**Deployment time:** 5-10 minutes

---

### 7. `deploy-flowise.sh` ⭐ NEW

Deploy Flowise application to specific environment.

**Usage:**
```bash
bash scripts/deploy-flowise.sh [env]

# Examples:
bash scripts/deploy-flowise.sh dev
bash scripts/deploy-flowise.sh staging
bash scripts/deploy-flowise.sh production
```

**What it deploys:**
- Flowise Server (Backend API)
- Flowise UI (Frontend)
- PostgreSQL Database (PVC)
- Services (Server + UI)
- Ingress (ALB with HTTPS)

**Deployment time:** 5-10 minutes

---

### 8. `remove-argocd.sh` ⭐ NEW

Remove ArgoCD and all deployed resources completely.

**⚠️  WARNING:** This will delete all applications and data!

**Usage:**
```bash
bash scripts/remove-argocd.sh
```

**What it removes:**
- All ArgoCD applications
- ArgoCD Projects
- ArgoCD namespace
- Deployed applications (Flowise, Prometheus)
- Local credentials

**What it keeps:**
- EKS Cluster
- cert-manager (optional)
- ALB Controller (in kube-system)

---

### 9. `deploy-alb-controller.sh`

Deploy AWS Load Balancer Controller using Kustomize (legacy, use `deploy-infrastructure.sh` instead).

**Usage:**
```bash
bash scripts/deploy-alb-controller.sh
```

---

### 10. `update-alb-controller-config.sh`

Update ALB Controller configuration with cluster-specific values.

**Usage:**
```bash
bash scripts/update-alb-controller-config.sh [env]

# Example:
bash scripts/update-alb-controller-config.sh dev
```

---

## 🏗️ Directory Structure

```
scripts/
├── deploy-argocd.sh              # Deploy ArgoCD
├── deploy-projects.sh            # Deploy ArgoCD Projects (RBAC)
├── deploy-infrastructure.sh      # Deploy Infrastructure App-of-Apps
├── deploy-flowise.sh            # Deploy Flowise Application
├── remove-argocd.sh             # Remove ArgoCD completely
├── get-argocd-token.sh          # Generate auth token
├── update-dns-records.sh        # Update Route53 DNS
├── export-cluster-info.sh       # Export cluster info
├── deploy-alb-controller.sh     # Deploy ALB Controller (legacy)
├── update-alb-controller-config.sh  # Update ALB config
└── README.md                    # This file
```

---

## 🔄 Typical Workflows

### Initial Deployment

```bash
# 1. Deploy infrastructure
cd terraform-eks/environments/dev
terraform apply

# 2. Export cluster info
cd ../../scripts
bash export-cluster-info.sh

# 3. Deploy ArgoCD
bash deploy-argocd.sh

# 4. Configure DNS
bash update-dns-records.sh

# 5. Get auth token
bash get-argocd-token.sh

# 6. Deploy Projects (RBAC)
bash deploy-projects.sh

# 7. Deploy Infrastructure
bash deploy-infrastructure.sh dev

# 8. Deploy Flowise
bash deploy-flowise.sh dev
```

### Add New Application

```bash
# 1. Create application manifests in argocd/apps/
# 2. Create bootstrap file in argocd/bootstrap/
# 3. Deploy
kubectl apply -f argocd/bootstrap/myapp-dev.yaml
```

### Remove and Redeploy

```bash
# Remove everything
bash scripts/remove-argocd.sh

# Redeploy
bash scripts/deploy-argocd.sh
bash scripts/deploy-projects.sh
bash scripts/deploy-infrastructure.sh dev
bash scripts/deploy-flowise.sh dev
```

---

## 📁 Related Directories

```
argocd/
├── bootstrap/           # ArgoCD Applications
├── projects/           # ArgoCD Projects (RBAC)
├── infrastructure/     # Infrastructure components
├── apps/              # Business applications
├── config/            # Centralized configurations
└── docs/              # Documentation

environments/
└── dev/
    └── cluster-info/  # Exported cluster information

terraform-eks/         # EKS cluster Terraform code
```

---

## 🔍 Troubleshooting

### ArgoCD not accessible

```bash
# Check ingress
kubectl get ingress -n argocd

# Check ALB provisioning
kubectl describe ingress argocd-server -n argocd

# Check DNS
nslookup argocd.do2506.click
```

### Applications not syncing

```bash
# Check application status
kubectl get applications -n argocd
argocd app list

# Check logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller

# Manual sync
argocd app sync <app-name>
```

### Projects not found

```bash
# Check if projects exist
kubectl get appprojects -n argocd

# Redeploy projects
bash scripts/deploy-projects.sh
```

---

## 📚 Additional Resources

- **ArgoCD Documentation:** https://argo-cd.readthedocs.io/
- **Project Architecture:** `argocd/docs/ARCHITECTURE.md`
- **Getting Started:** `argocd/docs/GETTING-STARTED.md`
- **Configuration Guide:** `argocd/apps/flowise/CONFIGURATION-CHECKLIST.md`

---
```bash
cd terraform-eks/scripts
./test-environment.sh
```

### 4. `validate-all.sh`
Validate Terraform configuration before apply.

**Usage:**
```bash
cd terraform-eks/scripts
./validate-all.sh
```

### 5. `install-argocd.sh` (Deprecated)
Legacy ArgoCD installation script. Use `deploy-argocd.sh` instead.

## Typical Workflow

```bash
# 1. Apply Terraform infrastructure
cd terraform-eks/environments/dev
terraform apply

# 2. Export cluster information
cd ../../scripts
./export-cluster-info.sh

# 3. Deploy ArgoCD
./deploy-argocd.sh

# 4. Access ArgoCD
# URL and credentials displayed by deploy script
# Username: admin
# Password: <shown in output>
```

## Directory Structure

```
terraform-eks/
├── scripts/                          # ← You are here
│   ├── export-cluster-info.sh       # Export Terraform outputs
│   ├── deploy-argocd.sh            # Deploy ArgoCD
│   ├── test-environment.sh         # Test cluster
│   ├── validate-all.sh             # Validate Terraform
│   └── README.md                   # This file
└── environments/
    └── dev/
        ├── cluster-info/            # Generated by export-cluster-info.sh
        │   ├── terraform-outputs.json
        │   ├── cluster-info.yaml
        │   ├── cluster-env.sh
        │   └── ...
        ├── main.tf
        └── terraform.tfvars
```

## Environment Variables

Load cluster information into your shell:

```bash
source ../environments/dev/cluster-info/cluster-env.sh

# Available variables:
echo $EKS_CLUSTER_NAME
echo $EKS_REGION
echo $AWS_ACCOUNT_ID
echo $VPC_ID
echo $ECR_FLOWISE_SERVER
```

## Troubleshooting

### Script not found
```bash
# Make sure you're in the scripts directory
cd terraform-eks/scripts
```

### Permission denied
```bash
# Make scripts executable
chmod +x *.sh
```

### Cluster info not found
```bash
# Run export first
./export-cluster-info.sh

# Then deploy ArgoCD
./deploy-argocd.sh
```

### Cannot access cluster
```bash
# Configure kubectl
aws eks update-kubeconfig --region ap-southeast-1 --name my-eks-dev

# Verify
kubectl get nodes
```

## See Also

- [DEPLOY-ARGOCD-GUIDE.md](../environments/dev/DEPLOY-ARGOCD-GUIDE.md) - Detailed ArgoCD deployment guide
- [COREDNS-SLOW-CREATION-FIX.md](../../docs/COREDNS-SLOW-CREATION-FIX.md) - CoreDNS troubleshooting
- [ECR-SETUP-GUIDE.md](../../docs/ECR-SETUP-GUIDE.md) - ECR repository setup
