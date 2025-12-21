# ArgoCD Deployment Guide

Hướng dẫn deploy ArgoCD lên EKS cluster sau khi Terraform hoàn tất.

## Prerequisites

- ✅ Terraform đã apply xong (xem [TERRAFORM-DEPLOYMENT.md](./TERRAFORM-DEPLOYMENT.md))
- ✅ kubectl configured
- ✅ Helm installed
- ✅ Cluster info đã export (`./export-cluster-info.sh`)

## Quick Start

### Option 1: Automated Script (Recommended)

```bash
cd terraform-eks/scripts
./deploy-argocd.sh
```

**Timeline:** ~10 phút

- AWS Load Balancer Controller: ~3 phút
- Cert-manager: ~2 phút
- ArgoCD Helm install: ~3 phút
- ALB provisioning: ~2 phút

### Option 2: Manual Steps

#### 1. Load Cluster Info

```bash
source ../environments/dev/cluster-info/cluster-env.sh
```

#### 2. Configure kubectl

```bash
aws eks update-kubeconfig --region $EKS_REGION --name $EKS_CLUSTER_NAME
kubectl get nodes
```

#### 3. Deploy AWS Load Balancer Controller

```bash
# Add Helm repos
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Install cert-manager (required)
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Wait for cert-manager
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s

# Install ALB Controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$EKS_CLUSTER_NAME \
  --set serviceAccount.create=true \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$ALB_CONTROLLER_ROLE_ARN \
  --set region=$EKS_REGION \
  --set vpcId=$VPC_ID
```

#### 4. Create ArgoCD Namespace

```bash
kubectl create namespace argocd
```

#### 5. Deploy ArgoCD

```bash
# Add ArgoCD Helm repo
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Install ArgoCD
helm install argocd argo/argo-cd \
  -n argocd \
  --values ../../argocd/helm-values/argocd-values.yaml \
  --wait
```

#### 6. Wait for Pods

```bash
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=argocd-server \
  -n argocd \
  --timeout=300s
```

#### 7. Get Admin Password

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

## Access ArgoCD

### Via ALB (Production)

**URL:** <https://argocd.do2506.click>

**Credentials:**

- Username: `admin`
- Password: (xem output từ script hoặc command trên)

Wait 2-3 phút để ALB provision và DNS propagate.

### Via Port Forward (Alternative)

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

**URL:** <https://localhost:8080>

## ArgoCD Configuration

File: `argocd/helm-values/argocd-values.yaml`

**Key settings:**

- Server: ALB Ingress với SSL (argocd.do2506.click)
- Repo Server: 2 replicas
- Application Controller: 2 replicas
- Redis HA: 3 replicas
- Dex disabled (using built-in auth)

## Verify Deployment

```bash
# Check pods
kubectl get pods -n argocd

# Check ingress
kubectl get ingress -n argocd

# Check ALB
kubectl get svc -n kube-system aws-load-balancer-controller

# Check ArgoCD health
kubectl get application -n argocd
```

## Post-Installation

### 1. Change Admin Password

```bash
argocd login argocd.do2506.click --username admin --password <initial-password>
argocd account update-password
```

### 2. Add Git Repository

**Via UI:**

1. Settings → Repositories → Connect Repo
2. Enter GitHub repo URL
3. Choose HTTPS or SSH
4. Add credentials if private

**Via CLI:**

```bash
argocd repo add https://github.com/TomJennyDev/devops.git \
  --username <github-username> \
  --password <github-token>
```

### 3. Deploy App of Apps

```bash
kubectl apply -f argocd/app-of-apps-kustomize-dev.yaml
```

This will deploy:

- AWS Load Balancer Controller (system app)
- Prometheus (monitoring)
- Other infrastructure components

### 4. Deploy Applications

```bash
kubectl apply -f argocd/applications/flowise-apps.yaml
```

## Cluster Info ConfigMap

ArgoCD applications có thể reference cluster info từ ConfigMap:

```bash
kubectl apply -f ../environments/dev/cluster-info/cluster-info-configmap.yaml
```

**Usage in Applications:**

```yaml
env:
  - name: CLUSTER_NAME
    valueFrom:
      configMapKeyRef:
        name: cluster-info
        key: cluster.name
```

## Troubleshooting

### ALB không tạo

```bash
# Check ALB Controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Check ingress events
kubectl describe ingress argocd-server -n argocd

# Verify IAM role
aws iam get-role --role-name my-eks-dev-aws-load-balancer-controller
```

### Cannot login

```bash
# Get fresh password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Reset admin password
kubectl -n argocd delete secret argocd-initial-admin-secret
kubectl -n argocd rollout restart deployment argocd-server
```

### Pods pending

```bash
# Check node resources
kubectl describe nodes

# Check pod events
kubectl describe pod <pod-name> -n argocd
```

### DNS not working

```bash
# Check Route53 record
aws route53 list-resource-record-sets \
  --hosted-zone-id <zone-id> \
  --query "ResourceRecordSets[?Name=='argocd.do2506.click.']"

# Check ALB DNS
kubectl get ingress argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

## Using ECR with ArgoCD

ECR URLs đã được export trong cluster-info:

```yaml
# Application using ECR
apiVersion: argoproj.io/v1alpha1
kind: Application
spec:
  source:
    helm:
      values: |
        image:
          repository: 372836560690.dkr.ecr.ap-southeast-1.amazonaws.com/flowise-server
          tag: latest
```

**Pull images:**

```bash
# Login to ECR
aws ecr get-login-password --region ap-southeast-1 | \
  docker login --username AWS --password-stdin 372836560690.dkr.ecr.ap-southeast-1.amazonaws.com

# Pull
docker pull 372836560690.dkr.ecr.ap-southeast-1.amazonaws.com/flowise-server:latest
```

## Directory Structure

```
terraform-eks/
├── scripts/
│   ├── export-cluster-info.sh       # Export cluster info
│   └── deploy-argocd.sh            # Deploy ArgoCD (run this)
├── environments/dev/
│   └── cluster-info/                # Generated files
│       ├── cluster-info.yaml
│       ├── cluster-env.sh
│       ├── argocd-cluster-values.yaml
│       └── argocd-credentials.txt   # Created after deploy
└── argocd/
    ├── helm-values/
    │   └── argocd-values.yaml      # ArgoCD configuration
    ├── applications/
    │   └── flowise-apps.yaml       # App definitions
    └── app-of-apps-kustomize-dev.yaml  # App of Apps pattern
```

## Resources

- ArgoCD Docs: <https://argo-cd.readthedocs.io>
- Helm Chart: <https://github.com/argoproj/argo-helm>
- AWS Load Balancer Controller: <https://kubernetes-sigs.github.io/aws-load-balancer-controller>

## Summary

1. ✅ Terraform creates EKS cluster
2. ✅ Export cluster info: `./export-cluster-info.sh`
3. ✅ Deploy ArgoCD: `./deploy-argocd.sh`
4. ⏳ Access UI: <https://argocd.do2506.click>
5. ⏳ Deploy apps via ArgoCD

**Next:** Configure Git repos and deploy your applications! 🚀
