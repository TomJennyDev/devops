# EKS Cluster Information

**Generated:** Sat, Dec 13, 2025  1:27:18 PM

## Cluster Details

| Property | Value |
|----------|-------|
| Cluster Name | `my-eks-dev` |
| Region | `ap-southeast-1` |
| Account ID | `372836560690` |
| VPC ID | `vpc-0e6ca42c7851c46c4` |
| Node Group | `my-eks-dev:dev-workers` |

## Endpoints

**EKS API Server:**
```
https://BF4C18058F438CD9909534B541FD16A8.gr7.ap-southeast-1.eks.amazonaws.com
```

## IAM Roles

**AWS Load Balancer Controller:**
```
arn:aws:iam::372836560690:role/my-eks-dev-aws-load-balancer-controller
```

**External DNS:**
```

```

## ECR Repositories

**Flowise Server:**
```
372836560690.dkr.ecr.ap-southeast-1.amazonaws.com/flowise-server
```

**Flowise UI:**
```
372836560690.dkr.ecr.ap-southeast-1.amazonaws.com/flowise-ui
```

## Quick Commands

### Configure kubectl
```bash
aws eks update-kubeconfig --region ap-southeast-1 --name my-eks-dev
```

### Load environment variables
```bash
source cluster-env.sh
```

### Apply ConfigMap
```bash
kubectl apply -f cluster-info-configmap.yaml
```

### Login to ECR
```bash
aws ecr get-login-password --region ap-southeast-1 | \
  docker login --username AWS --password-stdin 372836560690.dkr.ecr.ap-southeast-1.amazonaws.com
```

### Push image to ECR
```bash
# Tag image
docker tag flowise-server:latest 372836560690.dkr.ecr.ap-southeast-1.amazonaws.com/flowise-server:latest

# Push image
docker push 372836560690.dkr.ecr.ap-southeast-1.amazonaws.com/flowise-server:latest
```

## Files in this directory

- `terraform-outputs.json` - Raw Terraform outputs in JSON
- `cluster-info.yaml` - Structured cluster information
- `cluster-env.sh` - Shell environment variables
- `argocd-cluster-values.yaml` - ArgoCD-ready values file
- `cluster-info-configmap.yaml` - Kubernetes ConfigMap
- `README.md` - This file

## Usage in ArgoCD Applications

### Reference ECR images
```yaml
spec:
  source:
    helm:
      values: |
        image:
          repository: 372836560690.dkr.ecr.ap-southeast-1.amazonaws.com/flowise-server
          tag: latest
```

### Use ConfigMap values
```yaml
env:
  - name: CLUSTER_NAME
    valueFrom:
      configMapKeyRef:
        name: cluster-info
        key: cluster.name
```

### Use as Helm values
```bash
helm install my-app ./chart \
  -f argocd-cluster-values.yaml
```
