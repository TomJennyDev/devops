# Documentation

Complete guide for EKS + ArgoCD deployment.

## Quick Start

### 1. Deploy EKS with Terraform
📖 [TERRAFORM-DEPLOYMENT.md](./TERRAFORM-DEPLOYMENT.md)

Deploy infrastructure (~20 phút):
```bash
cd terraform-eks/environments/dev
terraform apply
```

### 2. Deploy ArgoCD
📖 [ARGOCD-DEPLOYMENT.md](./ARGOCD-DEPLOYMENT.md)

Deploy ArgoCD (~10 phút):
```bash
cd terraform-eks/scripts
./export-cluster-info.sh
./deploy-argocd.sh
```

### 3. Access & Deploy Apps

**ArgoCD URL:** https://argocd.do2506.click  
**Username:** admin  
**Password:** (from script output)

### 4. Setup GitHub Actions CI/CD
📖 [GITHUB-ACTIONS-ARGOCD.md](./GITHUB-ACTIONS-ARGOCD.md)

Integrate ArgoCD with GitHub Actions for automated deployments.

## Architecture

```
┌─────────────────────────────────────────────────┐
│                  AWS Cloud                       │
│  ┌───────────────────────────────────────────┐  │
│  │  VPC (10.0.0.0/16)                       │  │
│  │  ┌─────────────┐     ┌─────────────┐    │  │
│  │  │  Public     │     │  Private    │    │  │
│  │  │  Subnets    │────▶│  Subnets    │    │  │
│  │  │  (ALB)      │     │  (Nodes)    │    │  │
│  │  └─────────────┘     └─────────────┘    │  │
│  │         │                    │            │  │
│  │         │            ┌───────▼────────┐  │  │
│  │         │            │  EKS Cluster   │  │  │
│  │         │            │  - 2 Nodes     │  │  │
│  │         │            │  - t3.medium   │  │  │
│  │         │            └───────┬────────┘  │  │
│  │         │                    │            │  │
│  │  ┌──────▼──────┐    ┌────────▼────────┐ │  │
│  │  │    ALB      │    │    ArgoCD       │ │  │
│  │  │ (argocd.*)  │◀───│  (GitOps)       │ │  │
│  │  └─────────────┘    └─────────────────┘ │  │
│  └───────────────────────────────────────────┘  │
│                                                   │
│  ┌───────────────┐    ┌────────────────────┐   │
│  │ ECR Repos     │    │  Parameter Store   │   │
│  │ - flowise-*   │    │  - Cluster info    │   │
│  └───────────────┘    └────────────────────┘   │
└─────────────────────────────────────────────────┘
         │                         │
         │                         │
         ▼                         ▼
  ┌─────────────┐          ┌──────────────┐
  │   GitHub    │          │   Scripts    │
  │   (GitOps)  │          │   (Terraform)│
  └─────────────┘          └──────────────┘
```

## Resources

| Type | Quantity | Specs |
|------|----------|-------|
| VPC | 1 | 10.0.0.0/16 |
| Subnets | 4 | 2 public + 2 private |
| NAT Gateway | 1 | ap-southeast-1a |
| EKS Cluster | 1 | v1.34 |
| Worker Nodes | 2 | t3.medium |
| ECR Repos | 2 | flowise-server, flowise-ui |
| ALB | 1 | ArgoCD ingress |

## Costs

**Monthly estimate (dev):**
- EKS Control Plane: $73
- 2x t3.medium nodes: $60
- NAT Gateway: $32
- ALB: $16
- **Total: ~$181/month**

## Support

Need help? Check:
- [Terraform troubleshooting](./TERRAFORM-DEPLOYMENT.md#troubleshooting)
- [ArgoCD troubleshooting](./ARGOCD-DEPLOYMENT.md#troubleshooting)
