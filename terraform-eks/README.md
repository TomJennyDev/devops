# EKS Terraform Configuration - Multi-Environment

Terraform configuration để deploy Amazon EKS cluster với 3 môi trường: **Dev**, **Staging**, và **Production** (November 2025).

## 📋 Yêu cầu

- **Terraform**: >= 1.0
- **AWS CLI**: >= 2.x
- **kubectl**: >= 1.31
- **AWS Account** với quyền tạo EKS, VPC, IAM
- **S3 Bucket** cho Terraform state (mỗi môi trường 1 bucket)
- **ArgoCD** (optional): Để deploy applications sau khi tạo cluster

## 🏗️ Kiến trúc Multi-Layer GitOps

```
┌──────────────────────────────────────────────────────────────────────────┐
│                    EKS Multi-Environment GitOps Architecture              │
│         Terraform Infrastructure + ArgoCD + Prometheus + Flowise          │
└──────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│  LAYER 1: Infrastructure (Terraform)                                    │
├─────────────────────────────────────────────────────────────────────────┤
│  Terraform Modules:                                                     │
│  ┌─────────────────┐  ┌──────────────────┐  ┌────────────────────┐   │
│  │ VPC & Networking│  │  EKS Cluster     │  │  AWS Services      │   │
│  │ • Public Subnets│  │  • K8s 1.31/1.34 │  │  • IAM (IRSA)      │   │
│  │ • Private       │  │  • CoreDNS       │  │  • Route53         │   │
│  │ • IGW, NAT(1-3) │  │  • VPC CNI       │  │  • ACM (SSL/TLS)   │   │
│  │ • ALB           │  │  • kube-proxy    │  │  • ECR             │   │
│  │ • 2-3 AZs       │  │  • 2-6 nodes     │  │  • CloudWatch      │   │
│  └─────────────────┘  └──────────────────┘  │  • S3 + DynamoDB   │   │
│                                              └────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────┐
│  LAYER 2: System Applications (ArgoCD Managed)                         │
├─────────────────────────────────────────────────────────────────────────┤
│  ┌──────────────────┐  ┌──────────────────┐  ┌─────────────────────┐ │
│  │ argocd namespace │  │ kube-system      │  │ monitoring          │ │
│  │ • ArgoCD GitOps  │  │ • AWS LB Ctrl    │  │ • Prometheus        │ │
│  │ • App of Apps    │  │ • External DNS   │  │ • Grafana           │ │
│  │ • Auto Sync      │  │ • kube-proxy     │  │ • Alertmanager      │ │
│  │ • Self Heal      │  │                  │  │ • Node Exporter     │ │
│  │                  │  │                  │  │ • Kube State        │ │
│  │ Bootstrap:       │  │                  │  │ • Pushgateway       │ │
│  │ - infra-apps-dev │  │                  │  │ • Dashboards        │ │
│  │ - flowise-dev    │  │                  │  │                     │ │
│  └──────────────────┘  └──────────────────┘  └─────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────┐
│  LAYER 3: Business Applications (ArgoCD Managed)                       │
├─────────────────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────┐  ┌──────────────────────────────────┐  │
│  │ flowise-dev/staging/prod │  │ your-app-* namespaces            │  │
│  │ • Flowise AI Chatbot     │  │ • Your Microservices             │  │
│  │ • PostgreSQL Database    │  │ • Databases (MySQL, MongoDB)     │  │
│  │ • Ingress (ALB+ACM SSL)  │  │ • Workers & Background Jobs      │  │
│  │ • PVC (Storage)          │  │ • Message Queues (RabbitMQ)      │  │
│  │ • HPA (Auto-scaling)     │  │ • Cache (Redis)                  │  │
│  │ URL: flowise-dev.        │  │ • REST APIs                      │  │
│  │      do2506.click        │  │                                  │  │
│  └──────────────────────────┘  └──────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│  CI/CD Pipeline (GitHub Actions)                                        │
├─────────────────────────────────────────────────────────────────────────┤
│  DevOps → GitHub → GitHub Actions → Docker Build → Push ECR → ArgoCD  │
│           Repo      (CI Pipeline)     (Image)       (Registry)  Sync   │
│                                                                         │
│  Flow: Code Push → Build → Test → Push Image → ArgoCD Auto Deploy     │
└─────────────────────────────────────────────────────────────────────────┘

                           End Users ← Internet → ALB → Services
```

**Architecture Highlights:**

🔹 **Layer 1 - Infrastructure (Terraform):**

- Multi-AZ deployment (2 AZs for Dev, 3 AZs for Staging/Prod)
- High Availability with multiple NAT Gateways
- EKS Cluster with latest Kubernetes (1.31/1.34)
- Complete AWS integration (IAM, Route53, ACM, ECR, CloudWatch)
- State management with S3 + DynamoDB locking

🔹 **Layer 2 - System Apps (ArgoCD):**

- **ArgoCD**: GitOps continuous deployment (App of Apps pattern)
- **AWS Load Balancer Controller**: ALB/NLB for Ingress
- **External DNS**: Automatic Route53 record management
- **Prometheus Stack**: Complete monitoring solution
  - Metrics collection from K8s API, nodes, pods
  - Grafana dashboards for visualization
  - Alerting with Alertmanager
  - Multiple exporters (Node, Kube State, Push Gateway)

🔹 **Layer 3 - Business Apps (ArgoCD):**

- **Flowise**: AI Chatbot with PostgreSQL, Ingress, PVC, HPA
- **Your Applications**: Deployed via ArgoCD from GitHub
- Auto-scaling, persistent storage, SSL certificates
- Multiple environments (dev, staging, prod)

🔹 **CI/CD Pipeline:**

- GitHub Actions for automated builds
- Docker image build and push to ECR
- ArgoCD auto-sync for deployment
- GitOps workflow (Git as single source of truth)

**DNS & SSL Architecture:**

- **CoreDNS**: Built-in EKS addon - internal cluster DNS (service discovery)
- **External DNS**: Optional module - syncs Ingress/Service to Route53 (public DNS)
- **AWS ACM**: SSL/TLS certificate management (no cert-manager needed)

## 🏗️ Kiến trúc Multi-Environment

```
terraform-eks/
├── environments/
│   ├── dev/          # Development (~$140/month)
│   ├── staging/      # Pre-production (~$185/month)
│   └── prod/         # Production (~$315/month)
├── modules/                  # Reusable infrastructure modules
│   ├── vpc/                 # VPC, subnets, NAT, IGW
│   ├── iam/                 # IAM roles and policies
│   ├── security-groups/     # Security groups
│   ├── eks/                 # EKS cluster and addons (CoreDNS included)
│   ├── node-groups/         # Managed node groups
│   ├── alb-controller/      # ALB Controller IAM (IRSA)
│   └── external-dns/        # External DNS IAM (optional)
├── argocd/                   # ArgoCD application manifests
│   ├── app-of-apps.yaml     # App-of-Apps pattern
│   ├── system-apps/         # System-level apps
│   │   ├── aws-load-balancer-controller.yaml
│   │   ├── metrics-server.yaml
│   │   └── external-dns.yaml
│   └── examples/            # Configuration examples
│       ├── ingress-with-acm.md
│       └── external-dns-route53-setup.md
├── scripts/
│   ├── validate-all.sh      # Validate all environments
│   └── test-environment.sh  # Test specific environment
└── docs/
    ├── ENVIRONMENTS-README.md       # Environment details
    ├── NODE-GROUPS-README.md        # Node configuration
    ├── ALB-CONTROLLER-README.md     # Load balancer setup
    ├── DNS-ARCHITECTURE.md          # DNS architecture (CoreDNS vs External DNS)
    └── architecture-diagram.drawio  # Architecture diagram
```

### VPC Architecture (per environment)

```
VPC (10.x.0.0/16)
├── Public Subnets (2-3 AZs based on env)
│   ├── 10.x.1.0/24 (ap-southeast-1a)
│   ├── 10.x.2.0/24 (ap-southeast-1b)
│   └── 10.x.3.0/24 (ap-southeast-1c) [staging/prod only]
├── Private Subnets (2-3 AZs based on env)
│   ├── 10.x.11.0/24 (Nodes)
│   ├── 10.x.12.0/24 (Nodes)
│   └── 10.x.13.0/24 (Nodes) [staging/prod only]
├── Internet Gateway
├── NAT Gateway (1-3 based on env)
└── EKS Cluster (Kubernetes 1.31/1.34)
```

## 📦 Tính năng

- ✅ **Multi-Environment** - Dev, Staging, Production separated
- ✅ **EKS 1.31/1.34** - Kubernetes versions (Dev: 1.34, Staging/Prod: 1.31)
- ✅ **AWS Provider 5.100** - Latest features support
- ✅ **State Isolation** - Separate S3 backend per environment
- ✅ **Cost Optimized** - SPOT instances (staging), configurable NAT
- ✅ **High Availability** - Multi-AZ deployment (2-3 AZs based on env)
- ✅ **Amazon Linux 2023** - Latest AMI with long-term support
- ✅ **EKS Addons** - Dev: VPC CNI v1.20.4, CoreDNS v1.12.4, kube-proxy v1.34.1 | Staging/Prod: VPC CNI v1.18.5, CoreDNS v1.11.3, kube-proxy v1.31.0
- ✅ **IRSA Support** - IAM Roles for Service Accounts
- ✅ **ALB Controller** - Ready for Application Load Balancer
- ✅ **External DNS** - Optional Route53 automation for public DNS
- ✅ **AWS ACM** - SSL/TLS certificate management
- ✅ **GitOps Ready** - ArgoCD for application deployment
- ✅ **CloudWatch Logging** - Configurable log retention per environment
- ✅ **Security Hardened** - Separated security groups, optional SSH
- ✅ **Auto-scaling** - Node groups with configurable scaling

## 🚀 Quick Start

### Option 1: Test Configuration First (Recommended)

```bash
# Validate all environments
bash scripts/validate-all.sh

# Test specific environment
bash scripts/test-environment.sh dev
```

### Option 2: Deploy Step by Step

## 📝 Deployment Guide

### 🔧 Step 1: Chuẩn bị AWS Backend

Tạo S3 buckets và DynamoDB tables cho **mỗi môi trường**:

#### Development Backend

```bash
# Create S3 bucket
aws s3api create-bucket \
  --bucket terraform-state-372836560690-dev \
  --region ap-southeast-1 \
  --create-bucket-configuration LocationConstraint=ap-southeast-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket terraform-state-372836560690-dev \
  --versioning-configuration Status=Enabled

# Create DynamoDB table for locking
aws dynamodb create-table \
  --table-name terraform-state-lock-372836560690-dev \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ap-southeast-1
```

#### Staging Backend

```bash
aws s3api create-bucket \
  --bucket terraform-state-372836560690-staging \
  --region ap-southeast-1 \
  --create-bucket-configuration LocationConstraint=ap-southeast-1

aws s3api put-bucket-versioning \
  --bucket terraform-state-372836560690-staging \
  --versioning-configuration Status=Enabled

aws dynamodb create-table \
  --table-name terraform-state-lock-372836560690-staging \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ap-southeast-1
```

#### Production Backend

```bash
aws s3api create-bucket \
  --bucket terraform-state-372836560690-prod \
  --region ap-southeast-1 \
  --create-bucket-configuration LocationConstraint=ap-southeast-1

aws s3api put-bucket-versioning \
  --bucket terraform-state-372836560690-prod \
  --versioning-configuration Status=Enabled

aws dynamodb create-table \
  --table-name terraform-state-lock-372836560690-prod \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ap-southeast-1
```

### 🌱 Step 2: Deploy Development Environment

```bash
cd environments/dev

# Review configuration
cat terraform.tfvars

# Update backend.tf with your bucket names (if needed)
# Update terraform.tfvars with your settings

# Initialize
terraform init

# Review what will be created
terraform plan

# Deploy (takes ~15-20 minutes)
terraform apply

# Configure kubectl
aws eks update-kubeconfig --name my-eks-dev --region ap-southeast-1

# Verify
kubectl get nodes
kubectl get pods -A
```

**Development Config:**

- 1 NAT Gateway (cost saving)
- 2 nodes (t3.large ON_DEMAND) - HA configuration
- 2 Availability Zones
- 7 days log retention
- SSH enabled for debugging
- EKS 1.34 (latest)
- Cost: ~$140-160/month

### 🧪 Step 3: Deploy Staging Environment

```bash
cd environments/staging

# Review and customize
vim terraform.tfvars

terraform init
terraform plan
terraform apply

# Configure kubectl
aws eks update-kubeconfig --name my-eks-staging --region ap-southeast-1
kubectl get nodes
```

**Staging Config:**

- 2 NAT Gateways (moderate HA)
- 2 nodes (t3.large SPOT - 70% cheaper)
- 3 Availability Zones
- 14 days log retention
- EKS 1.31
- Similar to production for testing
- Cost: ~$185-200/month

### 🚀 Step 4: Deploy Production Environment

```bash
cd environments/prod

# Review carefully!
vim terraform.tfvars

terraform init
terraform plan

# Review plan thoroughly before applying!
terraform apply

# Configure kubectl
aws eks update-kubeconfig --name my-eks-prod --region ap-southeast-1
kubectl get nodes
```

**Production Config:**

- 3 NAT Gateways (full HA)
- 3 nodes (t3.xlarge/t3a.xlarge ON_DEMAND)
- 3 Availability Zones
- 30 days log retention (compliance)
- EKS 1.31
- SSH disabled (use SSM)
- Strict CIDR whitelist
- Cost: ~$315-350/month

## 📊 Outputs

Sau khi deploy xong, Terraform sẽ output:

```bash
cluster_endpoint              # EKS API endpoint
cluster_name                  # Tên cluster
cluster_version               # Kubernetes version
oidc_provider_arn             # OIDC provider ARN (cho IRSA)
vpc_id                        # VPC ID
configure_kubectl             # Command để config kubectl
```

## 💰 Chi phí So Sánh

| Environment | EKS | EC2 Nodes | NAT Gateway | Storage | Logs | **Total** |
|-------------|-----|-----------|-------------|---------|------|-----------||
| **Dev** | $73 | $60 (2x t3.large ON_DEMAND) | $32 (1x) | $5 | $2 | **~$140-160**|
| **Staging** | $73 | $20 (2x t3.large SPOT) | $65 (2x) | $10 | $5 | **~$185-200** |
| **Production** | $73 | $150 (3x t3.xlarge) | $97 (3x) | $30 | $10 | **~$315-350** |

💡 **Cost Optimization Tips:**

- Use SPOT instances in staging: Save ~70%
- Use ARM/Graviton instances: Save ~20%
- Reduce NAT Gateway count in dev: Save $65/month
- Use smaller instances in dev: Save $60-120/month

## 🎯 Environment Comparison

| Feature | Development | Staging | Production |
|---------|-------------|---------|------------|
| **Purpose** | Testing, development | Pre-prod validation | Live workloads |
| **EKS Version** | 1.34 | 1.31 | 1.31 |
| **VPC CIDR** | 10.0.0.0/16 | 10.1.0.0/16 | 10.2.0.0/16 |
| **Availability Zones** | 2 AZs | 3 AZs | 3 AZs |
| **NAT Gateways** | 1 NAT | 2 NAT | 3 NAT |
| **Node Count** | 2 (min) → 4 (max) | 2 (min) → 5 (max) | 3 (min) → 10 (max) |
| **Instance Type** | t3.large | t3.large | t3.xlarge/t3a.xlarge |
| **Capacity** | ON_DEMAND | SPOT (70% off) | ON_DEMAND |
| **SSH Access** | ✅ Enabled | ✅ Enabled | ❌ Disabled (SSM only) |
| **API Access** | Public (0.0.0.0/0) | Public (restricted) | Public (strict IPs) |
| **Log Retention** | 7 days | 14 days | 30 days (compliance) |
| **Disk Size** | 30GB | 50GB | 100GB |
| **Monthly Cost** | ~$140-160 | ~$185-200 | ~$315-350 |

## 🔧 Tùy chỉnh

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
node_instance_types = ["t3.medium", "t3.large"]
```

### Restrict API Access

```hcl
cluster_endpoint_public_access       = true
cluster_endpoint_public_access_cidrs = ["1.2.3.4/32"]  # Your IP
```

## 🔧 Post-Deployment Configuration

### Install AWS Load Balancer Controller

```bash
# Already configured in alb-controller.tf
# Follow the guide in ALB-CONTROLLER-README.md
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.1/docs/install/iam_policy.json
```

## 🔧 Post-Deployment: Install System Applications

After Terraform creates the infrastructure, deploy system applications using ArgoCD:

### Option 1: Using ArgoCD (Recommended - GitOps)

```bash
# 1. Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 2. Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# 3. Port forward ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# 4. Login to ArgoCD UI at https://localhost:8080
# Username: admin
# Password: (from step 2)

# 5. Deploy system applications
kubectl apply -f ../argocd/bootstrap/infrastructure-apps-dev.yaml

# This will automatically install:
# ✓ AWS Load Balancer Controller (for ALB/NLB ingress)
# ✓ Prometheus + Grafana (monitoring)
# ✓ External DNS (optional - for Route53 automation)
```

**📖 Detailed guides:**

- [argocd/README.md](../argocd/README.md) - Complete ArgoCD setup
- [argocd/docs/](../argocd/docs/) - ArgoCD architecture and getting started
- [docs/DNS-ARCHITECTURE.md](docs/DNS-ARCHITECTURE.md) - DNS architecture explained

### Option 2: Manual Helm Installation

```bash
# AWS Load Balancer Controller
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Get IAM role ARN from Terraform output
export ROLE_ARN=$(terraform output -raw aws_load_balancer_controller_role_arn)
export CLUSTER_NAME=$(terraform output -raw cluster_name)

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=${CLUSTER_NAME} \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=${ROLE_ARN}

# Or use ArgoCD to manage it (recommended)
kubectl apply -f ../argocd/infrastructure/aws-load-balancer-controller/
```

📖 Detailed guide: [argocd/README.md](../argocd/README.md)

### Deploy Sample Application

```bash
# Create deployment
kubectl create deployment nginx --image=nginx --replicas=3

# Expose with LoadBalancer
kubectl expose deployment nginx --type=LoadBalancer --port=80

# Get LoadBalancer URL
kubectl get svc nginx
```

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

### Clean Up Kubernetes Resources First

```bash
# Delete all LoadBalancers (prevent orphaned ELBs)
kubectl delete svc --all --all-namespaces

# Delete all PersistentVolumeClaims (prevent orphaned EBS)
kubectl delete pvc --all --all-namespaces
```

### Destroy Terraform Resources

```bash
# Development
cd environments/dev
terraform destroy

# Staging
cd environments/staging
terraform destroy

# Production
cd environments/prod
terraform destroy  # ⚠️ Be very careful!
```

⏱️ Destruction takes ~10-15 minutes per environment

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [README.md](README.md) | This file - Getting started guide |
| [modules/vpc/README.md](modules/vpc/README.md) | VPC module documentation |
| [modules/ecr/README.md](modules/ecr/README.md) | ECR module documentation |
| [modules/resource-limits/README.md](modules/resource-limits/README.md) | Resource limits configuration |
| [argocd/README.md](../argocd/README.md) | ArgoCD and GitOps setup |
| [argocd/docs/](../argocd/docs/) | Complete ArgoCD documentation |

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

### Error: "error creating EKS Cluster"

```bash
# Check IAM permissions
aws sts get-caller-identity

# Check service quotas
aws service-quotas get-service-quota \
  --service-code eks \
  --quota-code L-1194D53C
```

### Nodes not joining cluster

```bash
# Check node IAM role
kubectl get nodes
aws eks describe-cluster --name my-eks-dev

# Check security groups
aws ec2 describe-security-groups \
  --filters "Name=tag:Name,Values=*eks*"
```

### Cannot pull images from ECR

```bash
# Check VPC CNI addon
kubectl get pods -n kube-system | grep aws-node

# Check NAT Gateway
aws ec2 describe-nat-gateways \
  --filter "Name=state,Values=available"
```

### Terraform State Issues

```bash
# Refresh state
terraform refresh

# Import existing resource
terraform import <resource_type>.<name> <resource_id>
```

## 🔗 Useful Commands

### Cluster Management

```bash
# Switch between environments
aws eks update-kubeconfig --name my-eks-dev --region ap-southeast-1
aws eks update-kubeconfig --name my-eks-staging --region ap-southeast-1
aws eks update-kubeconfig --name my-eks-prod --region ap-southeast-1

# List contexts
kubectl config get-contexts

# Switch context
kubectl config use-context <context-name>
```

### Validation & Testing

```bash
# Validate all environments
bash scripts/validate-all.sh

# Test specific environment
bash scripts/test-environment.sh dev
```

## 📖 References

- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Kubernetes Documentation](https://kubernetes.io/docs/home/)
- [EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)

## 📝 Version History

- **v2.0** (Nov 2025) - Multi-environment setup, EKS 1.31, AWS Provider 5.75, AL2023
- **v1.0** - Initial release

## 👥 Support

For issues or questions:

1. Check [Troubleshooting](#-troubleshooting) section
2. Review validation: `bash scripts/validate-all.sh`
3. Check documentation in `docs/` folder
4. Create an issue in the repository

## 📄 License

MIT License - feel free to use for your projects!
