# Multi-Environment EKS Deployment Guide

## 📋 Tổng Quan

Cấu trúc này hỗ trợ 3 môi trường:
- **DEV**: Development - Chi phí thấp (~$50-70/tháng)
- **STAGING**: Pre-production - Moderate HA (~$120-150/tháng)
- **PROD**: Production - Full HA (~$250-350/tháng)

## 📁 Cấu Trúc Thư Mục

```
terraform-eks/
├── environments/
│   ├── dev/
│   │   ├── backend.tf           # S3 backend cho dev
│   │   ├── main.tf              # Module call
│   │   ├── variables.tf         # Variable declarations
│   │   ├── outputs.tf           # Outputs
│   │   ├── versions.tf          # Provider versions
│   │   └── terraform.tfvars     # Dev values
│   ├── staging/
│   │   └── ...                  # Tương tự dev
│   └── prod/
│       └── ...                  # Tương tự dev
├── eks.tf                       # Root module
├── vpc.tf
├── iam.tf
└── ...
```

## 🚀 Deployment Steps

### 1. Tạo S3 Backend (One-time setup)

**Development:**
```bash
# Create S3 bucket
aws s3api create-bucket \
  --bucket my-terraform-state-dev \
  --region ap-southeast-1 \
  --create-bucket-configuration LocationConstraint=ap-southeast-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket my-terraform-state-dev \
  --versioning-configuration Status=Enabled

# Create DynamoDB table for locking
aws dynamodb create-table \
  --table-name terraform-state-lock-dev \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ap-southeast-1
```

**Staging:**
```bash
# Tương tự dev, thay "dev" → "staging"
aws s3api create-bucket --bucket my-terraform-state-staging ...
aws dynamodb create-table --table-name terraform-state-lock-staging ...
```

**Production:**
```bash
# Tương tự, thay "dev" → "prod"
aws s3api create-bucket --bucket my-terraform-state-prod ...
aws dynamodb create-table --table-name terraform-state-lock-prod ...
```

### 2. Tạo SSH Key Pairs (Nếu cần)

```bash
# Dev
aws ec2 create-key-pair \
  --key-name my-dev-key \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/my-dev-key.pem
chmod 400 ~/.ssh/my-dev-key.pem

# Staging
aws ec2 create-key-pair \
  --key-name my-staging-key \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/my-staging-key.pem
chmod 400 ~/.ssh/my-staging-key.pem

# Production: KHÔNG dùng SSH, dùng AWS SSM Session Manager
```

### 3. Deploy Development Environment

```bash
cd environments/dev

# Initialize Terraform
terraform init

# Review plan
terraform plan

# Apply
terraform apply

# Configure kubectl
aws eks update-kubeconfig --name my-eks-dev --region ap-southeast-1

# Verify
kubectl get nodes
```

### 4. Deploy Staging Environment

```bash
cd ../staging

terraform init
terraform plan
terraform apply

aws eks update-kubeconfig --name my-eks-staging --region ap-southeast-1
kubectl get nodes
```

### 5. Deploy Production Environment

```bash
cd ../prod

terraform init
terraform plan

# IMPORTANT: Review carefully!
terraform apply

aws eks update-kubeconfig --name my-eks-prod --region ap-southeast-1
kubectl get nodes
```

## 💰 So Sánh Chi Phí

### Development Environment (~$50-70/month)
- **EKS Control Plane**: $73/month
- **EC2**: 1x t3.medium ON_DEMAND = ~$30/month
- **NAT Gateway**: 1x = $32.4/month
- **EBS**: 30GB = ~$3/month
- **CloudWatch Logs**: Minimal (~$2/month)
- **Total**: ~$140/month

**Cost Optimizations Applied:**
- ✅ Single NAT Gateway (saves $65/month vs 3 NAT)
- ✅ Small instance (t3.medium)
- ✅ Minimal log retention (7 days)
- ✅ 1 node only

### Staging Environment (~$120-150/month)
- **EKS Control Plane**: $73/month
- **EC2**: 2x t3.large SPOT = ~$25/month (70% cheaper!)
- **NAT Gateway**: 2x = $64.8/month
- **EBS**: 100GB = ~$10/month
- **CloudWatch Logs**: Medium (~$5/month)
- **Total**: ~$178/month

**Cost Optimizations Applied:**
- ✅ SPOT instances (saves ~$75/month vs ON_DEMAND)
- ✅ 2 NAT Gateways (balance cost vs HA)
- ✅ 14-day log retention

### Production Environment (~$250-350/month)
- **EKS Control Plane**: $73/month
- **EC2**: 3x t3.xlarge ON_DEMAND = ~$250/month
- **NAT Gateway**: 3x = $97.2/month
- **EBS**: 300GB = ~$30/month
- **CloudWatch Logs**: Full logs (~$15/month)
- **Total**: ~$465/month

**Production Features:**
- ✅ Full HA across 3 AZs
- ✅ ON_DEMAND instances (no interruptions)
- ✅ 3 NAT Gateways (independent AZ internet)
- ✅ 30-day log retention (compliance)
- ✅ Larger instances (t3.xlarge)

## 🔒 Security Best Practices

### Development
- ✅ SSH access enabled (debugging)
- ✅ Public endpoint from office IP
- ⚠️ Less restrictive for testing

### Staging
- ✅ SSH access enabled (troubleshooting)
- ✅ SPOT instances (acceptable for staging)
- ✅ Similar to prod config

### Production
- ✅ **NO SSH access** - use AWS SSM Session Manager
- ✅ Strict IP whitelist for API endpoint
- ✅ ON_DEMAND instances only
- ✅ Full audit logging (30 days)
- ✅ MFA delete on S3 state bucket
- ✅ CloudTrail monitoring

## 🛠️ Common Operations

### Switch Between Environments

```bash
# Dev
cd environments/dev
export KUBECONFIG=~/.kube/config-dev
aws eks update-kubeconfig --name my-eks-dev --region ap-southeast-1

# Staging
cd environments/staging
export KUBECONFIG=~/.kube/config-staging
aws eks update-kubeconfig --name my-eks-staging --region ap-southeast-1

# Prod
cd environments/prod
export KUBECONFIG=~/.kube/config-prod
aws eks update-kubeconfig --name my-eks-prod --region ap-southeast-1
```

### Update Infrastructure

```bash
cd environments/<env>

# Pull latest code
git pull

# Review changes
terraform plan

# Apply changes
terraform apply
```

### Destroy Environment (CAREFUL!)

```bash
cd environments/<env>

# Review what will be destroyed
terraform plan -destroy

# Destroy (confirm twice)
terraform destroy
```

### View Current State

```bash
cd environments/<env>

# Show all resources
terraform state list

# Show specific resource
terraform state show module.eks.aws_eks_cluster.this
```

## 🔄 Promotion Workflow

### Dev → Staging
1. Test thoroughly in dev
2. Update `staging/terraform.tfvars` if needed
3. Apply to staging: `cd environments/staging && terraform apply`
4. Run integration tests
5. Verify everything works

### Staging → Production
1. All tests passed in staging
2. Create change request (if required)
3. Schedule maintenance window
4. Update `prod/terraform.tfvars` carefully
5. Review plan: `terraform plan` (save output)
6. Get approval
7. Apply: `terraform apply`
8. Monitor closely for 24 hours
9. Rollback plan ready

## 📊 Monitoring

### Check Cluster Health

```bash
# Nodes status
kubectl get nodes

# Pods status
kubectl get pods -A

# Cluster info
kubectl cluster-info

# Node resources
kubectl top nodes
```

### AWS Console Checks
- EKS Console: Cluster status, addons
- EC2 Console: Node health, instance status
- CloudWatch: Logs, metrics
- VPC Console: NAT Gateway, subnet status

## 🚨 Troubleshooting

### Backend Initialization Failed
```bash
# Check S3 bucket exists
aws s3 ls s3://my-terraform-state-dev

# Check DynamoDB table
aws dynamodb describe-table --table-name terraform-state-lock-dev
```

### Nodes Not Joining Cluster
```bash
# Check node security group
aws ec2 describe-security-groups --group-ids <node-sg-id>

# Check CloudWatch logs
aws logs tail /aws/eks/my-eks-dev/cluster --follow

# SSH to node (dev/staging only)
ssh -i ~/.ssh/my-dev-key.pem ec2-user@<node-ip>
journalctl -u kubelet
```

### SPOT Interruptions (Staging)
```bash
# Monitor interruption notices
kubectl get events -A | grep -i spot

# Check node status
kubectl describe node <node-name>

# Pods should be rescheduled automatically
kubectl get pods -A -o wide
```

## 📚 Additional Resources

- [EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [Terraform AWS Provider Docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [AWS EKS Workshop](https://www.eksworkshop.com/)

## 🎯 Next Steps

1. **Install AWS Load Balancer Controller**
   ```bash
   cd environments/<env>
   # Follow ALB-CONTROLLER-README.md
   ```

2. **Setup Monitoring**
   - Install Prometheus & Grafana
   - Setup CloudWatch Container Insights
   - Configure alerts

3. **Setup CI/CD**
   - GitHub Actions / GitLab CI
   - Automated testing
   - Automated deployments

4. **Implement GitOps**
   - ArgoCD or Flux
   - Declarative deployments
   - Rollback capabilities

5. **Setup Backup**
   - Velero for cluster backup
   - EBS snapshots
   - State file backup

## ⚠️ Important Notes

1. **State File Security**
   - NEVER commit `.tfstate` files
   - S3 bucket should have encryption
   - Restrict IAM access to state bucket

2. **Environment Isolation**
   - Each environment has separate:
     - VPC (different CIDR)
     - S3 backend bucket
     - DynamoDB lock table
     - EKS cluster name

3. **Cost Management**
   - Enable AWS Cost Explorer
   - Setup billing alerts
   - Review costs weekly
   - Use AWS Cost Anomaly Detection

4. **Production Changes**
   - Always test in dev first
   - Promote to staging
   - Schedule prod changes during low-traffic
   - Have rollback plan ready
   - Monitor for 24h after changes
