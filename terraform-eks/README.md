# EKS Terraform Configuration

Terraform configuration để deploy một Amazon EKS cluster đầy đủ với các best practices (November 2025).

## 📋 Yêu cầu

- **Terraform**: >= 1.0
- **AWS CLI**: >= 2.x
- **kubectl**: >= 1.31
- **AWS Account** với quyền tạo EKS, VPC, IAM

## 🏗️ Kiến trúc

```
├── VPC (10.0.0.0/16)
│   ├── Public Subnets (3 AZs)
│   │   ├── 10.0.1.0/24
│   │   ├── 10.0.2.0/24
│   │   └── 10.0.3.0/24
│   └── Private Subnets (3 AZs)
│       ├── 10.0.11.0/24
│       ├── 10.0.12.0/24
│       └── 10.0.13.0/24
├── Internet Gateway
├── NAT Gateway (1-3 instances)
├── EKS Control Plane (Kubernetes 1.31)
└── EKS Node Group (t3.medium, 2-4 nodes)
```

## 📦 Tính năng

- ✅ **EKS 1.31** - Kubernetes version mới nhất (Nov 2025)
- ✅ **AWS Provider 5.75** - Hỗ trợ tất cả tính năng mới nhất
- ✅ **VPC với 3 AZs** - High availability
- ✅ **NAT Gateway** - Private subnets có internet access
- ✅ **Managed Node Group** - Auto scaling từ 1-4 nodes
- ✅ **Amazon Linux 2023** - AMI mới nhất
- ✅ **EKS Addons** - VPC CNI, CoreDNS, kube-proxy
- ✅ **IRSA** - IAM Roles for Service Accounts
- ✅ **CloudWatch Logging** - Control plane logs
- ✅ **Security Groups** - Tối ưu cho EKS
- ✅ **SSM Access** - Connect vào nodes không cần SSH

## 🚀 Cách sử dụng

### 1. Clone và cấu hình

```bash
cd d:/devops/terraform-eks
cp terraform.tfvars.example terraform.tfvars
```

### 2. Chỉnh sửa `terraform.tfvars`

```hcl
aws_region      = "us-west-2"
cluster_name    = "my-eks-cluster"
cluster_version = "1.31"

# Adjust node configuration
node_instance_types = ["t3.medium"]
node_desired_size   = 2
node_max_size       = 4
node_min_size       = 1
```

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Review plan

```bash
terraform plan
```

### 5. Apply configuration

```bash
terraform apply
```

⏱️ Thời gian deploy: ~15-20 phút

### 6. Configure kubectl

```bash
aws eks update-kubeconfig --region us-west-2 --name my-eks-cluster
```

### 7. Verify cluster

```bash
kubectl get nodes
kubectl get pods -A
```

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

## 💰 Chi phí ước tính (us-west-2)

| Resource | Quantity | Monthly Cost |
|----------|----------|--------------|
| EKS Control Plane | 1 | $73 |
| t3.medium nodes | 2 | ~$60 |
| NAT Gateway | 1 | ~$32 |
| EBS volumes | 40GB | ~$4 |
| **Total** | | **~$169/month** |

*Chi phí thực tế có thể khác tùy usage*

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

## 🔐 Security Best Practices

1. **Không commit** file `terraform.tfvars` có credentials
2. **Sử dụng IAM roles** thay vì hardcode credentials
3. **Enable CloudWatch logs** để audit
4. **Restrict API access** bằng CIDR blocks
5. **Enable private endpoint** trong production
6. **Use IRSA** thay vì node IAM roles cho pods

## 🧹 Cleanup

```bash
# Delete all Kubernetes resources first
kubectl delete all --all -A

# Then destroy Terraform resources
terraform destroy
```

⚠️ **Lưu ý**: NAT Gateway và ELB có thể mất vài phút để xóa

## 📚 Structure

```
terraform-eks/
├── main.tf              # Provider configuration
├── versions.tf          # Terraform & provider versions
├── variables.tf         # Input variables
├── outputs.tf           # Output values
├── vpc.tf              # VPC, subnets, NAT gateway
├── eks.tf              # EKS cluster & node group
├── iam.tf              # IAM roles & policies
├── security-groups.tf  # Security groups
├── terraform.tfvars.example  # Example variables
└── README.md           # This file
```

## 🐛 Troubleshooting

### Error: "error creating EKS Cluster"

```bash
# Check IAM permissions
aws sts get-caller-identity
```

### Nodes not joining cluster

```bash
# Check node IAM role
aws iam get-role --role-name <cluster-name>-eks-node-role

# Check security groups
kubectl get nodes
aws eks describe-cluster --name <cluster-name>
```

### Cannot pull images

```bash
# Check VPC CNI addon
kubectl get pods -n kube-system

# Check NAT Gateway
aws ec2 describe-nat-gateways
```

## 📖 References

- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## 📝 Version History

- **v2.0** (Nov 2025) - Updated to Kubernetes 1.31, AWS Provider 5.75, AL2023
- **v1.0** - Initial release

## 👨‍💻 Author

DevOps Team

## 📄 License

MIT