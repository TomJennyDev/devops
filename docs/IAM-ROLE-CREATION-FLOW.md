# AWS Load Balancer Controller - IAM Role Creation Flow

## 🔄 Khi nào IAM Role được tạo?

**IAM Role `eks.amazonaws.com/role-arn` được tạo tự động bởi Terraform khi chạy `terraform apply`**

---

## 📊 Creation Flow:

```
1. terraform apply
   ↓
2. Module: eks (create cluster + OIDC provider)
   ├─ EKS Cluster: my-eks-dev
   ├─ OIDC Provider: oidc.eks.ap-southeast-1.amazonaws.com/id/XXXXX
   └─ OIDC URL: extracted from cluster
   ↓
3. Module: alb_controller (depends_on eks)
   ├─ Create IAM Role: aws_iam_role.aws_load_balancer_controller
   │  ├─ Name: my-eks-dev-aws-load-balancer-controller
   │  ├─ Trust Policy: AssumeRoleWithWebIdentity
   │  └─ Principal: OIDC Provider from step 2
   │
   ├─ Create IAM Policy: aws_iam_policy.aws_load_balancer_controller
   │  ├─ Name: my-eks-dev-aws-load-balancer-controller
   │  └─ Permissions: EC2, ELB, ACM, WAF, Shield, etc.
   │
   └─ Attach Policy to Role: aws_iam_role_policy_attachment
   ↓
4. Output: aws_load_balancer_controller_role_arn
   └─ arn:aws:iam::372836560690:role/my-eks-dev-aws-load-balancer-controller
```

---

## 🎯 Terraform Code Flow:

### **Step 1: Root main.tf calls module**
```terraform
# terraform-eks/main.tf (line 138)
module "alb_controller" {
  source = "./modules/alb-controller"
  
  cluster_name       = var.cluster_name              # "my-eks-dev"
  oidc_provider_arn  = module.eks.oidc_provider_arn  # From EKS module
  oidc_provider_url  = module.eks.oidc_provider_url  # From EKS module
  enable_aws_load_balancer_controller = true
  
  depends_on = [module.eks]  # ← Must create EKS first!
}
```

### **Step 2: Module creates IAM Role**
```terraform
# modules/alb-controller/main.tf (line 10)
resource "aws_iam_role" "aws_load_balancer_controller" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0
  
  # Role name format: {cluster_name}-aws-load-balancer-controller
  name = "${var.cluster_name}-aws-load-balancer-controller"
  # Result: "my-eks-dev-aws-load-balancer-controller"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = {
        # Trust EKS cluster's OIDC provider
        Federated = var.oidc_provider_arn
        # arn:aws:iam::372836560690:oidc-provider/oidc.eks...
      }
      Condition = {
        StringEquals = {
          # Only allow Kubernetes ServiceAccount from kube-system namespace
          "${var.oidc_provider_url}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          "${var.oidc_provider_url}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}
```

### **Step 3: Output ARN**
```terraform
# modules/alb-controller/outputs.tf (line 1)
output "aws_load_balancer_controller_role_arn" {
  value = aws_iam_role.aws_load_balancer_controller[0].arn
  # arn:aws:iam::372836560690:role/my-eks-dev-aws-load-balancer-controller
}

# terraform-eks/outputs.tf (line 117)
output "aws_load_balancer_controller_role_arn" {
  value = module.alb_controller.aws_load_balancer_controller_role_arn
}
```

---

## 🔐 IRSA (IAM Roles for Service Accounts) Mechanism:

```
┌─────────────────────────────────────────────────┐
│  1. Kubernetes ServiceAccount                   │
│  (kube-system/aws-load-balancer-controller)     │
│                                                  │
│  annotations:                                    │
│    eks.amazonaws.com/role-arn:                  │
│      arn:aws:iam::xxx:role/...                  │
└────────────────┬────────────────────────────────┘
                 │
                 │ ① Pod starts with SA
                 ↓
┌─────────────────────────────────────────────────┐
│  2. EKS injects AWS credentials                 │
│  (via projected volume)                         │
│                                                  │
│  Environment variables:                         │
│    AWS_ROLE_ARN=arn:aws:iam::xxx:role/...      │
│    AWS_WEB_IDENTITY_TOKEN_FILE=/var/run/.../   │
└────────────────┬────────────────────────────────┘
                 │
                 │ ② Pod calls AWS STS
                 ↓
┌─────────────────────────────────────────────────┐
│  3. AWS STS AssumeRoleWithWebIdentity           │
│                                                  │
│  Verify:                                         │
│    - Token signed by EKS OIDC provider?         │
│    - ServiceAccount matches condition?          │
│    - Namespace = kube-system?                   │
└────────────────┬────────────────────────────────┘
                 │
                 │ ③ STS returns credentials
                 ↓
┌─────────────────────────────────────────────────┐
│  4. Pod uses temporary credentials              │
│  (valid for 1 hour, auto-refresh)               │
│                                                  │
│  Pod can now call AWS APIs:                     │
│    - Create ALB                                 │
│    - Create Target Groups                       │
│    - Modify Security Groups                     │
└─────────────────────────────────────────────────┘
```

---

## 📋 Timeline:

| Time | Action | Who | Result |
|------|--------|-----|--------|
| **T+0min** | `terraform apply` | You | Start deployment |
| **T+1min** | Create EKS Cluster | Terraform | Cluster created |
| **T+2min** | Create OIDC Provider | Terraform | OIDC configured |
| **T+3min** | **Create IAM Role** | **Terraform** | **Role ARN generated** ← HERE! |
| **T+4min** | Create IAM Policy | Terraform | Permissions defined |
| **T+5min** | Attach Policy to Role | Terraform | Role ready to use |
| **T+15min** | Deploy Node Groups | Terraform | Nodes join cluster |
| **T+20min** | Terraform complete | Terraform | Output role ARN |
| **Later** | Deploy ALB Controller | Helm/ArgoCD | Use role ARN |

---

## 🔍 Verify IAM Role Created:

### **Via Terraform:**
```bash
cd terraform-eks/environments/dev
terraform output aws_load_balancer_controller_role_arn

# Output:
# arn:aws:iam::372836560690:role/my-eks-dev-aws-load-balancer-controller
```

### **Via AWS CLI:**
```bash
# List IAM roles for ALB Controller
aws iam list-roles --query 'Roles[?contains(RoleName, `load-balancer-controller`)].RoleName'

# Get specific role
aws iam get-role --role-name my-eks-dev-aws-load-balancer-controller

# Check trust policy (OIDC)
aws iam get-role --role-name my-eks-dev-aws-load-balancer-controller \
  --query 'Role.AssumeRolePolicyDocument'
```

### **Via AWS Console:**
```
IAM → Roles → Search: "my-eks-dev-aws-load-balancer-controller"

You'll see:
- Trust relationships: OIDC provider
- Permissions: Load balancer controller policy
- Tags: Created by Terraform
```

---

## ⚙️ IAM Role Configuration:

### **Trust Policy (Who can assume this role):**
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::372836560690:oidc-provider/oidc.eks.ap-southeast-1.amazonaws.com/id/XXXXX"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "oidc.eks.ap-southeast-1.amazonaws.com/id/XXXXX:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller",
        "oidc.eks.ap-southeast-1.amazonaws.com/id/XXXXX:aud": "sts.amazonaws.com"
      }
    }
  }]
}
```

**Translation:**
- Only pods in `kube-system` namespace
- With ServiceAccount `aws-load-balancer-controller`
- Can assume this IAM role
- Authentication via EKS OIDC provider

### **Permissions Policy (What this role can do):**
```json
{
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:CreateLoadBalancer",
        "elasticloadbalancing:DeleteLoadBalancer",
        "elasticloadbalancing:CreateTargetGroup",
        "ec2:CreateSecurityGroup",
        "ec2:AuthorizeSecurityGroupIngress",
        "acm:DescribeCertificate",
        "wafv2:AssociateWebACL",
        ...
      ],
      "Resource": "*"
    }
  ]
}
```

---

## ✅ Summary:

**IAM Role được tạo khi:**
- ✅ Chạy `terraform apply` trong `terraform-eks/environments/dev/`
- ✅ Module `alb_controller` được execute (sau khi EKS cluster ready)
- ✅ Tự động tạo với naming: `{cluster_name}-aws-load-balancer-controller`

**Sử dụng role này khi:**
- ✅ Deploy ALB Controller Helm chart (via ArgoCD hoặc Helm)
- ✅ ServiceAccount annotation: `eks.amazonaws.com/role-arn`
- ✅ Controller pod tự động assume role qua IRSA

**Không cần tạo manual** - Terraform handles everything! 🎯
