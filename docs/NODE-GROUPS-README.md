# Node Groups Configuration Guide

File `node-groups.tf` chứa tất cả cấu hình cho EKS Node Groups (EC2 workers).

## 📁 Cấu trúc Files

```
terraform-eks/
├── eks.tf              # EKS Control Plane & Addons
├── node-groups.tf      # ⭐ EC2 Node Groups (THIS FILE)
├── vpc.tf              # Network infrastructure
├── iam.tf              # IAM roles
├── security-groups.tf  # Security groups
├── variables.tf        # All variables
└── outputs.tf          # Output values
```

---

## 🎯 Node Groups trong file này

### 1. **Main Node Group** (Active)
- Mặc định: ON_DEMAND, t3.medium
- Có thể customize qua `terraform.tfvars`

### 2. **Spot Node Group** (Commented)
- 70% rẻ hơn ON_DEMAND
- Mixed instance types
- Uncomment để enable

### 3. **GPU Node Group** (Commented)
- Dành cho ML/AI workloads
- g4dn.xlarge với NVIDIA GPU
- Uncomment để enable

### 4. **ARM Node Group** (Commented)
- AWS Graviton processors
- 20% rẻ hơn x86
- Uncomment để enable

---

## 🚀 Quick Start

### Enable Main Node Group (Default)

Edit `terraform.tfvars`:
```hcl
node_group_name      = "general-nodes"
node_instance_types  = ["t3.medium"]
node_capacity_type   = "ON_DEMAND"
node_desired_size    = 2
node_max_size        = 4
node_min_size        = 1
```

Apply:
```bash
terraform apply
```

---

## 💰 Enable Spot Node Group (Cost Saving)

### Step 1: Uncomment trong `node-groups.tf`

Tìm section:
```terraform
/*
resource "aws_eks_node_group" "spot" {
  ...
}
*/
```

Remove `/*` và `*/`

### Step 2: Apply

```bash
terraform apply
```

**💵 Savings: ~$42/month (70% cheaper than ON_DEMAND)**

### Step 3: Deploy workload to Spot

```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      nodeSelector:
        capacity-type: spot
```

---

## 🎮 Enable GPU Node Group (ML/AI)

### Step 1: Uncomment GPU node group

```terraform
/*
resource "aws_eks_node_group" "gpu" {
  ...
}
*/
```

Remove `/*` và `*/`

### Step 2: Apply

```bash
terraform apply
```

### Step 3: Deploy GPU workload

```yaml
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: gpu-container
    resources:
      limits:
        nvidia.com/gpu: 1
  tolerations:
  - key: nvidia.com/gpu
    operator: Equal
    value: "true"
    effect: NoSchedule
  nodeSelector:
    nvidia-gpu: "true"
```

**💵 Cost: ~$380/month (ON_DEMAND) or ~$115/month (SPOT)**

---

## 🔧 Enable ARM Node Group (Graviton)

### Step 1: Uncomment ARM node group

### Step 2: Apply

```bash
terraform apply
```

### Step 3: Deploy to ARM nodes

```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      nodeSelector:
        architecture: arm64
```

**💵 Savings: 20% cheaper than x86**

---

## 📝 Add Custom Node Group

### Example: High-Memory Nodes

Add to `node-groups.tf`:

```terraform
resource "aws_eks_node_group" "memory_optimized" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "memory-nodes"
  node_role_arn   = aws_iam_role.eks_node.arn
  subnet_ids      = aws_subnet.eks_subnet_private[*].id
  version         = var.cluster_version

  scaling_config {
    desired_size = 1
    max_size     = 3
    min_size     = 0
  }

  update_config {
    max_unavailable = 1
  }

  ami_type       = "AL2023_x86_64_STANDARD"
  capacity_type  = "ON_DEMAND"
  disk_size      = 30
  instance_types = ["r5.large"]  # 2 vCPU, 16GB RAM

  labels = {
    role          = "memory-optimized"
    workload-type = "cache"
  }

  tags = merge(
    {
      Name = "${var.cluster_name}-memory-nodes"
    },
    var.tags
  )

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_ecr_policy
  ]

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [scaling_config[0].desired_size]
  }
}
```

---

## 🎯 Best Practices

### 1. **Separate Node Groups by Workload**

```
✅ general-nodes:    Regular apps (ON_DEMAND)
✅ spot-nodes:       Stateless apps (SPOT)
✅ gpu-nodes:        ML/AI workloads (SPOT GPU)
✅ memory-nodes:     Caches, databases (ON_DEMAND)
```

### 2. **Use Mixed Instance Types**

```hcl
instance_types = ["t3.medium", "t3a.medium", "t2.medium"]
```

Tăng availability cho Spot instances.

### 3. **Set Min Size > 0 for Critical Workloads**

```hcl
# Critical node group
node_min_size = 2  # Always have 2 nodes

# Optional node group (GPU, etc)
node_min_size = 0  # Can scale to zero
```

### 4. **Use Labels for Routing**

```hcl
labels = {
  workload-type = "frontend"
  tier          = "web"
  cost-center   = "engineering"
}
```

### 5. **Use Taints for Dedicated Nodes**

```hcl
taint {
  key    = "dedicated"
  value  = "gpu"
  effect = "NoSchedule"
}
```

---

## 🔍 Monitoring Node Groups

### Check node groups
```bash
kubectl get nodes --show-labels
aws eks list-nodegroups --cluster-name my-eks-cluster
```

### Check node group details
```bash
aws eks describe-nodegroup \
  --cluster-name my-eks-cluster \
  --nodegroup-name general-nodes
```

### Check node capacity
```bash
kubectl top nodes
kubectl describe nodes
```

---

## 💡 Common Configurations

### Development (Minimum Cost)
```hcl
# Only main node group
node_instance_types = ["t3.small"]
node_capacity_type  = "SPOT"
node_desired_size   = 1
node_min_size       = 1
node_max_size       = 2
```
**💵 ~$7/month**

---

### Production (Standard)
```hcl
# Main: ON_DEMAND
node_instance_types = ["t3.medium"]
node_capacity_type  = "ON_DEMAND"
node_desired_size   = 3
node_min_size       = 2
node_max_size       = 10

# Spot: Cost optimization (uncomment spot node group)
# 70% cheaper for non-critical workloads
```
**💵 ~$90/month (main) + ~$25/month (spot)**

---

### ML/AI Workload
```hcl
# Main: General workloads
node_instance_types = ["t3.medium"]
node_desired_size   = 2

# GPU: ML workloads (uncomment gpu node group)
# Save 70% with SPOT
```
**💵 ~$60/month (main) + ~$115/month (GPU spot)**

---

## 🐛 Troubleshooting

### Nodes not appearing
```bash
# Check node group status
aws eks describe-nodegroup --cluster-name <name> --nodegroup-name <ng-name>

# Check IAM role
kubectl describe node <node-name>
```

### Pods not scheduling to specific node group
```bash
# Check node labels
kubectl get nodes --show-labels

# Check pod node selector
kubectl describe pod <pod-name>

# Add node selector to deployment
kubectl edit deployment <deployment-name>
```

### Spot instances terminating frequently
```bash
# Check termination notices
kubectl get events

# Solutions:
# 1. Use multiple instance types
# 2. Enable spot instance draining
# 3. Mix ON_DEMAND + SPOT
```

---

## 📊 Cost Comparison

| Node Group Type | Instance | Monthly Cost | Use Case |
|----------------|----------|--------------|----------|
| **Main (ON_DEMAND)** | t3.medium x2 | $60 | Production apps |
| **Spot** | t3.medium x2 | $18 | Non-critical apps |
| **GPU (ON_DEMAND)** | g4dn.xlarge | $380 | ML training |
| **GPU (SPOT)** | g4dn.xlarge | $115 | ML inference |
| **ARM (ON_DEMAND)** | t4g.medium x2 | $48 | Cost-optimized |

---

## 📚 References

- [EKS Node Groups](https://docs.aws.amazon.com/eks/latest/userguide/managed-node-groups.html)
- [EC2 Instance Types](https://aws.amazon.com/ec2/instance-types/)
- [Spot Instances](https://aws.amazon.com/ec2/spot/)
- [Node Taints & Tolerations](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/)

---

## ✅ Checklist

Before enabling additional node groups:

- [ ] Check AWS Service Quotas for instance types
- [ ] Verify subnet capacity (enough IPs)
- [ ] Set appropriate min/max sizes
- [ ] Configure auto-scaling if needed
- [ ] Add monitoring/alerts
- [ ] Test workload scheduling
- [ ] Document custom configurations
