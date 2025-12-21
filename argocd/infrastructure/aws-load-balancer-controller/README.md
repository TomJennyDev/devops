# AWS Load Balancer Controller Configuration

## 📁 Directory Structure

```
aws-load-balancer-controller/
├── base/
│   ├── application.yaml          # Base ArgoCD Application
│   ├── kustomization.yaml
│   ├── namespace.yaml
│   └── serviceaccount.yaml
└── overlays/
    ├── dev/
    │   ├── values.yaml            # ⚠️ Dev environment values
    │   ├── application-patch.yaml
    │   ├── deployment-patch.yaml
    │   ├── serviceaccount-patch.yaml
    │   └── kustomization.yaml
    ├── staging/
    │   ├── values.yaml            # ⚠️ Staging environment values
    │   └── ...
    └── production/
        ├── values.yaml            # ⚠️ Production environment values
        └── ...
```

---

## 🎯 Values File Pattern

All environment-specific configuration is centralized in **`values.yaml`** per environment.

### **Dev (`overlays/dev/values.yaml`)**

```yaml
clusterName: my-eks-dev
region: ap-southeast-1
vpcId: vpc-0e6ca42c7851c46c4
iamRoleArn: arn:aws:iam::372836560690:role/my-eks-dev-aws-load-balancer-controller
replicaCount: 2
```

### **Staging (`overlays/staging/values.yaml`)**

```yaml
clusterName: my-eks-staging
vpcId: vpc-XXXXXXXXX  # Update after terraform apply
iamRoleArn: arn:aws:iam::372836560690:role/my-eks-staging-aws-load-balancer-controller
replicaCount: 2
```

### **Production (`overlays/production/values.yaml`)**

```yaml
clusterName: my-eks-prod
vpcId: vpc-XXXXXXXXX  # Update after terraform apply
iamRoleArn: arn:aws:iam::372836560690:role/my-eks-prod-aws-load-balancer-controller
replicaCount: 3  # More replicas for production
```

---

## 🔄 Workflow

### **1. Deploy Terraform Infrastructure**

```bash
cd terraform-eks/environments/dev
terraform apply
```

### **2. Auto-update values.yaml**

```bash
cd /d/devops/gitops/scripts

# Update dev
./update-alb-controller-config.sh dev

# Update staging
./update-alb-controller-config.sh staging

# Update production
./update-alb-controller-config.sh production
```

### **3. Review Changes**

```bash
git diff argocd/system-apps-kustomize/aws-load-balancer-controller/overlays/dev/values.yaml
```

### **4. Commit**

```bash
git add .
git commit -m "Update ALB Controller values for dev from Terraform outputs"
git push
```

### **5. Deploy to Cluster**

```bash
# Deploy via Kustomize
kubectl apply -k argocd/system-apps-kustomize/aws-load-balancer-controller/overlays/dev/

# Or deploy via ArgoCD
kubectl apply -f argocd/system-apps-kustomize/aws-load-balancer-controller/base/application.yaml
```

---

## 📝 Manual Update (if needed)

If auto-script doesn't work, manually edit `values.yaml`:

```bash
# Get Terraform outputs
cd terraform-eks/environments/dev
terraform output cluster_id
terraform output vpc_id
terraform output aws_load_balancer_controller_role_arn

# Edit values.yaml
vi argocd/system-apps-kustomize/aws-load-balancer-controller/overlays/dev/values.yaml
```

**Update these fields:**

- `clusterName`: From `terraform output cluster_id`
- `vpcId`: From `terraform output vpc_id`
- `iamRoleArn`: From `terraform output aws_load_balancer_controller_role_arn`

---

## ✅ Verification

```bash
# Check values file
cat overlays/dev/values.yaml

# Build final manifest
kubectl kustomize overlays/dev/ | grep -A 5 "clusterName"

# Check deployed controller
kubectl get deployment -n kube-system aws-load-balancer-controller
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

---

## 🔍 Troubleshooting

### **Issue: Values not applied**

```bash
# Check if Kustomize picked up values.yaml
kubectl kustomize overlays/dev/ | grep clusterName

# Verify ConfigMap created
kubectl get configmap -n kube-system alb-controller-config
```

### **Issue: Wrong IAM role**

```bash
# Check service account annotation
kubectl get sa -n kube-system aws-load-balancer-controller -o yaml | grep role-arn

# Should match:
# eks.amazonaws.com/role-arn: arn:aws:iam::372836560690:role/my-eks-dev-aws-load-balancer-controller
```

### **Issue: Controller not starting**

```bash
# Check logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=100

# Common errors:
# - "AccessDenied" → Check IAM role permissions
# - "VPC not found" → Check vpcId in values.yaml
# - "Cluster not found" → Check clusterName matches EKS cluster
```

---

## 🎯 Benefits of Centralized Values

✅ **Single source of truth**: All environment config in one file
✅ **Easy to update**: Change one file, not multiple manifests
✅ **Version controlled**: Track changes to infrastructure config
✅ **Automation friendly**: Script can update one file easily
✅ **Clear separation**: Base vs environment-specific config

---

## 📊 Values Precedence

```
Base values (application.yaml)
  ↓
Environment values (values.yaml)
  ↓
Patches (deployment-patch.yaml, serviceaccount-patch.yaml)
  ↓
Final manifest applied to cluster
```

The **values.yaml takes highest precedence** for Helm values.
