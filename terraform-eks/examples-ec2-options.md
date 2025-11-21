# EC2 Node Group Options - Examples

## 📋 Tất cả options có sẵn cho EKS Nodes

### 1. **Instance Types** (node_instance_types)

```hcl
# General Purpose (Balanced CPU/Memory)
node_instance_types = ["t3.small"]      # 2 vCPU, 2GB RAM - $0.0208/hour
node_instance_types = ["t3.medium"]     # 2 vCPU, 4GB RAM - $0.0416/hour
node_instance_types = ["t3.large"]      # 2 vCPU, 8GB RAM - $0.0832/hour
node_instance_types = ["t3.xlarge"]     # 4 vCPU, 16GB RAM - $0.1664/hour
node_instance_types = ["t3a.medium"]    # AMD - rẻ hơn 10%

# Compute Optimized (High CPU)
node_instance_types = ["c5.large"]      # 2 vCPU, 4GB RAM - $0.085/hour
node_instance_types = ["c5.xlarge"]     # 4 vCPU, 8GB RAM - $0.17/hour
node_instance_types = ["c6i.large"]     # Intel gen mới nhất

# Memory Optimized (High RAM)
node_instance_types = ["r5.large"]      # 2 vCPU, 16GB RAM - $0.126/hour
node_instance_types = ["r5.xlarge"]     # 4 vCPU, 32GB RAM - $0.252/hour

# ARM-based (Graviton - rẻ hơn 20%)
node_instance_types = ["t4g.medium"]    # ARM, 2 vCPU, 4GB RAM - $0.0336/hour
node_instance_types = ["m6g.large"]     # ARM, 2 vCPU, 8GB RAM

# GPU (Machine Learning)
node_instance_types = ["g4dn.xlarge"]   # 4 vCPU, 16GB RAM, 1 GPU - $0.526/hour
node_instance_types = ["p3.2xlarge"]    # 8 vCPU, 61GB RAM, 1 V100 GPU

# Mixed instances (Auto Scaling sẽ chọn)
node_instance_types = ["t3.medium", "t3a.medium", "t2.medium"]
```

---

### 2. **Capacity Type** (node_capacity_type)

```hcl
# ON_DEMAND - Stable, predictable pricing
node_capacity_type = "ON_DEMAND"

# SPOT - 70% cheaper nhưng có thể bị terminate bất cứ lúc nào
node_capacity_type = "SPOT"
```

**💡 Khi nào dùng SPOT:**
- ✅ Dev/Test environments
- ✅ Stateless workloads
- ✅ Batch processing
- ✅ CI/CD runners
- ❌ Production critical apps
- ❌ Stateful databases

---

### 3. **AMI Type** (node_ami_type)

```hcl
# Amazon Linux 2023 (Mới nhất - Recommended)
node_ami_type = "AL2023_x86_64_STANDARD"

# Amazon Linux 2 (Stable, widely used)
node_ami_type = "AL2_x86_64"
node_ami_type = "AL2_x86_64_GPU"        # Với GPU support

# ARM-based (Graviton)
node_ami_type = "AL2_ARM_64"
node_ami_type = "AL2023_ARM_64_STANDARD"

# Bottlerocket (Minimal, security-focused)
node_ami_type = "BOTTLEROCKET_x86_64"
node_ami_type = "BOTTLEROCKET_ARM_64"

# Windows
node_ami_type = "WINDOWS_CORE_2019_x86_64"
node_ami_type = "WINDOWS_FULL_2022_x86_64"
```

---

### 4. **Node Labels** (node_labels)

```hcl
# Basic labels
node_labels = {
  environment = "production"
  team        = "platform"
  role        = "worker"
}

# Labels cho workload routing
node_labels = {
  workload-type = "compute-intensive"
  gpu-enabled   = "true"
  zone          = "us-west-2a"
}

# Labels cho cost allocation
node_labels = {
  cost-center  = "engineering"
  project      = "web-app"
  billing-team = "platform"
}
```

**Sử dụng labels trong Pod:**
```yaml
apiVersion: v1
kind: Pod
spec:
  nodeSelector:
    environment: production
    workload-type: compute-intensive
```

---

### 5. **Node Taints** (node_taints)

```hcl
# Taint cho GPU nodes
node_taints = [
  {
    key    = "nvidia.com/gpu"
    value  = "true"
    effect = "NoSchedule"
  }
]

# Taint cho dedicated workloads
node_taints = [
  {
    key    = "dedicated"
    value  = "high-priority"
    effect = "NoSchedule"
  }
]

# Multiple taints
node_taints = [
  {
    key    = "spot-instance"
    value  = "true"
    effect = "PreferNoSchedule"
  },
  {
    key    = "workload-type"
    value  = "batch"
    effect = "NoExecute"
  }
]
```

**Effects:**
- `NoSchedule` - Pod không schedule nếu không có toleration
- `PreferNoSchedule` - Cố gắng tránh schedule
- `NoExecute` - Evict pods không có toleration

**Sử dụng trong Pod:**
```yaml
apiVersion: v1
kind: Pod
spec:
  tolerations:
  - key: "nvidia.com/gpu"
    operator: "Equal"
    value: "true"
    effect: "NoSchedule"
```

---

### 6. **SSH Access** (optional)

```hcl
# Enable SSH access
enable_node_group_remote_access = true
node_ssh_key_name               = "my-ec2-keypair"
node_ssh_allowed_cidr           = ["10.0.0.0/16"]  # VPC CIDR only

# Production: Disable SSH (use SSM Session Manager)
enable_node_group_remote_access = false
```

---

## 🎯 Các cấu hình phổ biến

### A. **Development Environment** (Chi phí thấp)
```hcl
node_instance_types  = ["t3.small"]
node_capacity_type   = "SPOT"
node_ami_type        = "AL2023_x86_64_STANDARD"
node_desired_size    = 1
node_max_size        = 2
node_min_size        = 1
node_disk_size       = 10

node_labels = {
  environment = "dev"
}
```
**💵 Chi phí: ~$15/month**

---

### B. **Production (Standard)**
```hcl
node_instance_types  = ["t3.medium", "t3a.medium"]
node_capacity_type   = "ON_DEMAND"
node_ami_type        = "AL2023_x86_64_STANDARD"
node_desired_size    = 3
node_max_size        = 10
node_min_size        = 2
node_disk_size       = 20

node_labels = {
  environment = "production"
  tier        = "application"
}
```
**💵 Chi phí: ~$90/month**

---

### C. **High Performance (Compute)**
```hcl
node_instance_types  = ["c5.xlarge"]
node_capacity_type   = "ON_DEMAND"
node_ami_type        = "AL2023_x86_64_STANDARD"
node_desired_size    = 2
node_max_size        = 5
node_min_size        = 1
node_disk_size       = 30

node_labels = {
  workload-type = "compute-intensive"
  performance   = "high"
}
```
**💵 Chi phí: ~$245/month**

---

### D. **Cost-Optimized (ARM Graviton)**
```hcl
node_instance_types  = ["t4g.medium"]
node_capacity_type   = "ON_DEMAND"
node_ami_type        = "AL2023_ARM_64_STANDARD"
node_desired_size    = 2
node_max_size        = 4
node_min_size        = 1
node_disk_size       = 20

node_labels = {
  architecture = "arm64"
  cost-optimized = "true"
}
```
**💵 Chi phí: ~$48/month (save 20%)**

---

### E. **Spot + On-Demand Mixed** (Best of both)
Cần 2 node groups:

**Node Group 1: On-Demand (Critical)**
```hcl
node_group_name      = "on-demand-nodes"
node_instance_types  = ["t3.medium"]
node_capacity_type   = "ON_DEMAND"
node_desired_size    = 1
node_min_size        = 1

node_labels = {
  capacity-type = "on-demand"
}

node_taints = [
  {
    key    = "dedicated"
    value  = "critical"
    effect = "NoSchedule"
  }
]
```

**Node Group 2: Spot (Flexible)**
```hcl
node_group_name      = "spot-nodes"
node_instance_types  = ["t3.medium", "t3a.medium", "t2.medium"]
node_capacity_type   = "SPOT"
node_desired_size    = 2
node_min_size        = 0
node_max_size        = 10

node_labels = {
  capacity-type = "spot"
}
```

---

### F. **GPU Workloads** (Machine Learning)
```hcl
node_instance_types  = ["g4dn.xlarge"]
node_capacity_type   = "SPOT"  # Save 70% on GPU!
node_ami_type        = "AL2_x86_64_GPU"
node_desired_size    = 1
node_max_size        = 3
node_min_size        = 0
node_disk_size       = 50

node_labels = {
  workload-type = "gpu"
  nvidia-gpu    = "true"
}

node_taints = [
  {
    key    = "nvidia.com/gpu"
    value  = "true"
    effect = "NoSchedule"
  }
]
```
**💵 Chi phí: ~$380/month (ON_DEMAND) hoặc ~$115/month (SPOT)**

---

### G. **Bottlerocket (Security-focused)**
```hcl
node_instance_types  = ["t3.medium"]
node_capacity_type   = "ON_DEMAND"
node_ami_type        = "BOTTLEROCKET_x86_64"
node_desired_size    = 2
node_max_size        = 4
node_min_size        = 1

# Bottlerocket không hỗ trợ SSH
enable_node_group_remote_access = false

node_labels = {
  os = "bottlerocket"
  security-enhanced = "true"
}
```

---

## 💡 Best Practices

### 1. **Mixed Instance Types**
```hcl
# Tăng khả năng scale với nhiều instance types
node_instance_types = ["t3.medium", "t3a.medium", "t2.medium"]
```

### 2. **Separate Node Groups cho workload types**
```
- on-demand-nodes: Critical apps
- spot-nodes: Stateless apps
- gpu-nodes: ML workloads
- memory-nodes: Cache, databases
```

### 3. **Use Labels & Taints**
```hcl
# Route workloads đúng nodes
node_labels = { workload-type = "frontend" }
node_taints = [{ key = "dedicated", value = "backend", effect = "NoSchedule" }]
```

### 4. **Cost Optimization**
```hcl
# Dev/Test
node_capacity_type = "SPOT"
node_instance_types = ["t3a.small"]  # AMD cheaper

# Production
node_capacity_type = "ON_DEMAND"
node_instance_types = ["t4g.medium"]  # ARM 20% cheaper
```

### 5. **Disk Sizing**
```hcl
# Minimum cho container images
node_disk_size = 20

# Cho data-heavy workloads
node_disk_size = 50

# Container images cache
node_disk_size = 30
```

---

## 🔧 Troubleshooting

### Pods pending vì taint:
```bash
kubectl describe pod <pod-name>
# Add toleration to pod spec
```

### Nodes không đủ capacity:
```bash
kubectl top nodes
# Increase node_max_size hoặc upgrade instance type
```

### Spot instance bị terminate:
```bash
kubectl get nodes
# Dùng mixed on-demand + spot
# Set node_min_size > 0 cho on-demand
```

---

## 📚 References

- [EC2 Instance Types](https://aws.amazon.com/ec2/instance-types/)
- [EC2 Pricing](https://aws.amazon.com/ec2/pricing/on-demand/)
- [Spot Instance Pricing](https://aws.amazon.com/ec2/spot/pricing/)
- [EKS AMI Types](https://docs.aws.amazon.com/eks/latest/userguide/eks-optimized-ami.html)
- [Kubernetes Taints & Tolerations](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/)
