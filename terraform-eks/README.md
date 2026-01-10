# EKS Terraform Configuration - Development Environment

Terraform configuration để deploy Amazon EKS cluster cho môi trường **Development** với GitOps pattern sử dụng ArgoCD (January 2026).

## 📋 Yêu cầu

- **Terraform**: >= 1.9.0
- **AWS CLI**: >= 2.x
- **kubectl**: >= 1.31
- **AWS Account** với quyền tạo EKS, VPC, IAM, WAF
- **S3 Bucket** cho Terraform state: `terraform-state-372836560690-dev`
- **DynamoDB Table** cho state locking: `terraform-state-lock-dev`
- **ArgoCD**: Deployed trong cluster để quản lý applications

## 🏗️ Kiến trúc GitOps - Development Environment

```
┌──────────────────────────────────────────────────────────────────────────┐
│                    EKS Development GitOps Architecture                    │
│         Terraform Infrastructure + ArgoCD + Prometheus + Flowise          │
└──────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│  LAYER 1: Infrastructure (Terraform)                                    │
├─────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌──────────────────┐  ┌────────────────────┐   │
│  │ VPC & Network   │  │  EKS Cluster     │  │  AWS Services      │   │
│  │ • Public (2 AZ) │  │  • K8s 1.31      │  │  • IAM (IRSA)      │   │
│  │ • Private (2 AZ)│  │  • VPC CNI       │  │  • Route53         │   │
│  │ • 1 NAT Gateway │  │  • CoreDNS       │  │  • ACM (SSL)       │   │
│  │ • Internet GW   │  │  • kube-proxy    │  │  • WAF (Active)    │   │
│  │ • 2 AZs         │  │  • 2-4 nodes     │  │  • S3 + DynamoDB   │   │
│  └─────────────────┘  └──────────────────┘  └────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────┐
│  LAYER 2: System Applications (ArgoCD Bootstrap)                       │
├─────────────────────────────────────────────────────────────────────────┤
│  Bootstrap Applications (App-of-Apps Pattern):                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │ infrastructure-apps-dev.yaml  → Manages infrastructure services  │  │
│  │ flowise-dev.yaml              → Manages Flowise application      │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  ┌──────────────────┐  ┌──────────────────┐  ┌─────────────────────┐ │
│  │ kube-system      │  │ monitoring       │  │ argocd              │ │
│  │ • AWS LB Ctrl    │  │ • Prometheus     │  │ • ArgoCD Server     │ │
│  │   (2 ALBs)       │  │ • Grafana        │  │ • App-of-Apps       │ │
│  │ • VPC CNI        │  │ • Alertmanager   │  │ • Auto Sync         │ │
│  │ • CoreDNS        │  │ • Node Exporter  │  │                     │ │
│  │                  │  │ • Kube State     │  │ Projects:           │ │
│  │ ALBs Created:    │  │                  │  │ - applications      │ │
│  │ 1. flowise-dev   │  │ Ingress:         │  │ - infrastructure    │ │
│  │ 2. monitoring    │  │ grafana-dev.     │  │                     │ │
│  │                  │  │ do2506.click     │  │                     │ │
│  └──────────────────┘  └──────────────────┘  └─────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────┐
│  LAYER 3: Business Applications (ArgoCD Managed)                       │
├─────────────────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────┐  ┌──────────────────────────────────┐  │
│  │ flowise-dev namespace    │  │ Future Applications              │  │
│  │ • Flowise UI (port 80)   │  │ • Your microservices             │  │
│  │ • Flowise Server (3000)  │  │ • Databases                      │  │
│  │ • Ingress + WAF          │  │ • Message queues                 │  │
│  │ • PVC Storage            │  │ • APIs                           │  │
│  │                          │  │                                  │  │
│  │ URL: flowise-dev.        │  │ Kustomize: base + overlays/dev   │  │
│  │      do2506.click        │  │                                  │  │
│  │                          │  │                                  │  │
│  │ WAF Protection:          │  │                                  │  │
│  │ • Rate limiting          │  │                                  │  │
│  │ • SQL injection block    │  │                                  │  │
│  │ • XSS prevention         │  │                                  │  │
│  └──────────────────────────┘  └──────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│  Traffic Flow                                                            │
├─────────────────────────────────────────────────────────────────────────┤
│  User → Route53 → WAF (Block/Allow) → ALB → Ingress → Service → Pods  │
│         DNS        Security Layer      L7 LB   K8s      ClusterIP       │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│  State Management                                                        │
├─────────────────────────────────────────────────────────────────────────┤
│  S3: terraform-state-372836560690-dev/eks/terraform.tfstate (21.6 KB)  │
│  DynamoDB: terraform-state-lock-dev (State locking)                    │
│  Git: argocd/ directory (Application manifests - GitOps)               │
└─────────────────────────────────────────────────────────────────────────┘
```

**Architecture Highlights:**

🔹 **Layer 1 - Infrastructure (Terraform):**

- 2 Availability Zones deployment
- 1 NAT Gateway (cost-optimized for dev)
- EKS Cluster v1.31 with managed node groups
- Complete AWS integration (IAM IRSA, Route53, ACM, WAF)
- S3 backend với DynamoDB locking cho state management
- WAF Web ACL protecting all ALBs

🔹 **Layer 2 - System Apps (ArgoCD Bootstrap):**

- **ArgoCD**: GitOps continuous deployment với App-of-Apps pattern
- **AWS Load Balancer Controller**: Tạo 2 ALBs (flowise-dev, monitoring)
- **Prometheus Stack**: Complete monitoring solution
  - Grafana dashboards với ingress
  - Prometheus metrics collection
  - Alertmanager notifications
  - Node & Kube State metrics exporters

🔹 **Layer 3 - Business Apps (ArgoCD Managed):**

- **Flowise**: AI Chatbot application
  - UI service (port 80) + Server (port 3000)
  - Kustomize base + dev overlay
  - WAF protection + SSL certificate
  - Ingress: flowise-dev.do2506.click

🔹 **Security Layer:**

- **AWS WAF v2**: Active protection
  - Rate limiting (requests per IP)
  - SQL injection prevention
  - XSS attack blocking
  - Associated with both ALBs

**DNS & SSL Architecture:**

- **CoreDNS**: Built-in EKS addon cho internal cluster DNS (service discovery)
- **Route53**: Manual DNS records cho external access
- **AWS ACM**: SSL/TLS certificate management (no cert-manager needed)

## 🏗️ Cấu trúc Project

```
terraform-eks/
├── environments/
│   └── dev/                 # Development environment (~$140/month)
│       ├── backend.tf       # S3 backend configuration
│       ├── main.tf          # Main infrastructure  
│       ├── variables.tf     # Variable definitions
│       ├── terraform.tfvars # Dev-specific values
│       └── outputs.tf       # Output values
├── modules/                 # Reusable infrastructure modules
│   ├── vpc/                # VPC, subnets, NAT, IGW (2 AZs)
│   ├── iam/                # IAM roles and policies
│   ├── security-groups/    # Security groups
│   ├── eks/                # EKS cluster and addons
│   ├── node-groups/        # Managed node groups (2-4 nodes)
│   ├── alb-controller/     # ALB Controller IAM (IRSA)
│   └── waf/                # WAF Web ACL configuration
├── outputs.tf              # Root-level outputs
└── README.md               # This file
```

### VPC Architecture (Dev Environment)

```
VPC (10.0.0.0/16)
├── Public Subnets (2 AZs)
│   ├── 10.0.1.0/24 (ap-southeast-1a) - NAT Gateway here
│   └── 10.0.2.0/24 (ap-southeast-1b)
├── Private Subnets (2 AZs)
│   ├── 10.0.11.0/24 (Worker Nodes)
│   └── 10.0.12.0/24 (Worker Nodes)
├── Internet Gateway
├── 1x NAT Gateway (cost-optimized)
├── EKS Cluster (Kubernetes 1.31)
└── WAF Web ACL (protecting 2 ALBs)
```

## 📦 Tính năng

- ✅ **EKS 1.31** - Stable Kubernetes version
- ✅ **AWS Provider 5.100** - Latest features support
- ✅ **S3 Backend** - Remote state với S3 + DynamoDB locking
- ✅ **Cost Optimized** - 1 NAT Gateway, t3.large nodes
- ✅ **High Availability** - 2 AZ deployment, 2-4 nodes
- ✅ **Amazon Linux 2023** - Latest AMI with long-term support
- ✅ **EKS Addons** - VPC CNI v1.18.5, CoreDNS v1.11.3, kube-proxy v1.31.0
- ✅ **IRSA Support** - IAM Roles for Service Accounts
- ✅ **ALB Controller** - 2 ALBs (flowise-dev, monitoring)
- ✅ **AWS WAF** - Web Application Firewall protection
- ✅ **AWS ACM** - SSL/TLS certificate management
- ✅ **GitOps Ready** - ArgoCD với App-of-Apps pattern
- ✅ **Monitoring Stack** - Prometheus + Grafana deployed
- ✅ **CloudWatch Logging** - 7 days retention
- ✅ **Security Hardened** - Separated security groups, WAF protection

## 🚀 Quick Start

### Prerequisites Check

```bash
# Check AWS CLI
aws --version
aws sts get-caller-identity

# Check Terraform
terraform version  # Should be >= 1.9.0

# Check kubectl
kubectl version --client
```

## 📝 Deployment Guide

### 🔧 Step 1: Chuẩn bị AWS Backend

```bash
# Create S3 bucket for state
aws s3api create-bucket \
  --bucket terraform-state-372836560690-dev \
  --region ap-southeast-1 \
  --create-bucket-configuration LocationConstraint=ap-southeast-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket terraform-state-372836560690-dev \
  --versioning-configuration Status=Enabled

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-state-lock-dev \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ap-southeast-1
```

### 🌱 Step 2: Deploy Infrastructure

```bash
cd environments/dev

# Review configuration
cat terraform.tfvars
cat backend.tf

# Initialize Terraform
terraform init

# Review what will be created (~50 resources)
terraform plan

# Deploy infrastructure (takes ~15-20 minutes)
terraform apply

# Configure kubectl
aws eks update-kubeconfig --name my-eks-dev --region ap-southeast-1

# Verify cluster
kubectl get nodes
kubectl get pods -A
```

**Được tạo:**
- ✅ VPC với 2 AZs, 1 NAT Gateway
- ✅ EKS Cluster v1.31 với 2 worker nodes
- ✅ IAM roles với IRSA support
- ✅ Security groups
- ✅ WAF Web ACL
- ✅ CloudWatch log groups

**Outputs quan trọng:**
```bash
terraform output cluster_endpoint
terraform output waf_web_acl_arn
terraform output aws_load_balancer_controller_role_arn
```

## 📊 Outputs

Sau khi deploy xong, check outputs:

```bash
# All outputs
terraform output

# Specific outputs
terraform output cluster_endpoint
terraform output waf_web_acl_arn
terraform output aws_load_balancer_controller_role_arn

# Configure kubectl command
terraform output configure_kubectl
```

**Key outputs:**
- `cluster_endpoint` - EKS API server endpoint
- `cluster_name` - my-eks-dev
- `waf_web_acl_arn` - ARN của WAF (dùng trong Ingress)
- `aws_load_balancer_controller_role_arn` - IAM role cho ALB Controller
- `vpc_id` - VPC ID
- `oidc_provider_arn` - OIDC provider (cho IRSA)

## 💰 Chi phí Development Environment

| Component | Configuration | Monthly Cost |
|-----------|---------------|--------------|
| **EKS Control Plane** | 1 cluster | $73 |
| **EC2 Worker Nodes** | 2x t3.large (ON_DEMAND) | $60 |
| **NAT Gateway** | 1x NAT + Data transfer | $35 |
| **EBS Storage** | ~50GB gp3 | $5 |
| **CloudWatch Logs** | 7 days retention | $2 |
| **WAF** | Web ACL + Rules | $10 |
| **Data Transfer** | Egress | $5 |
| **Total** | | **~$190/month** |

💡 **Cost Optimization Tips:**

- ✅ Sử dụng 1 NAT Gateway thay vì 3: Tiết kiệm $70/month
- ✅ Stop cluster ngoài giờ: Tiết kiệm ~40% ($70-80/month)
- ⚠️ SPOT instances: Tiết kiệm 70% nodes cost nhưng có thể bị interrupt
- ⚠️ ARM/Graviton (t4g): Tiết kiệm 20% nhưng cần test compatibility

## 🔧 Configuration

Chỉnh sửa `environments/dev/terraform.tfvars`:

### Node Scaling

```hcl
node_min_size     = 2   # Minimum nodes
node_desired_size = 2   # Desired nodes
node_max_size     = 4   # Maximum nodes (auto-scaling)
```

### Instance Types

```hcl
node_group_instance_types = ["t3.large"]  # Or ["t3.medium", "t3.large"] for mixed
```

### High Availability NAT

```hcl
nat_gateway_count = 2  # Tăng HA, thêm ~$35/month per NAT
```

### API Access Restriction

```hcl
cluster_endpoint_public_access_cidrs = ["1.2.3.4/32"]  # Your office IP only
```

## 🔧 Post-Deployment: Install System Applications

### Bootstrap với ArgoCD

```bash
# 1. Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 2. Wait for ArgoCD ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# 3. Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

# 4. Port forward ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# 5. Login: https://localhost:8080
# Username: admin
# Password: (from step 3)

# 6. Deploy ArgoCD Projects
kubectl apply -f ../argocd/projects/applications.yaml
kubectl apply -f ../argocd/projects/infrastructure.yaml

# 7. Bootstrap system apps (App-of-Apps pattern)
kubectl apply -f ../argocd/bootstrap/infrastructure-apps-dev.yaml
kubectl apply -f ../argocd/bootstrap/flowise-dev.yaml

# ArgoCD sẽ tự động deploy:
# ✓ AWS Load Balancer Controller → Tạo 2 ALBs
# ✓ Prometheus + Grafana → Monitoring stack
# ✓ Flowise Application → AI Chatbot
```

**Kiểm tra deployment:**

```bash
# Check ArgoCD applications
kubectl get applications -n argocd

# Check ALBs được tạo
kubectl get ingress -A

# Check pods
kubectl get pods -n kube-system      # ALB Controller
kubectl get pods -n monitoring       # Prometheus, Grafana
kubectl get pods -n flowise-dev      # Flowise app
```

**Update DNS records:**

```bash
# Get ALB hostnames
kubectl get ingress -A -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.loadBalancer.ingress[0].hostname}{"\n"}{end}'

# Update DNS với scripts
cd ../scripts
./update-flowise-dns.sh dev
./update-monitoring-dns.sh
```

**Deployed URLs:**
- 🎯 Flowise: https://flowise-dev.do2506.click
- 📊 Grafana: https://grafana-dev.do2506.click
- 🔍 Prometheus: https://prometheus-dev.do2506.click

📖 **Chi tiết:** [../argocd/README.md](../argocd/README.md)

## 🏗️ Architecture Layers

This project follows the **GitOps separation of concerns** pattern:

### Layer 1: Infrastructure (This Repository)

- **Managed by**: Terraform
- **Contains**: VPC, EKS, IAM, Security Groups
- **Change Frequency**: Low (weeks/months)
- **Team**: Platform/DevOps

### Layer 2: System Applications

- **Managed by**: ArgoCD (see `../argocd/` folder)
- **Contains**:
  - AWS Load Balancer Controller (ALB/NLB ingress)
  - Prometheus + Grafana (monitoring stack)
  - External DNS (optional - Route53 automation)
- **Change Frequency**: Medium (days/weeks)
- **Team**: Platform/SRE

### Layer 3: Business Applications

- **Managed by**: ArgoCD (separate repository)
- **Contains**: Your microservices, databases, APIs
- **Change Frequency**: High (daily/hourly)
- **Team**: Development teams

**Why this separation?**

- ✅ Clear ownership and responsibilities
- ✅ Independent lifecycles and rollback
- ✅ Reduced blast radius
- ✅ Better CI/CD pipelines
- ✅ Easier troubleshooting

## 🔐 Security Best Practices

### ✅ Implemented

- [x] Private subnets for worker nodes
- [x] Security groups with least privilege
- [x] IRSA (IAM Roles for Service Accounts)
- [x] Encrypted CloudWatch logs
- [x] SSH disabled in production
- [x] Public API with CIDR restrictions

### 🎯 Recommended Next Steps

1. Enable Pod Security Standards
2. Setup Network Policies
3. Enable AWS Secrets Manager integration
4. Setup monitoring (Prometheus/Grafana)
5. Configure backup strategy (Velero)

## 🧹 Cleanup

### Step 1: Clean Kubernetes Resources

```bash
# Delete ArgoCD applications (will cascade delete all apps)
kubectl delete application -n argocd --all

# Wait for resources to be cleaned up
kubectl wait --for=delete application/infrastructure-apps-dev -n argocd --timeout=300s
kubectl wait --for=delete application/flowise-dev -n argocd --timeout=300s

# Verify ALBs are deleted
kubectl get ingress -A
aws elbv2 describe-load-balancers --query 'LoadBalancers[?starts_with(LoadBalancerName, `k8s-`)].LoadBalancerName'
```

### Step 2: Destroy Terraform

```bash
cd environments/dev

# Review what will be destroyed
terraform plan -destroy

# Destroy infrastructure
terraform destroy

# Confirm: yes
```

⏱️ Destruction takes ~10-15 minutes

### Step 3: Clean Backend (Optional)

```bash
# Delete S3 state bucket
aws s3 rm s3://terraform-state-372836560690-dev --recursive
aws s3api delete-bucket --bucket terraform-state-372836560690-dev

# Delete DynamoDB lock table
aws dynamodb delete-table --table-name terraform-state-lock-dev
```

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [README.md](README.md) | This file - Quick start guide |
| [../argocd/README.md](../argocd/README.md) | ArgoCD setup and GitOps patterns |
| [../argocd/docs/](../argocd/docs/) | ArgoCD architecture documentation |
| [modules/vpc/README.md](modules/vpc/README.md) | VPC module details |
| [modules/waf/README.md](modules/waf/README.md) | WAF configuration |
| [STRUCTURE-EXPLAINED.md](STRUCTURE-EXPLAINED.md) | Terraform structure explained |

## 🔧 Tùy chỉnh (Per Environment)

Edit `terraform.tfvars` in each environment directory:

### High Availability NAT Gateway

```hcl
nat_gateway_count = 3  # Tăng chi phí thêm ~$64/month
```

### Scaling Node Group

```hcl
node_min_size     = 2
node_desired_size = 3
node_max_size     = 10
```

### Mixed Instance Types

```hcl
node_group_instance_types = ["t3.medium", "t3.large"]
```

### Restrict API Access

```hcl
cluster_endpoint_public_access_cidrs = ["1.2.3.4/32"]  # Your office IP
```

## 🐛 Troubleshooting

### Terraform State Lock Error

```bash
# Error: State is locked
# Solution: Force unlock
terraform force-unlock <LOCK_ID>

# Check lock in DynamoDB
aws dynamodb get-item \
  --table-name terraform-state-lock-dev \
  --key '{"LockID":{"S":"terraform-state-372836560690-dev/eks/terraform.tfstate-md5"}}'
```

### WAF ARN Error in Ingress

```bash
# Error: WAF doesn't exist
# Get correct WAF ARN from Terraform
terraform output -raw waf_web_acl_arn

# Update ingress annotation
kubectl edit ingress flowise-ingress -n flowise-dev
# Update: alb.ingress.kubernetes.io/wafv2-acl-arn
```

### ALB Not Created

```bash
# Check ALB Controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Check Ingress events
kubectl describe ingress <ingress-name> -n <namespace>

# Verify IAM role
kubectl get sa aws-load-balancer-controller -n kube-system -o yaml
```

### Nodes Not Joining Cluster

```bash
# Check node status
kubectl get nodes

# Check node group
aws eks describe-nodegroup \
  --cluster-name my-eks-dev \
  --nodegroup-name general

# Check security groups
aws ec2 describe-security-groups \
  --filters "Name=tag:Name,Values=*eks*"
```

### DNS Not Resolving

```bash
# Check Route53 records
aws route53 list-resource-record-sets \
  --hosted-zone-id Z08819302E9BMC6AAR2OJ \
  --query "ResourceRecordSets[?Name=='flowise-dev.do2506.click.']"

# Test DNS
nslookup flowise-dev.do2506.click
dig flowise-dev.do2506.click

# Get ALB hostname
kubectl get ingress -n flowise-dev -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

## 🔗 Useful Commands

### Cluster Management

```bash
# Configure kubectl
aws eks update-kubeconfig --name my-eks-dev --region ap-southeast-1

# Check cluster info
kubectl cluster-info
kubectl get nodes
kubectl get pods -A

# Get cluster version
kubectl version
```

### ArgoCD Management

```bash
# List applications
kubectl get applications -n argocd

# Sync application
kubectl patch application <app-name> -n argocd \
  --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

# Check app status
kubectl get application flowise-dev -n argocd -o yaml
```

### ALB & Ingress

```bash
# List ingresses
kubectl get ingress -A

# Get ALB hostnames
kubectl get ingress -A -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.loadBalancer.ingress[0].hostname}{"\n"}{end}'

# Describe ingress
kubectl describe ingress <name> -n <namespace>

# List ALBs in AWS
aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[?starts_with(LoadBalancerName, `k8s-`)].{Name:LoadBalancerName,DNS:DNSName}'
```

### WAF Management

```bash
# Get WAF ARN
terraform output -raw waf_web_acl_arn

# Check WAF associations
aws wafv2 list-resources-for-web-acl \
  --web-acl-arn $(terraform output -raw waf_web_acl_arn) \
  --resource-type APPLICATION_LOAD_BALANCER \
  --region ap-southeast-1

# WAF metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/WAFV2 \
  --metric-name BlockedRequests \
  --start-time 2026-01-08T00:00:00Z \
  --end-time 2026-01-08T23:59:59Z \
  --period 3600 \
  --statistics Sum
```

## 📖 References

- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Kubernetes Documentation](https://kubernetes.io/docs/home/)
- [EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)

## 📝 Version History

- **v2.1** (Jan 2026) - Development environment với WAF, ArgoCD patterns documented
- **v2.0** (Nov 2025) - Multi-environment setup, EKS 1.31
- **v1.0** - Initial release

## 👥 Support

For issues or questions:

1. Check [Troubleshooting](#-troubleshooting) section
2. Review [ArgoCD documentation](../argocd/README.md)
3. Check logs: `kubectl logs -n <namespace> <pod>`
4. Create an issue in the repository

## 📄 License

MIT License - feel free to use for your projects!
