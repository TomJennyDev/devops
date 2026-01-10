# Atlantis Setup - Terraform Automation cho GitOps

## Atlantis là gì?
- Open-source tool để tự động chạy Terraform qua Pull Requests
- Comment `/atlantis plan` trong PR → tự động chạy terraform plan
- Comment `/atlantis apply` → tự động apply và commit changes
- Hoàn toàn tích hợp với GitHub/GitLab/Bitbucket

## Architecture
```
GitHub PR → Atlantis Server → terraform plan/apply
                              ↓
                         Update files (ingress.yaml)
                              ↓
                         Commit to PR branch
                              ↓
                         ArgoCD auto-sync
```

## Installation

### Option 1: Docker Compose (Quick Start)
```yaml
# docker-compose.yml
version: '3'
services:
  atlantis:
    image: ghcr.io/runatlantis/atlantis:latest
    ports:
      - 4141:4141
    environment:
      ATLANTIS_REPO_ALLOWLIST: "github.com/TomJennyDev/devops"
      ATLANTIS_GH_USER: "your-github-username"
      ATLANTIS_GH_TOKEN: "ghp_xxxxx"
      ATLANTIS_GH_WEBHOOK_SECRET: "your-webhook-secret"
      AWS_ACCESS_KEY_ID: "${AWS_ACCESS_KEY_ID}"
      AWS_SECRET_ACCESS_KEY: "${AWS_SECRET_ACCESS_KEY}"
      AWS_REGION: "ap-southeast-1"
    volumes:
      - ./atlantis-data:/atlantis-data
    command: server
```

```bash
# Start Atlantis
docker-compose up -d

# Setup GitHub webhook
# URL: https://your-atlantis-domain.com/events
# Events: issue_comment, pull_request, push
```

### Option 2: Kubernetes Deployment
```yaml
# atlantis-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: atlantis
  namespace: atlantis
spec:
  replicas: 1
  selector:
    matchLabels:
      app: atlantis
  template:
    metadata:
      labels:
        app: atlantis
    spec:
      serviceAccountName: atlantis
      containers:
      - name: atlantis
        image: ghcr.io/runatlantis/atlantis:v0.28.0
        ports:
        - containerPort: 4141
        env:
        - name: ATLANTIS_REPO_ALLOWLIST
          value: "github.com/TomJennyDev/devops"
        - name: ATLANTIS_GH_USER
          valueFrom:
            secretKeyRef:
              name: atlantis-github
              key: username
        - name: ATLANTIS_GH_TOKEN
          valueFrom:
            secretKeyRef:
              name: atlantis-github
              key: token
        - name: ATLANTIS_GH_WEBHOOK_SECRET
          valueFrom:
            secretKeyRef:
              name: atlantis-github
              key: webhook-secret
        - name: ATLANTIS_ATLANTIS_URL
          value: "https://atlantis.do2506.click"
        volumeMounts:
        - name: atlantis-data
          mountPath: /atlantis-data
      volumes:
      - name: atlantis-data
        persistentVolumeClaim:
          claimName: atlantis-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: atlantis
  namespace: atlantis
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 4141
  selector:
    app: atlantis
```

## Configuration

### atlantis.yaml (Root của repo)
```yaml
version: 3
automerge: false
delete_source_branch_on_merge: false

projects:
- name: eks-dev
  dir: terraform-eks/environments/dev
  workspace: default
  autoplan:
    when_modified: ["*.tf", "*.tfvars"]
    enabled: true
  apply_requirements: ["approved"]
  workflow: eks-workflow
  
workflows:
  eks-workflow:
    plan:
      steps:
      - init
      - plan:
          extra_args: ["-out=tfplan"]
    apply:
      steps:
      - apply
      # Post-apply: Update ingress with WAF ARN
      - run: |
          WAF_ARN=$(terraform output -raw waf_web_acl_arn 2>/dev/null || echo "")
          if [ -n "$WAF_ARN" ]; then
            INGRESS_FILE="../../argocd/apps/flowise/overlays/dev/ingress.yaml"
            sed -i "s|alb.ingress.kubernetes.io/wafv2-acl-arn:.*|alb.ingress.kubernetes.io/wafv2-acl-arn: $WAF_ARN|" "$INGRESS_FILE"
            echo "✓ Updated WAF ARN in ingress"
          fi
      # Commit updated files
      - run: |
          git config user.name "Atlantis Bot"
          git config user.email "atlantis@do2506.click"
          git add ../../argocd/apps/flowise/overlays/dev/ingress.yaml
          if ! git diff --cached --quiet; then
            git commit -m "chore: auto-update WAF ARN [atlantis]"
          fi
```

## Workflow

### 1. Tạo Pull Request với Terraform changes
```bash
git checkout -b feat/update-waf
# Edit terraform files...
git commit -m "feat: enable WAF rate limiting"
git push origin feat/update-waf
# Create PR on GitHub
```

### 2. Atlantis tự động chạy plan
```
PR created → Atlantis comments với terraform plan output
```

### 3. Review và approve
```
Review PR → Comment: /atlantis apply
```

### 4. Atlantis apply và update ingress
```
Atlantis:
1. terraform apply
2. Extract WAF ARN
3. Update ingress.yaml
4. Commit changes to PR branch
5. Comment với apply results
```

### 5. Merge PR
```
PR merged → ArgoCD auto-sync → Ingress updated with new WAF
```

## Security Best Practices

### 1. IAM Role for Atlantis (IRSA)
```hcl
# terraform-eks/modules/atlantis/iam.tf
resource "aws_iam_role" "atlantis" {
  name = "${var.cluster_name}-atlantis"
  
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Condition = {
        StringEquals = {
          "${var.oidc_provider}:sub" = "system:serviceaccount:atlantis:atlantis"
          "${var.oidc_provider}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "atlantis_admin" {
  role       = aws_iam_role.atlantis.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
```

### 2. GitHub App (thay vì Personal Access Token)
- Tạo GitHub App với limited permissions
- Install app vào repo
- Atlantis sử dụng app credentials

### 3. Webhook Secret
```bash
# Generate strong secret
openssl rand -hex 32
```

## Pros & Cons

### ✅ Pros
- **Fully automated**: Không cần chạy terraform manual
- **GitOps native**: Mọi thứ qua PR, có audit trail
- **Team collaboration**: Comment-based workflow
- **Auto-update files**: Tự động commit ingress changes
- **Open source**: Free, community support

### ⚠️ Cons
- **Infrastructure cost**: Cần server/pod chạy Atlantis
- **Setup complexity**: Cần config IAM, webhooks, secrets
- **Single point of failure**: Nếu Atlantis down, không deploy được

## Alternative: GitHub Actions với Terraform

Nếu không muốn maintain Atlantis server:

```yaml
# .github/workflows/terraform-auto.yml
name: Terraform Auto-Apply
on:
  push:
    branches: [main]
    paths:
      - 'terraform-eks/**'

jobs:
  terraform:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: write
    steps:
    - uses: actions/checkout@v4
    
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        role-to-assume: arn:aws:iam::372836560690:role/github-actions-terraform
        aws-region: ap-southeast-1
    
    - name: Terraform Apply
      working-directory: terraform-eks/environments/dev
      run: |
        terraform init
        terraform apply -auto-approve
    
    - name: Update Ingress with WAF ARN
      working-directory: terraform-eks/environments/dev
      run: |
        WAF_ARN=$(terraform output -raw waf_web_acl_arn)
        sed -i "s|alb.ingress.kubernetes.io/wafv2-acl-arn:.*|alb.ingress.kubernetes.io/wafv2-acl-arn: $WAF_ARN|" ../../argocd/apps/flowise/overlays/dev/ingress.yaml
    
    - name: Commit changes
      run: |
        git config user.name "GitHub Actions"
        git config user.email "actions@github.com"
        git add argocd/apps/flowise/overlays/dev/ingress.yaml
        git diff --cached --quiet || git commit -m "chore: auto-update WAF ARN [ci]"
        git push
```

## Recommendation

### For Your Setup (Small team, 1-2 envs):
**→ Use GitHub Actions** (simpler, no infra to maintain)

### For Production (Multiple teams, many envs):
**→ Use Atlantis** (better collaboration, PR-based workflow)

### For Enterprise:
**→ Use Terraform Cloud/HCP Terraform** (official HashiCorp solution, paid)
