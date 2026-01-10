# =========================================
# Dynamic WAF Configuration Strategy
# =========================================

## Problem
After running `terraform apply`, WAF ARN changes and needs to be updated in Kubernetes Ingress annotations manually.

## Solutions

### Option 1: Post-Deployment Script (Simple)
**Use case:** Dev/Staging environments with manual deployments

**Steps:**
1. Run terraform: `cd terraform-eks/environments/dev && terraform apply`
2. Run post-deployment: `./scripts/post-terraform-deploy.sh`
   - Extracts WAF ARN from terraform output
   - Updates ingress.yaml with new ARN
   - Commits and pushes changes
   - ArgoCD auto-syncs and applies

**Pros:** 
- Simple to implement
- Works with existing GitOps workflow
- No additional dependencies

**Cons:**
- Manual step after terraform
- Requires git commit

**Files:**
- `scripts/update-waf-ingress.sh` - Updates ingress with WAF ARN
- `scripts/post-terraform-deploy.sh` - Orchestrates all post-deploy tasks

---

### Option 2: ConfigMap with Kustomize (Better)
**Use case:** Semi-automated deployments with Kustomize

**Architecture:**
```
terraform apply
    ↓
generate-terraform-outputs.sh
    ↓
Creates: argocd/apps/flowise/overlays/dev/terraform-outputs.yaml (ConfigMap)
    ↓
Kustomize patches ingress annotations from ConfigMap
    ↓
ArgoCD syncs automatically
```

**Implementation:**

1. **Generate ConfigMap after terraform:**
```bash
./scripts/generate-terraform-outputs.sh
```

2. **Create Kustomize patch:**
```yaml
# argocd/apps/flowise/overlays/dev/ingress-waf-patch.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: flowise-ingress
  annotations:
    alb.ingress.kubernetes.io/wafv2-acl-arn: $(WAF_ARN)
```

3. **Use envsubst or kustomize replacements:**
```yaml
# kustomization.yaml
replacements:
- source:
    kind: ConfigMap
    name: terraform-outputs
    fieldPath: data.waf_arn
  targets:
  - select:
      kind: Ingress
      name: flowise-ingress
    fieldPaths:
    - metadata.annotations.[alb.ingress.kubernetes.io/wafv2-acl-arn]
```

**Pros:**
- Automated with Kustomize
- No manual ingress file editing
- GitOps friendly

**Cons:**
- Requires Kustomize v4.1+
- Still needs ConfigMap generation

---

### Option 3: External Secrets Operator (Production)
**Use case:** Production environments with full automation

**Architecture:**
```
Terraform stores outputs → AWS SSM Parameter Store
    ↓
External Secrets Operator reads from SSM
    ↓
Creates Kubernetes Secret with WAF ARN
    ↓
Ingress uses secret via annotation
```

**Implementation:**

1. **Store WAF ARN in SSM (Terraform):**
```hcl
resource "aws_ssm_parameter" "waf_arn" {
  name  = "/eks/${var.cluster_name}/waf/arn"
  type  = "String"
  value = module.waf.waf_web_acl_arn
}
```

2. **Install External Secrets Operator:**
```bash
helm install external-secrets external-secrets/external-secrets -n external-secrets-system
```

3. **Create ExternalSecret:**
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: terraform-outputs
  namespace: flowise-dev
spec:
  refreshInterval: 5m
  secretStoreRef:
    name: aws-parameter-store
    kind: SecretStore
  target:
    name: terraform-outputs
  data:
  - secretKey: waf_arn
    remoteRef:
      key: /eks/my-eks-dev/waf/arn
```

4. **Use in ingress via Kustomize replacement**

**Pros:**
- Fully automated
- No git commits needed
- Real-time sync from AWS
- Production-grade

**Cons:**
- Complex setup
- Additional operator to manage
- Requires AWS IAM permissions

---

## Recommended Approach

### For Current Setup (Dev):
**Use Option 1 (Post-Deployment Script)**

**Workflow:**
```bash
# 1. Deploy infrastructure
cd terraform-eks/environments/dev
terraform apply

# 2. Run post-deployment automation
cd ../../..
./scripts/post-terraform-deploy.sh

# 3. Verify
./scripts/check-flowise-health.sh
```

### For Production:
**Use Option 3 (External Secrets Operator)**
- Fully automated
- No manual intervention
- Scales to multiple environments

---

## Quick Start

**Enable automation now:**
```bash
# Make scripts executable
chmod +x scripts/update-waf-ingress.sh
chmod +x scripts/post-terraform-deploy.sh
chmod +x scripts/generate-terraform-outputs.sh

# Add to deployment workflow
echo "terraform apply && ../../../scripts/post-terraform-deploy.sh" > deploy.sh
chmod +x deploy.sh
```

**Usage:**
```bash
cd terraform-eks/environments/dev
terraform apply && ../../../scripts/post-terraform-deploy.sh
```

This automatically:
1. ✅ Exports cluster info
2. ✅ Updates kubeconfig
3. ✅ Updates WAF ARN in ingress
4. ✅ Updates DNS records
5. ✅ Commits and pushes changes
6. ✅ ArgoCD syncs automatically

---

## Files Created

- `scripts/update-waf-ingress.sh` - Extract WAF ARN and update ingress
- `scripts/post-terraform-deploy.sh` - Orchestrate all post-deploy tasks
- `scripts/generate-terraform-outputs.sh` - Generate ConfigMap (for Option 2)
- `docs/WAF-DYNAMIC-CONFIG.md` - This documentation

---

## Future Improvements

1. **GitHub Actions Integration:**
   - Trigger post-deployment script in CI/CD
   - Auto-commit and push from GitHub Actions

2. **Multi-environment support:**
   - Loop through dev/staging/prod
   - Update all ingresses automatically

3. **Validation:**
   - Verify WAF attachment after update
   - Check ingress health before commit

4. **Rollback:**
   - Keep previous WAF ARN in git history
   - Easy rollback if needed
