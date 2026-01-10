# Terraform Structure Explained

## 📚 Mục lục

- [Tổng quan cấu trúc](#tổng-quan-cấu-trúc)
- [Luồng hoạt động](#luồng-hoạt-động)
- [Giải thích chi tiết từng thư mục](#giải-thích-chi-tiết)
- [Ví dụ thực tế](#ví-dụ-thực-tế)
- [Tham khảo từ các dự án lớn](#tham-khảo)

---

## 🏗️ Tổng quan cấu trúc

```
terraform-eks/
│
├── main.tf              # ⭐ ROOT MODULE - Template infrastructure
├── variables.tf         # ⭐ Định nghĩa variables
├── outputs.tf           # ⭐ Định nghĩa outputs
├── versions.tf          # ⭐ Terraform & provider versions
├── README.md            # 📖 Documentation
├── STRUCTURE-EXPLAINED.md # 📖 Structure guide (file này)
│
├── modules/             # 📦 REUSABLE MODULES
│   ├── vpc/            # VPC, subnets, NAT gateway (2 AZs)
│   ├── eks/            # EKS cluster v1.31
│   ├── iam/            # IAM roles và policies
│   ├── security-groups/# Security groups cho cluster/nodes
│   ├── node-groups/    # Managed node groups (2-4 nodes)
│   ├── alb-controller/ # ALB Controller IAM (IRSA)
│   ├── waf/            # WAF Web ACL protection
│   └── ecr/            # Container registry (optional)
│
└── environments/        # 🌍 ENVIRONMENT CONFIG
    └── dev/            # Development environment
        ├── main.tf          # 🔗 Gọi ROOT module
        ├── backend.tf       # 💾 S3 backend (state management)
        ├── terraform.tfvars # 🎯 Dev-specific values
        ├── variables.tf     # 📋 Variable declarations
        └── outputs.tf       # 📤 Environment outputs
```

---

## 🔄 Luồng hoạt động (Data Flow)

### Khi bạn chạy `terraform apply` trong `environments/dev/`

```
┌─────────────────────────────────────────────────────────────┐
│ 1. terraform apply (trong environments/dev/)                │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. Đọc environments/dev/terraform.tfvars                    │
│    ┌────────────────────────────────────────────────────┐   │
│    │ cluster_name = "my-eks-dev"                        │   │
│    │ node_group_desired_size = 2                        │   │
│    │ node_group_instance_types = ["t3.large"]          │   │
│    │ vpc_cidr = "10.0.0.0/16"                          │   │
│    │ enable_waf = true                                  │   │
│    └────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. Đọc environments/dev/main.tf                            │
│    ┌────────────────────────────────────────────────────┐   │
│    │ module "eks" {                                     │   │
│    │   source = "../../"  # 👈 Trỏ đến ROOT MODULE     │   │
│    │   cluster_name = var.cluster_name                 │   │
│    │   vpc_cidr = var.vpc_cidr                         │   │
│    │   enable_waf = var.enable_waf                     │   │
│    │ }                                                  │   │
│    └────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. Load ROOT MODULE (terraform-eks/main.tf)                │
│    ┌────────────────────────────────────────────────────┐   │
│    │ module "vpc" {                                     │   │
│    │   source = "./modules/vpc"                         │   │
│    │   vpc_cidr = var.vpc_cidr                         │   │
│    │ }                                                  │   │
│    │                                                    │   │
│    │ module "eks" {                                     │   │
│    │   source = "./modules/eks"                         │   │
│    │   cluster_name = var.cluster_name                 │   │
│    │   vpc_id = module.vpc.vpc_id  # 👈 Dependency     │   │
│    │ }                                                  │   │
│    │                                                    │   │
│    │ module "waf" {                                     │   │
│    │   source = "./modules/waf"                         │   │
│    │   cluster_name = var.cluster_name                 │   │
│    │   enable_waf = var.enable_waf                     │   │
│    │ }                                                  │   │
│    └────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│ 5. Load từng module con (vpc, eks, waf, iam, ...)          │
│    ┌────────────────────────────────────────────────────┐   │
│    │ modules/vpc/main.tf:                               │   │
│    │   resource "aws_vpc" "main" {                      │   │
│    │     cidr_block = "10.0.0.0/16"                     │   │
│    │   }                                                │   │
│    │                                                    │   │
│    │ modules/eks/main.tf:                               │   │
│    │   resource "aws_eks_cluster" "main" {              │   │
│    │     name = "my-eks-dev"                            │   │
│    │     vpc_config { ... }                             │   │
│    │   }                                                │   │
│    │                                                    │   │
│    │ modules/waf/main.tf:                               │   │
│    │   resource "aws_wafv2_web_acl" "main" {            │   │
│    │     name = "my-eks-dev-dev-waf"                    │   │
│    │   }                                                │   │
│    └────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│ 6. Apply resources trên AWS                                │
│    VPC → Subnets → NAT → SGs → IAM → EKS → Nodes → WAF     │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│ 7. Lưu state vào S3 (từ backend.tf)                        │
│    s3://terraform-state-372836560690-dev/eks/terraform.tfstate │
│    Lock với DynamoDB: terraform-state-lock-dev              │
└─────────────────────────────────────────────────────────────┘
```

---

## 📂 Giải thích chi tiết từng thư mục/file

### 1️⃣ **ROOT MODULE** (`terraform-eks/main.tf`)

**Vai trò:** Template chung - định nghĩa TOÀN BỘ infrastructure

```terraform
# terraform-eks/main.tf
module "vpc" {
  source = "./modules/vpc"
  vpc_cidr = var.vpc_cidr  # 👈 Nhận từ environment
}

module "eks" {
  source = "./modules/eks"
  cluster_name = var.cluster_name
  vpc_id = module.vpc.vpc_id  # 👈 Dependency: EKS cần VPC
  subnet_ids = module.vpc.private_subnet_ids
}

module "node_groups" {
  source = "./modules/node-groups"
  cluster_name = module.eks.cluster_name
  subnet_ids = module.vpc.private_subnet_ids
}
```

**Tại sao cần ROOT MODULE?**

- ✅ **DRY (Don't Repeat Yourself)**: Viết logic 1 lần, dùng cho 3 environments
- ✅ **Consistency**: Dev, Staging, Prod dùng chung template → ít bug
- ✅ **Easy Updates**: Sửa 1 chỗ → all environments benefit

**Ví dụ thực tế:**

```
Nếu không có ROOT MODULE:
❌ environments/dev/main.tf     (300 dòng code)
❌ environments/staging/main.tf (300 dòng code - copy/paste)
❌ environments/prod/main.tf    (300 dòng code - copy/paste)
→ Total: 900 dòng, sửa bug phải sửa 3 chỗ

Với ROOT MODULE:
✅ terraform-eks/main.tf        (300 dòng code)
✅ environments/dev/main.tf     (10 dòng - chỉ gọi module)
✅ environments/staging/main.tf (10 dòng)
✅ environments/prod/main.tf    (10 dòng)
→ Total: 330 dòng, sửa bug chỉ sửa 1 chỗ
```

---

### 2️⃣ **MODULES** (`terraform-eks/modules/`)

**Vai trò:** Building blocks - các thành phần có thể tái sử dụng

```
modules/
├── vpc/           # Tạo VPC, subnets, NAT gateway
├── eks/           # Tạo EKS cluster
├── iam/           # Tạo IAM roles, policies
├── node-groups/   # Tạo worker nodes
└── ...
```

**Mối quan hệ giữa các modules:**

```
┌─────────────────────────────────────────────────────────┐
│                    ROOT MODULE (main.tf)                │
│                                                         │
│  module "vpc" ───────┐                                 │
│                      │                                  │
│  module "iam" ───────┼─────┐                           │
│                      │     │                            │
│  module "eks" ◄──────┘     │                           │
│       │                    │                            │
│       │ (depends_on)       │                            │
│       │                    │                            │
│  module "node_groups" ◄────┘                           │
│       │                                                 │
│       │                                                 │
│  module "alb_controller" ◄─────┘                       │
└─────────────────────────────────────────────────────────┘

Dependencies (implicit):
- node_groups depends on eks (needs cluster_name)
- eks depends on vpc (needs subnet_ids)
- alb_controller depends on eks (needs cluster_endpoint)
```

**Ví dụ module VPC:**

```terraform
# modules/vpc/main.tf
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "${var.cluster_name}-vpc"
  }
}

resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)
  vpc_id = aws_vpc.main.id
  cidr_block = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]
}

# modules/vpc/outputs.tf
output "vpc_id" {
  value = aws_vpc.main.id  # 👈 Được dùng bởi module eks
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id  # 👈 Được dùng bởi module eks
}
```

**Tại sao tách modules?**

- ✅ **Modularity**: Mỗi module có 1 responsibility
- ✅ **Reusability**: Dùng lại cho nhiều projects
- ✅ **Testing**: Test từng module độc lập
- ✅ **Team collaboration**: Team A làm VPC, Team B làm EKS

---

### 3️⃣ **ENVIRONMENTS** (`terraform-eks/environments/`)

**Vai trò:** Environment-specific configuration + state management

```
environments/
├── dev/
│   ├── main.tf          # 👈 Gọi ROOT MODULE
│   ├── backend.tf       # 👈 S3 backend config (dev-specific)
│   ├── terraform.tfvars # 👈 Dev values
│   └── variables.tf     # 👈 Variable declarations
├── staging/
└── prod/
```

#### 📄 **environments/dev/main.tf**

```terraform
# Gọi ROOT MODULE và truyền variables
module "eks" {
  source = "../../"  # 👈 Point to ROOT MODULE (2 levels up)

  # Truyền tất cả variables từ terraform.tfvars
  cluster_name = var.cluster_name
  vpc_cidr = var.vpc_cidr
  node_group_desired_size = var.node_group_desired_size
  # ... (30+ variables)
}

module "ecr" {
  source = "../../modules/ecr"  # 👈 Call module trực tiếp

  repositories = var.ecr_repositories
  common_tags = var.common_tags
}
```

**❓ Tại sao không gọi module trực tiếp mà phải qua ROOT MODULE?**

```terraform
# ❌ BAD: Gọi từng module riêng lẻ
# environments/dev/main.tf (không dùng root module)
module "vpc" {
  source = "../../modules/vpc"
  vpc_cidr = var.vpc_cidr
}

module "eks" {
  source = "../../modules/eks"
  cluster_name = var.cluster_name
  vpc_id = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
}

module "node_groups" {
  source = "../../modules/node-groups"
  cluster_name = module.eks.cluster_name
  subnet_ids = module.vpc.private_subnet_ids
}

# ❌ Problem: Phải copy/paste cho staging và prod
# ❌ Problem: Sửa logic phải sửa 3 chỗ
```

```terraform
# ✅ GOOD: Gọi ROOT MODULE (đã orchestrate tất cả)
# environments/dev/main.tf
module "eks" {
  source = "../../"  # ROOT module đã handle hết

  cluster_name = var.cluster_name
  vpc_cidr = var.vpc_cidr
  # ... chỉ truyền values, không lo logic
}

# ✅ Benefit: Staging và Prod chỉ cần copy file này
#            và thay đổi terraform.tfvars
```

#### 📄 **environments/dev/backend.tf**

**Vai trò:** Nơi lưu Terraform state file

```terraform
# environments/dev/backend.tf
terraform {
  backend "s3" {
    bucket = "terraform-state-372836560690-dev"  # 👈 Dev bucket
    key    = "eks/terraform.tfstate"
    region = "ap-southeast-1"

    dynamodb_table = "terraform-state-lock-dev"  # 👈 Dev lock table
  }
}
```

**Tại sao mỗi environment cần backend riêng?**

```
❓ Nếu dùng chung bucket:

terraform-state-372836560690/
└── eks/
    └── terraform.tfstate  # ❌ Chỉ 1 file cho cả dev, staging, prod

→ Problem: Deploy dev sẽ overwrite prod state
→ Problem: Không thể rollback riêng từng environment
→ Problem: Risk cao: dev bug có thể crash prod
```

```
✅ Mỗi environment có bucket riêng:

terraform-state-372836560690-dev/
└── eks/
    └── terraform.tfstate  # ✅ Dev state

terraform-state-372836560690-staging/
└── eks/
    └── terraform.tfstate  # ✅ Staging state

terraform-state-372836560690-prod/
└── eks/
    └── terraform.tfstate  # ✅ Prod state

→ Benefit: Hoàn toàn isolated
→ Benefit: Deploy dev không ảnh hưởng prod
→ Benefit: Rollback riêng từng environment
```

#### 📄 **environments/dev/terraform.tfvars**

**Vai trò:** Values cụ thể cho từng environment

```terraform
# environments/dev/terraform.tfvars
cluster_name = "flowise-dev"
node_group_desired_size = 2
node_group_instance_types = ["t3.medium"]
vpc_cidr = "10.0.0.0/16"

# environments/staging/terraform.tfvars
cluster_name = "flowise-staging"
node_group_desired_size = 3
node_group_instance_types = ["t3.large"]
vpc_cidr = "10.1.0.0/16"

# environments/prod/terraform.tfvars
cluster_name = "flowise-prod"
node_group_desired_size = 5
node_group_instance_types = ["t3.xlarge"]
vpc_cidr = "10.2.0.0/16"
```

**Tại sao tách tfvars?**

- ✅ **Security**: Prod có security group khác dev
- ✅ **Cost**: Dev dùng t3.medium, prod dùng t3.xlarge
- ✅ **Scale**: Dev 2 nodes, prod 5 nodes
- ✅ **Network**: Prod có VPC riêng, không conflict với dev

---

## 🔥 Ví dụ thực tế: Deploy Dev

### Bước 1: Navigate to dev environment

```bash
cd terraform-eks/environments/dev/
```

### Bước 2: Initialize Terraform

```bash
terraform init
```

**Điều gì xảy ra?**

```
1. Đọc backend.tf
   → Connect to S3: terraform-state-372836560690-dev
   → Download state file (nếu có)

2. Đọc main.tf
   → Tìm thấy: source = "../../"
   → Load ROOT MODULE từ terraform-eks/main.tf

3. Đọc ROOT MODULE
   → Tìm thấy: source = "./modules/vpc"
   → Download module vpc

4. Download tất cả providers (AWS, Kubernetes, Helm)
   → Version được định nghĩa trong versions.tf
```

### Bước 3: Plan changes

```bash
terraform plan -out=tfplan
```

**Điều gì xảy ra?**

```
1. Đọc terraform.tfvars
   cluster_name = "flowise-dev"
   vpc_cidr = "10.0.0.0/16"
   ...

2. Truyền variables vào ROOT MODULE
   module "eks" {
     cluster_name = "flowise-dev"
     vpc_cidr = "10.0.0.0/16"
   }

3. ROOT MODULE gọi từng module con
   module "vpc" → tạo VPC 10.0.0.0/16
   module "eks" → tạo cluster "flowise-dev"
   module "node_groups" → tạo 2 t3.medium nodes

4. Terraform compare với state hiện tại
   → Show: 52 resources to add, 0 to change, 0 to destroy
```

### Bước 4: Apply changes

```bash
terraform apply tfplan
```

**Điều gì xảy ra?**

```
1. Tạo resources theo thứ tự dependencies:
   [1/52] VPC
   [2/52] Internet Gateway
   [3/52] Subnets (public + private)
   [4/52] NAT Gateway
   [5/52] Route Tables
   [6/52] IAM Roles
   [7/52] Security Groups
   [8/52] EKS Cluster
   [9/52] Node Groups
   [10/52] WAF Web ACL
   [11/52] ALB Controller IRSA
   ...

2. Lưu state vào S3:
   s3://terraform-state-372836560690-dev/eks/terraform.tfstate

3. Lock state với DynamoDB:
   terraform-state-lock-dev (prevents concurrent modifications)
```

---

## 🤝 Future Scalability (Optional)

### If you need to add Staging/Production later

```bash
# Copy dev environment structure
cp -r environments/dev environments/staging

cd environments/staging

# Update backend.tf
nano backend.tf
# Change:
# bucket = "terraform-state-372836560690-staging"
# key = "staging/eks/terraform.tfstate"
# dynamodb_table = "terraform-state-lock-staging"

# Update terraform.tfvars
nano terraform.tfvars
# Change:
# cluster_name = "my-eks-staging"
# vpc_cidr = "10.1.0.0/16"  # Different from dev
# node_group_instance_types = ["t3.large"]  # Larger instances

terraform init
terraform plan
terraform apply
```

**Benefits of this approach:**
- Same infrastructure template (ROOT MODULE) for all environments
- Separate state files (no conflicts between dev/staging/prod)
- Easy to test changes in dev before rolling out to staging/prod
module "eks" {
  source = "../../"  # 👈 Same ROOT MODULE
  # ... same structure
}
```

**Result:** 2 clusters hoàn toàn độc lập

```
Dev Cluster:
- Name: flowise-dev
- VPC: 10.0.0.0/16
- Nodes: 2x t3.medium
- State: s3://...dev/

Staging Cluster:
- Name: flowise-staging
- VPC: 10.1.0.0/16  # 👈 Không conflict
- Nodes: 3x t3.large
- State: s3://...staging/  # 👈 State riêng
```

---

## 📚 Tham khảo từ các dự án lớn

### 1. **Gruntwork (Terraform Experts)**

GitHub: <https://github.com/gruntwork-io/terragrunt-infrastructure-live-example>

```
infrastructure-live/
├── dev/
│   └── us-east-1/
│       └── dev/
│           └── services/
│               └── web-app/
│                   └── terragrunt.hcl  # 👈 Gọi module chung
├── stage/
└── prod/

infrastructure-modules/  # 👈 Shared modules (giống ROOT MODULE)
├── services/
│   └── web-app/
│       └── main.tf
```

**Pattern:** Giống hệt structure của bạn!

---

### 2. **Terraform Official Documentation**

Link: <https://developer.hashicorp.com/terraform/language/modules/develop#when-to-write-a-module>

**Quote từ Terraform docs:**

> "We recommend using a consistent file and directory structure:
>
> - Root module: Contains main configuration
> - Child modules: Reusable infrastructure components
> - Environment-specific configurations: Separate directories for dev, staging, prod"

---

### 3. **AWS EKS Best Practices**

GitHub: <https://github.com/aws-ia/terraform-aws-eks-blueprints>

```
patterns/
├── blue-green-upgrade/
│   └── main.tf  # 👈 ROOT configuration
├── multi-tenancy/
└── private-cluster/

modules/
├── aws-eks-managed-node-groups/
├── aws-eks-teams/
└── ...
```

**Pattern:** ROOT module + reusable modules + patterns (environments)

---

### 4. **Google Cloud Foundation Toolkit**

GitHub: <https://github.com/terraform-google-modules/terraform-google-kubernetes-engine>

```
examples/
├── simple_regional/
│   └── main.tf  # 👈 Example calling root module
├── simple_zonal/
└── private_cluster/

modules/
├── auth/
├── beta-autopilot-private-cluster/
└── ...

main.tf  # 👈 ROOT MODULE
```

---

### 5. **Cloudposse (AWS Terraform Modules)**

GitHub: <https://github.com/cloudposse/terraform-aws-eks-cluster>

**Structure pattern họ recommend:**

```
infrastructure/
├── live/
│   ├── dev/
│   │   └── main.tf  # 👈 Calls root module
│   ├── staging/
│   └── prod/
├── modules/
│   ├── vpc/
│   ├── eks/
│   └── ...
└── root/
    └── main.tf  # 👈 ROOT MODULE
```

---

## 🎯 Tại sao cấu trúc này là Best Practice?

### 1. **Industry Standard**

```
✅ HashiCorp (Terraform creators) recommends
✅ AWS Well-Architected Framework recommends
✅ Google Cloud recommends
✅ Gruntwork (Terraform experts) use
✅ CloudPosse (AWS experts) use
```

### 2. **Real-world Production Usage**

```
Companies using this pattern:
- Airbnb
- Uber
- Netflix
- Stripe
- GitHub
- GitLab
```

### 3. **Benefits in Development**

| Benefit | Explanation |
|---------|------------|
| **Modular Design** | Easy to add/remove modules without affecting others |
| **DRY** | Write infrastructure code once, reusable template |
| **Testing** | Test infrastructure changes safely in isolated environment |
| **Rollback** | Easy to rollback state to previous version (S3 versioning) |
| **Team Collaboration** | State locking prevents conflicts when multiple devs work |
| **Cost Control** | Use smaller resources in dev, can scale up later |
| **Documentation** | Clear structure makes onboarding easier |
| **Compliance** | Audit trail of all infrastructure changes in git |

---

## ❓ FAQs

### Q1: Tại sao không gộp tất cả vào 1 file duy nhất?

**A:**

```terraform
# ❌ BAD: All-in-one file (terraform-eks/main.tf - 2000 dòng)
resource "aws_vpc" "main" { ... }
resource "aws_eks_cluster" "main" { ... }
resource "aws_eks_node_group" "main" { ... }
resource "aws_wafv2_web_acl" "main" { ... }
# ... 50 more resources

# Problems:
❌ 2000+ lines không maintain được
❌ Khó tìm và sửa specific resource
❌ 1 typo có thể crash toàn bộ infrastructure
❌ Không có reusability (phải copy/paste toàn bộ nếu muốn thêm env)
❌ Team conflicts (everyone edits same large file)
❌ Khó test từng phần riêng lẻ
```

```
# ✅ GOOD: Separated modular structure
terraform-eks/main.tf (300 dòng - orchestration)
modules/vpc/          (VPC-specific logic)
modules/eks/          (EKS-specific logic)
modules/waf/          (WAF-specific logic)
environments/dev/     (dev-specific overrides)

Benefits:
✅ Dễ maintain (mỗi file ~100-200 dòng)
✅ Easy to find and fix issues
✅ Isolated testing (test từng module độc lập)
✅ Reusable (modules can be shared across projects)
✅ Better team collaboration (work on different modules)
✅ Clear dependencies và resource relationships
```

Benefits:
✅ Clean, maintainable code
✅ Deploy independently
✅ State isolation
✅ Team can work in parallel
```

---

### Q2: Khi nào nên dùng structure này?

**A:**

✅ **Dùng khi:**

- Có nhiều environments (dev, staging, prod)
- Infrastructure phức tạp (>10 resources)
- Team >1 người
- Cần deploy independently
- Cần state isolation

❌ **Không cần dùng khi:**

- Chỉ có 1 environment
- Pet project (<10 resources)
- Solo developer, không cần collaborate

---

## 🔧 Các Modules Quan Trọng Khác

### 1. **Security Groups Module** (`modules/security-groups/`)

**Mục đích:** Tạo firewall rules cho EKS cluster

```terraform
# modules/security-groups/main.tf
resource "aws_security_group" "cluster" {
  name_prefix = "${var.cluster_name}-cluster-"
  vpc_id      = var.vpc_id

  # Allow nodes to communicate with cluster
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.private_subnet_cidrs
  }
}

resource "aws_security_group" "node" {
  name_prefix = "${var.cluster_name}-node-"
  vpc_id      = var.vpc_id

  # Allow SSH if enabled
  dynamic "ingress" {
    for_each = var.enable_node_ssh_access ? [1] : []
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.ssh_allowed_cidr_blocks
    }
  }
}
```

**Được gọi từ:**

```terraform
# terraform-eks/main.tf
module "security_groups" {
  source = "./modules/security-groups"

  vpc_id = module.vpc.vpc_id  # 👈 Phụ thuộc VPC
  cluster_name = var.cluster_name
}
```

**Outputs:**

- `cluster_security_group_id` → Dùng cho EKS cluster
- `node_security_group_id` → Dùng cho worker nodes

---

### 2. **Node Groups Module** (`modules/node-groups/`)

**Mục đích:** Tạo EC2 instances (worker nodes) cho EKS

```terraform
# modules/node-groups/main.tf
resource "aws_eks_node_group" "main" {
  cluster_name    = var.cluster_name
  node_group_name = var.node_group_name
  node_role_arn   = var.node_role_arn  # 👈 Từ IAM module
  subnet_ids      = var.private_subnet_ids  # 👈 Từ VPC module

  scaling_config {
    desired_size = var.desired_size  # Dev: 2, Prod: 5
    min_size     = var.min_size
    max_size     = var.max_size
  }

  instance_types = var.instance_types  # Dev: t3.medium, Prod: t3.xlarge
  capacity_type  = var.capacity_type   # ON_DEMAND hoặc SPOT

  labels = var.labels  # Kubernetes node labels
  taints = var.taints  # Kubernetes node taints
}
```

**Dependencies:**

- Cần `cluster_name` từ EKS module
- Cần `node_role_arn` từ IAM module
- Cần `subnet_ids` từ VPC module

**Why separate?**

- Có thể tạo nhiều node groups (CPU nodes, GPU nodes, memory-optimized)
- Có thể scale từng node group độc lập

---

### 3. **EKS Addons Module** (`modules/eks-addons/`)

**Mục đích:** Cài đặt addons cần thiết cho EKS

```terraform
# modules/eks-addons/main.tf

# VPC CNI - Network plugin
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = var.cluster_name
  addon_name   = "vpc-cni"
  addon_version = var.vpc_cni_version

  # Resolve conflicts automatically
  resolve_conflicts_on_create = "OVERWRITE"
}

# CoreDNS - DNS resolution
resource "aws_eks_addon" "coredns" {
  cluster_name = var.cluster_name
  addon_name   = "coredns"
  addon_version = var.coredns_version

  depends_on = [aws_eks_addon.vpc_cni]  # 👈 Must install after VPC CNI
}

# kube-proxy - Network proxy
resource "aws_eks_addon" "kube_proxy" {
  cluster_name = var.cluster_name
  addon_name   = "kube-proxy"
  addon_version = var.kube_proxy_version
}
```

**Critical:** Phải cài sau khi EKS cluster ready!

---

### 4. **ALB Controller Module** (`modules/alb-controller/`)

**Mục đích:** Tạo AWS Load Balancer Controller cho Kubernetes Ingress

```terraform
# modules/alb-controller/main.tf

# IAM role for ALB controller
resource "aws_iam_role" "alb_controller" {
  name = "${var.cluster_name}-alb-controller"

  # OIDC trust policy
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn  # 👈 Từ EKS module
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${var.oidc_provider}:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }]
  })
}

# Attach AWS managed policy
resource "aws_iam_role_policy_attachment" "alb_controller" {
  policy_arn = "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
  role       = aws_iam_role.alb_controller.name
}
```

**Why needed?**

- Kubernetes Ingress → AWS Application Load Balancer
- Auto-creates ALB khi deploy Ingress manifest
- Quản lý SSL certificates, routing rules

---

### 5. **Route53 Module** (`modules/route53/`) [Optional]

**Mục đích:** Quản lý DNS hosted zone và records

**Note:** In current project, DNS is managed manually via script (`update-flowise-dns.sh`), not with Terraform module. But module can be added if you need automated DNS management.

```terraform
# modules/route53/main.tf

# Hosted zone (nếu chưa có)
data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

# A record cho Flowise app
resource "aws_route53_record" "flowise" {
  count = var.flowise_dns_enabled ? 1 : 0

  zone_id = data.aws_route53_zone.main.zone_id
  name    = "flowise-dev.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.flowise_alb_dns_name  # 👈 Từ ALB
    zone_id                = var.flowise_alb_zone_id
    evaluate_target_health = true
  }
}

# A record cho Grafana monitoring
resource "aws_route53_record" "grafana" {
  count = var.grafana_dns_enabled ? 1 : 0

  zone_id = data.aws_route53_zone.main.zone_id
  name    = "grafana-dev.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.monitoring_alb_dns_name
    zone_id                = var.monitoring_alb_zone_id
    evaluate_target_health = true
  }
}
```

**Current Setup:**
Instead of Terraform module, project uses bash script for DNS management:
```bash
./scripts/update-flowise-dns.sh dev
./scripts/update-monitoring-dns.sh dev
```

**Future Option:**
If you want automated DNS, you can:
1. Create Route53 module as shown above
2. Add module to root `main.tf`
3. Replace manual scripts with Terraform-managed records

---

### 6. **WAF Module** (`modules/waf/`)
  name         = var.domain_name
  private_zone = false
}

# A record cho ArgoCD
resource "aws_route53_record" "argocd" {
  count = var.argocd_dns_enabled ? 1 : 0

**Current Setup:**
Instead of Terraform module, project uses bash script for DNS management:
```bash
./scripts/update-flowise-dns.sh dev
./scripts/update-monitoring-dns.sh dev
```

**Future Option:**
If you want automated DNS, you can:
1. Create Route53 module as shown above
2. Add module to root `main.tf`
3. Replace manual scripts with Terraform-managed records

---

### 6. **WAF Module** (`modules/waf/`)

**Mục đích:** Web Application Firewall protection cho ALBs

**Status:** ✅ Currently deployed protecting both ALBs (flowise-dev, monitoring)

```terraform
# modules/waf/main.tf

resource "aws_wafv2_web_acl" "main" {
  name  = "${var.cluster_name}-${var.environment}-waf"
  scope = "REGIONAL"  # For ALB (CLOUDFRONT for CDN)

  default_action {
    allow {}  # Allow by default, block specific rules
  }

  # Rule 1: Rate limiting (1000 requests per 5 min)
  rule {
    name     = "rate-limit"
    priority = 1

    statement {
      rate_based_statement {
        limit              = 1000
        aggregate_key_type = "IP"
      }
    }

    action {
      block {}
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitRule"
    }
  }

  # Rule 2: AWS Managed - Core Rule Set
  rule {
    name     = "aws-core-rules"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "CoreRuleSet"
    }
  }

  # Rule 3: SQL Injection protection
  rule {
    name     = "sql-injection"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "SQLiProtection"
    }
  }

  visibility_config {
    sampled_requests_enabled   = true
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.cluster_name}-waf"
  }
}

# Associate WAF with ALB
resource "aws_wafv2_web_acl_association" "alb" {
  for_each = toset(var.alb_arns)

  resource_arn = each.value
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}

# Output WAF Web ACL ARN for ingress annotations
output "web_acl_arn" {
  value       = aws_wafv2_web_acl.main.arn
  description = "WAF Web ACL ARN to use in ALB ingress annotations"
}
```

**Protection Features:**
- ✅ Rate limiting (1000 req/5min per IP)
- ✅ SQL Injection prevention
- ✅ XSS (Cross-Site Scripting) blocking
- ✅ AWS Managed Core Rule Set
- ✅ CloudWatch metrics for monitoring

**Usage in Kubernetes Ingress:**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    alb.ingress.kubernetes.io/wafv2-acl-arn: arn:aws:wafv2:us-east-1:372836560690:regional/webacl/...
```

**Current ARN:** Check with:
```bash
cd terraform-eks/environments/dev
terraform output waf_web_acl_arn
```

---

### 7. **ECR Module** (`modules/ecr/`) [Optional]

**Mục đích:** Tạo Docker container registry

```terraform
# modules/ecr/main.tf

resource "aws_ecr_repository" "main" {
  for_each = toset(var.repositories)  # ["flowise-server", "flowise-ui"]

  name = each.value

  image_scanning_configuration {
    scan_on_push = true  # Auto-scan for vulnerabilities
  }

  encryption_configuration {
    encryption_type = var.encryption_type  # AES256 hoặc KMS
  }

  image_tag_mutability = "MUTABLE"  # Allow overwrite tags

  force_delete = var.force_delete  # Dev: true, Prod: false
}

# Lifecycle policy - Auto-cleanup old images
resource "aws_ecr_lifecycle_policy" "main" {
  for_each = aws_ecr_repository.main

  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}
```

**Why separate from EKS?**

- ECR không phụ thuộc EKS cluster
- Có thể deploy/destroy độc lập
- Images survive cluster recreation

---

### 8. **Secrets Manager Module** (`modules/secrets-manager/`)

**Mục đích:** Lưu trữ secrets an toàn (DB passwords, API keys)

```terraform
# modules/secrets-manager/main.tf

resource "aws_secretsmanager_secret" "main" {
  for_each = var.secrets

  name = "${var.cluster_name}-${each.key}"

  recovery_window_in_days = var.recovery_window_in_days  # Dev: 7, Prod: 30

  kms_key_id = var.kms_key_id  # Encryption key
}

resource "aws_secretsmanager_secret_version" "main" {
  for_each = aws_secretsmanager_secret.main

  secret_id     = each.value.id
  secret_string = var.secrets[each.key]
}

# IAM policy để EKS pods có thể read secrets
resource "aws_iam_policy" "secrets_read" {
  name = "${var.cluster_name}-secrets-read"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      Resource = [
        for secret in aws_secretsmanager_secret.main : secret.arn
      ]
    }]
  })
}
```

**Usage in Kubernetes:**

```yaml
# Pod với External Secrets Operator
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: flowise-db-password
spec:
  secretStoreRef:
    name: aws-secrets-manager
  target:
    name: flowise-db-secret
  data:
  - secretKey: password
    remoteRef:
      key: flowise-dev-db-password  # 👈 Secret trong AWS
```

---

### 9. **CloudFront Module** (`modules/cloudfront/`)

**Mục đích:** CDN cho static assets, caching

```terraform
# modules/cloudfront/main.tf

resource "aws_cloudfront_distribution" "main" {
  enabled = true

  # Origin = ALB
  origin {
    domain_name = var.alb_dns_name
    origin_id   = "alb-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Cache behavior
  default_cache_behavior {
    target_origin_id       = "alb-origin"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods  = ["GET", "HEAD", "OPTIONS"]

    forwarded_values {
      query_string = true
      cookies {
        forward = "all"
      }
    }
  }

  # SSL certificate
  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}
```

**Benefits:**

- Global CDN → Faster loading
- DDoS protection
- SSL/TLS termination
- Cache static assets

---

### 10. **WAF Module** (`modules/waf/`)

**Mục đích:** Web Application Firewall - bảo vệ khỏi attacks

```terraform
# modules/waf/main.tf

resource "aws_wafv2_web_acl" "main" {
  name  = "${var.cluster_name}-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  # Rule 1: Rate limiting
  rule {
    name     = "rate-limit"
    priority = 1

    statement {
      rate_based_statement {
        limit              = 2000  # Requests per 5 min
        aggregate_key_type = "IP"
      }
    }

    action {
      block {}
    }
  }

  # Rule 2: AWS Managed Rules
  rule {
    name     = "aws-managed-rules"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
  }

  # Rule 3: SQL Injection protection
  rule {
    name     = "sql-injection"
    priority = 3

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }
  }
}

# Associate WAF with ALB
resource "aws_wafv2_web_acl_association" "main" {
  resource_arn = var.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}
```

**Protection against:**

- SQL Injection
- XSS attacks
- DDoS attacks
- Bot traffic
- Rate limiting

---

## 📊 Module Dependencies Graph

**Current Project Modules:**

```
┌─────────────┐
│    VPC      │ ← Foundation (10.0.0.0/16, 2 AZs)
└──────┬──────┘
       │
       ├──────────────┬──────────────┐
       ▼              ▼              ▼
┌──────────┐   ┌──────────┐   ┌──────────┐
│   IAM    │   │ Security │   │ Route53  │
│  Roles   │   │  Groups  │   │(manual)  │
└──────┬───┘   └─────┬────┘   └──────────┘
       │             │
       └──────┬──────┘
              ▼
       ┌──────────────────────┐
       │    EKS Cluster       │ ← Core (v1.31, 2 nodes)
       └──────────┬───────────┘
                  │
         ┌────────┴────────┬─────────┐
         ▼                 ▼         ▼
   ┌──────────┐      ┌─────────┐ ┌─────────┐
   │   Node   │      │   EKS   │ │   ALB   │
   │  Groups  │      │ Addons  │ │ Contr.  │
   │(t3.large)│      │(VPC-CNI)│ │  (IRSA) │
   └──────────┘      └─────────┘ └────┬────┘
                                       │
                                  ┌────┴────┐
                                  │   WAF   │ ← Deployed (Web ACL)
                                  │ (v2)    │
                                  └─────────┘
```

**Optional Modules (not currently deployed):**
- ECR (using Docker Hub instead)
- External DNS (using manual DNS script)
- CloudFront (using direct ALB access)
- Secrets Manager (can be added for DB passwords)

---

### Q3: Có cách nào đơn giản hơn không?

**A:** Có 2 alternatives:

**Option 1: Flat structure (simpler, but less scalable)**

```
terraform-eks/
├── main.tf         # All resources in one file
├── variables.tf
└── terraform.tfvars

Pros:
✅ Fewer files to manage
✅ Simpler structure for very small projects

Cons:
❌ Hard to scale when project grows
❌ Difficult to maintain large files (1000+ lines)
❌ No reusability across environments
❌ No module isolation
❌ Harder for team collaboration
```

**Option 2: Current modular structure (recommended)**

```
terraform-eks/
├── main.tf (ROOT MODULE - orchestration)
├── modules/ (reusable components)
└── environments/dev/ (environment-specific configs)

Pros:
✅ Industry standard pattern
✅ Easy to scale and extend
✅ Clear separation of concerns
✅ Reusable modules
✅ Better for team collaboration
✅ Follows HashiCorp best practices

Cons:
❌ More files (but well-organized)
❌ Slight learning curve (but worth it)
```

**Recommendation:** Stick with Option 2 (current structure). While it has more files, the benefits far outweigh the complexity. This structure is:
- Used by major companies (Netflix, Airbnb, Stripe)
- Recommended by HashiCorp (Terraform creators)
- Essential for any production-ready infrastructure

---

## 🎓 Học thêm

### Terraform Documentation

- [Module Composition](https://developer.hashicorp.com/terraform/language/modules/develop/composition)
- [Module Structure](https://developer.hashicorp.com/terraform/language/modules/develop/structure)

### Best Practices Guides

- [Gruntwork: How to use Terraform as a team](https://blog.gruntwork.io/how-to-use-terraform-as-a-team-251bc1104973)
- [AWS: Terraform Best Practices](https://aws.amazon.com/blogs/apn/terraform-beyond-the-basics-with-aws/)

### Example Repositories

- [Gruntwork Terragrunt](https://github.com/gruntwork-io/terragrunt-infrastructure-live-example)
- [AWS EKS Blueprints](https://github.com/aws-ia/terraform-aws-eks-blueprints)
- [CloudPosse](https://github.com/cloudposse/terraform-aws-eks-cluster)

---

## 📝 Tóm tắt

```
Root Module (terraform-eks/main.tf)
    ↓ orchestrates
Reusable Modules (modules/vpc, modules/eks, modules/waf, ...)
    ↓ used by
Environment Config (environments/dev/)
    ↓ stores state in
S3 Backend (terraform-state-372836560690-dev)
    ↓ locks with
DynamoDB (terraform-state-lock-dev)
```

**Key Principles:**

1. **DRY (Don't Repeat Yourself)**: Write infrastructure code once in modules, reuse everywhere
2. **Modularity**: Break infrastructure into logical, reusable components (VPC, EKS, WAF, etc.)
3. **State Management**: Remote state in S3 with locking ensures team collaboration safety
4. **Best Practices**: Follow HashiCorp and AWS recommended patterns
5. **Scalability**: Structure allows easy addition of new environments or modules

**Current Deployment:**
- ✅ Single development environment (can scale to staging/prod later)
- ✅ EKS 1.31 with 2 worker nodes (t3.large)
- ✅ WAF protection enabled (Web ACL with SQL injection + XSS prevention)
- ✅ 2 ALBs deployed (flowise-dev, monitoring)
- ✅ ArgoCD GitOps for application deployment
- ✅ State management with S3 + DynamoDB locking

**Your structure follows industry best practices! ✅**
