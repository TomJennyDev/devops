# Terraform EKS Deployment Guide

Hướng dẫn triển khai EKS cluster với Terraform.

## Prerequisites

- AWS CLI configured (`aws configure`)
- Terraform >= 1.13
- kubectl >= 1.28
- Helm >= 3.0

## Deployment Steps

### 1. Configure Variables

```bash
cd terraform-eks/environments/dev
cp terraform.tfvars.example terraform.tfvars  # Nếu chưa có

# Edit terraform.tfvars với thông tin của bạn:
# - cluster_name
# - aws_region
# - vpc_cidr
# - node_group_desired_size
# - ecr_repositories
```

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Review Plan

```bash
terraform plan
```

### 4. Deploy Infrastructure

```bash
terraform apply
```

**Timeline:** ~20-25 phút

- VPC, IAM, Security Groups: ~2 phút
- EKS Cluster: ~9 phút  
- Node Groups: ~5 phút
- VPC-CNI, Kube-proxy: ~1 phút
- CoreDNS addon: ~2 phút
- ECR repositories: ~10 giây

### 5. Verify Deployment

```bash
# Configure kubectl
aws eks update-kubeconfig --region ap-southeast-1 --name my-eks-dev

# Check nodes
kubectl get nodes

# Check system pods
kubectl get pods -n kube-system

# Check CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns
aws eks describe-addon --cluster-name my-eks-dev --addon-name coredns
```

### 6. Export Cluster Info

```bash
cd ../../scripts
./export-cluster-info.sh
```

**Output:** `environments/dev/cluster-info/`

- `cluster-info.yaml` - Cluster information
- `cluster-env.sh` - Environment variables
- `argocd-cluster-values.yaml` - Helm values cho ArgoCD

## Outputs

Sau khi apply xong, Terraform sẽ hiển thị:

```
Outputs:

cluster_id = "my-eks-dev"
cluster_endpoint = "https://F6C5DEE49950A6782A9F46119614E70C.gr7.ap-southeast-1.eks.amazonaws.com"
vpc_id = "vpc-0e6ca42c7851c46c4"
node_group_id = "my-eks-dev:dev-workers"
aws_load_balancer_controller_role_arn = "arn:aws:iam::372836560690:role/my-eks-dev-aws-load-balancer-controller"
ecr_flowise_server_url = "372836560690.dkr.ecr.ap-southeast-1.amazonaws.com/flowise-server"
ecr_flowise_ui_url = "372836560690.dkr.ecr.ap-southeast-1.amazonaws.com/flowise-ui"
```

## Resources Created

| Resource | Description |
|----------|-------------|
| **VPC** | 10.0.0.0/16 with 2 AZs |
| **Subnets** | 2 public + 2 private |
| **NAT Gateway** | 1 NAT GW |
| **EKS Cluster** | Kubernetes 1.34 |
| **Node Group** | 2x t3.medium nodes |
| **IAM Roles** | Cluster, Node, ALB Controller |
| **Security Groups** | Cluster + Node groups |
| **ECR** | 2 repositories (flowise-server, flowise-ui) |
| **Addons** | VPC-CNI, Kube-proxy, CoreDNS |

## Important Notes

### CoreDNS Fix

CoreDNS addon được tạo **SAU** node groups để tránh timeout 20 phút.

**Thứ tự tạo:**

```
1. EKS Cluster + VPC-CNI + Kube-proxy
2. Node Groups (nodes ready)
3. CoreDNS addon (pods schedule ngay)
```

### State Management

- **Backend:** S3 bucket `terraform-state-<account-id>-dev`
- **Lock:** DynamoDB table `terraform-state-lock`
- **State file:** `eks/terraform.tfstate`

### Cost Estimation

**Monthly costs (dev environment):**

- EKS Cluster: $73
- 2x t3.medium: ~$60
- NAT Gateway: ~$32
- Load Balancer: ~$16
- **Total:** ~$181/month

## Troubleshooting

### State Lock Error

```bash
terraform force-unlock <lock-id>
```

### CoreDNS Degraded

CoreDNS đã được fix tự động. Nếu vẫn bị:

```bash
# Check nodes
kubectl get nodes

# Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Restart CoreDNS
kubectl rollout restart deployment coredns -n kube-system
```

### Cannot Access Cluster

```bash
aws eks update-kubeconfig --region ap-southeast-1 --name my-eks-dev
kubectl get nodes
```

### Destroy Infrastructure

```bash
cd terraform-eks/environments/dev
terraform destroy
```

⚠️ **Warning:** Sẽ xóa toàn bộ infrastructure (~10-15 phút)

## Next Steps

After Terraform deployment complete → [ARGOCD-DEPLOYMENT.md](./ARGOCD-DEPLOYMENT.md)
