# AWS EKS Module

## Overview
Creates a production-ready Amazon EKS cluster with managed control plane, IRSA (IAM Roles for Service Accounts), and comprehensive security configurations.

## Features
- ✅ EKS Cluster v1.28-1.34 support
- ✅ IRSA (IAM Roles for Service Accounts) with OIDC provider
- ✅ Public/Private endpoint access control
- ✅ Cluster encryption with KMS (optional)
- ✅ Control plane logging to CloudWatch
- ✅ Pod Security Standards enforcement
- ✅ VPC CNI configuration for pod networking
- ✅ Auto-scaling group integration
- ✅ Certificate authority data export

## Architecture
```
┌──────────────────────────────────────────────────────────┐
│                    EKS Control Plane                     │
│              (Managed by AWS - Multi-AZ)                 │
│                                                          │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐          │
│  │API Server │  │  etcd     │  │Scheduler  │          │
│  │           │  │           │  │Controller │          │
│  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘          │
│        │              │              │                  │
│        └──────────────┴──────────────┘                  │
│                       │                                  │
└───────────────────────┼──────────────────────────────────┘
                        │
                        │ (Secure Communications)
                        │
┌───────────────────────┼──────────────────────────────────┐
│                  VPC (Customer Managed)                  │
│                       │                                  │
│  ┌────────────────────┴────────────────────┐            │
│  │          Worker Node Groups              │            │
│  │  (Private Subnets across Multiple AZs)  │            │
│  │                                          │            │
│  │  ┌──────────┐  ┌──────────┐            │            │
│  │  │  Node    │  │  Node    │            │            │
│  │  │  Group 1 │  │  Group 2 │    ...     │            │
│  │  │          │  │          │            │            │
│  │  │ - Pods   │  │ - Pods   │            │            │
│  │  │ - IRSA   │  │ - IRSA   │            │            │
│  │  └──────────┘  └──────────┘            │            │
│  └─────────────────────────────────────────┘            │
└──────────────────────────────────────────────────────────┘
```

## Usage

### Basic Cluster (Development)
```hcl
module "eks" {
  source = "../../modules/eks"

  cluster_name    = "my-eks-dev"
  cluster_version = "1.34"
  
  vpc_id                  = module.vpc.vpc_id
  subnet_ids              = module.vpc.private_subnet_ids
  control_plane_subnet_ids = module.vpc.private_subnet_ids
  
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true
  
  cluster_enabled_log_types = ["api", "audit"]
  
  common_tags = {
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}
```

### Production Cluster (Enhanced Security)
```hcl
module "eks" {
  source = "../../modules/eks"

  cluster_name    = "my-eks-prod"
  cluster_version = "1.34"
  
  vpc_id                  = module.vpc.vpc_id
  subnet_ids              = module.vpc.private_subnet_ids
  control_plane_subnet_ids = module.vpc.private_subnet_ids
  
  # Security hardening
  cluster_endpoint_public_access  = false  # Private only
  cluster_endpoint_private_access = true
  cluster_encryption_config = {
    enabled = true
    kms_key_arn = aws_kms_key.eks.arn
  }
  
  # Comprehensive logging
  cluster_enabled_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]
  
  # Security groups
  cluster_additional_security_group_ids = [
    aws_security_group.additional_eks_sg.id
  ]
  
  common_tags = {
    Environment = "prod"
    ManagedBy   = "Terraform"
    Compliance  = "PCI-DSS"
  }
}
```

### IRSA Setup for Applications
```hcl
# Create IAM role for app with IRSA
module "app_irsa" {
  source = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  
  create_role = true
  role_name   = "my-app-irsa-role"
  
  provider_url = module.eks.cluster_oidc_issuer_url
  
  role_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  ]
  
  oidc_fully_qualified_subjects = [
    "system:serviceaccount:default:my-app-sa"
  ]
}

# Kubernetes ServiceAccount
resource "kubernetes_service_account" "app" {
  metadata {
    name      = "my-app-sa"
    namespace = "default"
    annotations = {
      "eks.amazonaws.com/role-arn" = module.app_irsa.iam_role_arn
    }
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cluster_name | Name of the EKS cluster | `string` | - | yes |
| cluster_version | Kubernetes version | `string` | `"1.34"` | no |
| vpc_id | VPC ID where cluster will be created | `string` | - | yes |
| subnet_ids | Subnet IDs for worker nodes | `list(string)` | - | yes |
| control_plane_subnet_ids | Subnet IDs for control plane ENIs | `list(string)` | - | yes |
| cluster_endpoint_public_access | Enable public API endpoint | `bool` | `true` | no |
| cluster_endpoint_private_access | Enable private API endpoint | `bool` | `true` | no |
| cluster_endpoint_public_access_cidrs | CIDR blocks for public API access | `list(string)` | `["0.0.0.0/0"]` | no |
| cluster_enabled_log_types | Control plane logging types | `list(string)` | `["api", "audit"]` | no |
| cluster_encryption_config | KMS encryption configuration | `object` | `null` | no |
| cluster_additional_security_group_ids | Additional security groups | `list(string)` | `[]` | no |
| cluster_service_ipv4_cidr | CIDR for Kubernetes services | `string` | `null` | no |
| enable_irsa | Enable IRSA (OIDC provider) | `bool` | `true` | no |
| common_tags | Tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster_id | EKS cluster ID |
| cluster_arn | EKS cluster ARN |
| cluster_endpoint | EKS cluster API endpoint |
| cluster_version | EKS cluster Kubernetes version |
| cluster_security_group_id | Security group ID attached to cluster |
| cluster_certificate_authority_data | Base64 encoded certificate data |
| cluster_oidc_issuer_url | OIDC provider URL for IRSA |
| oidc_provider_arn | ARN of OIDC provider for IRSA |

## IRSA (IAM Roles for Service Accounts)

### What is IRSA?
IRSA allows Kubernetes pods to assume IAM roles without:
- Storing AWS credentials in secrets
- Using EC2 instance profiles
- Managing access keys

### How It Works
1. EKS creates OIDC identity provider
2. Service account annotated with IAM role ARN
3. Pod uses service account
4. AWS STS exchanges OIDC token for temporary AWS credentials

### Best Practices
1. **One role per application** - Avoid shared roles
2. **Least privilege** - Grant minimal permissions needed
3. **Namespace isolation** - Use `oidc_fully_qualified_subjects`
4. **Audit regularly** - Review IAM role usage in CloudTrail

### Example: S3 Access
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: s3-app-sa
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/s3-app-role
---
apiVersion: v1
kind: Pod
metadata:
  name: s3-app
spec:
  serviceAccountName: s3-app-sa
  containers:
  - name: app
    image: my-app:latest
    env:
    - name: AWS_ROLE_ARN
      value: arn:aws:iam::123456789012:role/s3-app-role
    - name: AWS_WEB_IDENTITY_TOKEN_FILE
      value: /var/run/secrets/eks.amazonaws.com/serviceaccount/token
```

## Security Best Practices

### 1. Private Cluster
```hcl
cluster_endpoint_public_access  = false
cluster_endpoint_private_access = true
```

### 2. Encryption at Rest
```hcl
cluster_encryption_config = {
  enabled = true
  kms_key_arn = aws_kms_key.eks.arn
  resources   = ["secrets"]
}
```

### 3. Control Plane Logging
```hcl
cluster_enabled_log_types = [
  "api",              # API server requests
  "audit",            # Audit logs
  "authenticator",    # Authentication attempts
  "controllerManager",# Controller manager
  "scheduler"         # Scheduler
]
```

### 4. Network Policies
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

### 5. Pod Security Standards
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: my-app
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

## Accessing the Cluster

### Update kubeconfig
```bash
aws eks update-kubeconfig \
  --region ap-southeast-1 \
  --name my-eks-dev \
  --profile myprofile
```

### Verify Access
```bash
kubectl get nodes
kubectl get pods -A
kubectl cluster-info
```

## Troubleshooting

### Can't Access Cluster
1. Check AWS credentials: `aws sts get-caller-identity`
2. Update kubeconfig: `aws eks update-kubeconfig ...`
3. Verify IAM permissions for `eks:DescribeCluster`

### Pods Can't Assume IAM Role
1. Verify OIDC provider exists
2. Check ServiceAccount annotation
3. Validate IAM role trust policy includes OIDC provider
4. Ensure pod uses correct ServiceAccount

### Node Registration Failed
1. Check VPC CNI configuration
2. Verify subnet tags for EKS
3. Review security group rules
4. Check IAM instance profile for nodes

## Cost Optimization

### Cluster Costs
- **Control Plane:** $0.10/hour (~$73/month)
- **Worker Nodes:** EC2 pricing
- **Data Transfer:** Varies by usage
- **CloudWatch Logs:** ~$0.50/GB ingested

### Recommendations
1. Use Spot Instances for non-critical workloads
2. Enable Cluster Autoscaler
3. Limit control plane logging in dev
4. Use lifecycle hooks for graceful node termination

## Monitoring

### CloudWatch Metrics
```bash
# CPU Utilization
aws cloudwatch get-metric-statistics \
  --namespace AWS/EKS \
  --metric-name node_cpu_utilization \
  --dimensions Name=ClusterName,Value=my-eks-dev \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-02T00:00:00Z \
  --period 3600 \
  --statistics Average
```

### Prometheus Metrics
```yaml
apiVersion: v1
kind: ServiceMonitor
metadata:
  name: eks-metrics
spec:
  selector:
    matchLabels:
      app: kube-state-metrics
  endpoints:
  - port: metrics
    interval: 30s
```

## Upgrade Strategy

### 1. Check Compatibility
```bash
kubectl version --short
aws eks describe-addon-versions --kubernetes-version 1.34
```

### 2. Update Cluster
```hcl
cluster_version = "1.34"  # Update in terraform
```

### 3. Update Add-ons
```bash
# Update CoreDNS
aws eks update-addon \
  --cluster-name my-eks-dev \
  --addon-name coredns \
  --addon-version v1.11.1-eksbuild.9
```

### 4. Update Node Groups
- Create new node group with new version
- Cordon and drain old nodes
- Delete old node group

## Dependencies

- AWS Provider >= 5.0
- Terraform >= 1.5.0
- kubectl >= 1.28

## References

- [EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/)
- [IRSA Documentation](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
