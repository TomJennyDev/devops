# Flowise CI/CD Workflow

## Tổng Quan

Pipeline CI/CD cho FlowiseAI được thiết kế theo mô hình **GitOps**, tách biệt hoàn toàn giữa:
- **Build & Push Images** (Repo Flowise - source code)
- **Update Deployment Config** (Repo DevOps - GitOps)

## Kiến Trúc

```
┌─────────────────────────────────────────────────────────────────────┐
│                         FLOWISE REPO                                 │
│                    (Source Code Repository)                          │
│                                                                      │
│  Push Code → GitHub Actions Workflow                                │
│                                                                      │
│  Jobs:                                                               │
│  1. Build Server Image   → Push to ECR                              │
│  2. Build UI Image       → Push to ECR                              │
│  3. Get Image Digests    → Immutable references                     │
│  4. Trigger DevOps Repo  → repository_dispatch event                │
│                                                                      │
└────────────────────────┬─────────────────────────────────────────────┘
                         │
                         │ Repository Dispatch Event
                         │ Payload: {environment, tag, digests, sha}
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        DEVOPS REPO                                   │
│                  (GitOps Configuration Repository)                   │
│                                                                      │
│  Receives Trigger → GitHub Actions Workflow                         │
│                                                                      │
│  Jobs:                                                               │
│  1. Parse Payload       → Extract deployment info                   │
│  2. Update Kustomization → Set new image references                 │
│  3. Commit & Push       → Trigger ArgoCD sync                       │
│                                                                      │
└────────────────────────┬─────────────────────────────────────────────┘
                         │
                         │ Git Commit on main branch
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────────┐
│                           ARGOCD                                     │
│                                                                      │
│  Auto-Sync Enabled → Detect Git changes                             │
│                   → Apply to Kubernetes                              │
│                   → Rolling update pods with new images              │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

## Chi Tiết Workflows

### 1. Flowise Repo: `deploy-to-k8s.yml`

**Location**: `Flowise-Repo/.github/workflows/deploy-to-k8s.yml`

**Triggers**:
- Push to `main` branch (auto deploy to dev)
- Manual dispatch (chọn environment: dev/staging/production)

**Steps**:

```yaml
Job 1: set-env
  - Tạo tag từ commit SHA (7 ký tự)
  - Xác định environment (dev/staging/production)
  - Output: tag, env, node_version

Job 2: build-server
  - Build Docker image từ packages/server/Dockerfile
  - Push lên ECR với tags: {sha}, latest, {full-sha}
  - Lấy image digest từ ECR
  - Output: image_uri, image_digest

Job 3: build-ui
  - Build Docker image từ packages/ui/Dockerfile
  - Push lên ECR với tags: {sha}, latest, {full-sha}
  - Lấy image digest từ ECR
  - Output: image_uri, image_digest

Job 4: trigger-gitops-repo
  - Gửi repository_dispatch event đến DevOps repo
  - Event type: flowise-image-updated
  - Payload:
    {
      environment: "dev",
      tag: "abc1234",
      sha: "abc1234567890...",
      server_digest: "sha256:...",
      ui_digest: "sha256:...",
      actor: "github-username",
      workflow_run_id: "123456"
    }
```

**Secrets Required**:
- `AWS_ACCESS_KEY_ID`: AWS credentials để push ECR
- `AWS_SECRET_ACCESS_KEY`: AWS secret key
- `GITOPS_TOKEN`: GitHub PAT để trigger DevOps repo

### 2. DevOps Repo: `update-flowise-deployment.yml`

**Location**: `devops/.github/workflows/update-flowise-deployment.yml`

**Triggers**:
- `repository_dispatch` event type `flowise-image-updated` (từ Flowise repo)
- Manual dispatch (cho testing)

**Steps**:

```yaml
Job: update-kustomization
  Step 1: Parse trigger payload
    - Nhận environment, tag, SHA, digests từ payload
    - Hoặc từ manual input nếu workflow_dispatch
    - Xác định overlay path: argocd/apps/flowise/overlays/{env}

  Step 2: Checkout DevOps repository
    - Clone repo với GITHUB_TOKEN
    - Full history (fetch-depth: 0)

  Step 3: Setup Kustomize
    - Cài đặt kustomize CLI

  Step 4: Update kustomization.yaml
    - CD vào overlay directory
    - Ưu tiên dùng digest (immutable) nếu có
    - Fallback sang tag nếu không có digest
    - Chạy: kustomize edit set image flowise-server=...
    - Chạy: kustomize edit set image flowise-ui=...
    - In ra kustomization.yaml mới

  Step 5: Commit and push changes
    - Git config user = github-actions[bot]
    - Git add kustomization.yaml
    - Check nếu có thay đổi
    - Commit với message: "chore(env): update flowise images to {tag}"
    - Push lên main branch

  Step 6: Deployment summary
    - In ra thông tin deployment
    - Environment, tag, SHA, images, next steps
```

**Secrets Required**:
- `GITHUB_TOKEN`: Automatically provided, dùng để commit/push

## Luồng Hoạt Động Đầy Đủ

### Scenario: Developer push code mới

```
1. Developer push code vào Flowise repo (main branch)
   └─> Trigger: deploy-to-k8s.yml workflow

2. Flowise Workflow:
   ├─> Build server image → Push ECR (tag: f3a21bc)
   ├─> Build UI image → Push ECR (tag: f3a21bc)
   ├─> Get digests: sha256:abc123... & sha256:def456...
   └─> Send repository_dispatch to DevOps repo

3. DevOps Workflow (auto-triggered):
   ├─> Receive event with payload
   ├─> Update argocd/apps/flowise/overlays/dev/kustomization.yaml:
   │     images:
   │     - name: flowise-server
   │       newName: 372836560690.dkr.ecr.ap-southeast-1.amazonaws.com/flowise-server
   │       digest: sha256:abc123...
   │     - name: flowise-ui
   │       newName: 372836560690.dkr.ecr.ap-southeast-1.amazonaws.com/flowise-ui
   │       digest: sha256:def456...
   └─> Commit & push to main

4. ArgoCD (auto-sync enabled):
   ├─> Detect Git commit on main branch
   ├─> Compare desired state vs current state
   ├─> Apply changes to Kubernetes cluster
   └─> Rolling update deployments:
         flowise-server: Pulling new image with digest
         flowise-ui: Pulling new image with digest

5. Kubernetes:
   ├─> Pull new images from ECR
   ├─> Start new pods with new images
   ├─> Wait for readiness probes
   ├─> Terminate old pods
   └─> Deployment complete ✅
```

## Cách Sử Dụng

### Deploy Tự Động (Push to Main)

1. Push code vào Flowise repo:
   ```bash
   git add .
   git commit -m "feat: add new feature"
   git push origin main
   ```

2. Workflow tự động chạy và deploy lên **dev environment**

3. Kiểm tra:
   - GitHub Actions: https://github.com/TomJennyDev/FlowiseAI/actions
   - ArgoCD UI: kiểm tra app `flowise-dev`
   - Pods: `kubectl get pods -n flowise-dev`

### Deploy Thủ Công (Manual Trigger)

#### Từ Flowise Repo:

1. Vào: https://github.com/TomJennyDev/FlowiseAI/actions
2. Chọn workflow: "Build and Push Flowise Images"
3. Click **"Run workflow"**
4. Chọn:
   - **Environment**: dev / staging / production
   - **Node version**: 20
5. Click **"Run workflow"**

#### Từ DevOps Repo (Testing):

1. Vào: https://github.com/TomJennyDev/devops/actions
2. Chọn workflow: "Update Flowise Deployment"
3. Click **"Run workflow"**
4. Nhập:
   - **Environment**: dev / staging / production
   - **Tag**: commit SHA (ví dụ: `f3a21bc`)
   - **Server digest** (optional): `sha256:abc123...`
   - **UI digest** (optional): `sha256:def456...`
5. Click **"Run workflow"**

## Cấu Hình

### Secrets Cần Thiết

#### Flowise Repo:
```
AWS_ACCESS_KEY_ID       → AWS credentials cho ECR
AWS_SECRET_ACCESS_KEY   → AWS secret key
GITOPS_TOKEN            → GitHub PAT với quyền trigger DevOps repo
```

#### DevOps Repo:
```
GITHUB_TOKEN            → Auto-provided, không cần config
```

### Tạo GitHub Personal Access Token (GITOPS_TOKEN)

1. Vào GitHub Settings → Developer settings → Personal access tokens
2. Generate new token (classic)
3. Chọn scopes:
   - ✅ `repo` (full control)
   - ✅ `workflow` (update workflows)
4. Copy token và thêm vào Flowise repo secrets

### Environment Variables

Trong `update-flowise-deployment.yml`:
```yaml
env:
    AWS_REGION: ap-southeast-1
    ECR_REGISTRY: 372836560690.dkr.ecr.ap-southeast-1.amazonaws.com
```

Trong `deploy-to-k8s.yml`:
```yaml
env:
    AWS_REGION: ap-southeast-1
    GITOPS_REPO: TomJennyDev/devops
```

## Kiểm Tra & Debug

### Xem Logs Workflow

**Flowise Repo**:
```bash
# Xem workflow runs
gh run list --repo TomJennyDev/FlowiseAI

# Xem logs của run cụ thể
gh run view <run-id> --repo TomJennyDev/FlowiseAI --log
```

**DevOps Repo**:
```bash
# Xem workflow runs
gh run list --repo TomJennyDev/devops

# Xem logs
gh run view <run-id> --repo TomJennyDev/devops --log
```

### Kiểm Tra Images trong ECR

```bash
# List images
aws ecr describe-images \
    --repository-name flowise-server \
    --region ap-southeast-1

# Get digest của tag cụ thể
aws ecr describe-images \
    --repository-name flowise-server \
    --image-ids imageTag=f3a21bc \
    --query 'imageDetails[0].imageDigest' \
    --output text
```

### Kiểm Tra Deployment Status

```bash
# Check ArgoCD app status
argocd app get flowise-dev

# Check pods
kubectl get pods -n flowise-dev

# Check image đang chạy
kubectl get deployment flowise-server -n flowise-dev -o jsonpath='{.spec.template.spec.containers[0].image}'
```

### Debug Workflow Không Trigger

1. **Check webhook delivery** (nếu dùng repository_dispatch):
   - Vào DevOps repo → Settings → Webhooks
   - Xem Recent Deliveries

2. **Check GITOPS_TOKEN permissions**:
   - Token phải có quyền `repo` và `workflow`
   - Token chưa expired

3. **Check workflow file syntax**:
   ```bash
   # Validate YAML
   yamllint .github/workflows/update-flowise-deployment.yml
   ```

4. **Manual test repository_dispatch**:
   ```bash
   curl -X POST \
     -H "Accept: application/vnd.github+json" \
     -H "Authorization: Bearer $GITOPS_TOKEN" \
     https://api.github.com/repos/TomJennyDev/devops/dispatches \
     -d '{
       "event_type": "flowise-image-updated",
       "client_payload": {
         "environment": "dev",
         "tag": "test123",
         "sha": "abc123",
         "server_digest": "",
         "ui_digest": "",
         "actor": "test-user",
         "workflow_run_id": "12345"
       }
     }'
   ```

## Lợi Ích của Kiến Trúc Này

### 1. Separation of Concerns
- **Flowise repo**: Focus vào source code, build images
- **DevOps repo**: Focus vào deployment config, GitOps

### 2. Immutable Deployments
- Dùng image digests (sha256) thay vì tags
- Đảm bảo deploy đúng image, không bị override

### 3. GitOps Best Practices
- Git là single source of truth
- Mọi thay đổi đều tracked qua commits
- Dễ rollback bằng cách revert commits

### 4. Audit Trail
- Workflow logs ghi lại ai trigger, khi nào, deploy gì
- Git commits ghi lại lịch sử thay đổi deployment

### 5. Environment Isolation
- Dev / Staging / Production hoàn toàn tách biệt
- Mỗi environment có kustomize overlay riêng

### 6. Zero-Downtime Deployment
- Kubernetes rolling update
- ArgoCD health checks
- Automatic rollback nếu deployment fail

## Troubleshooting

### Issue: Workflow không trigger từ Flowise repo

**Cause**: GITOPS_TOKEN không có quyền hoặc expired

**Solution**:
```bash
# Tạo token mới
# Thêm vào Flowise repo secrets
# Test bằng curl (xem phần Debug)
```

### Issue: Image digest không tìm thấy

**Cause**: Image chưa được push lên ECR hoặc tag không đúng

**Solution**:
```bash
# Check image tồn tại
aws ecr describe-images \
    --repository-name flowise-server \
    --image-ids imageTag=<tag>

# Nếu không có, workflow sẽ fallback dùng tag thay vì digest
```

### Issue: ArgoCD không sync

**Cause**: Auto-sync disabled hoặc sync failed

**Solution**:
```bash
# Check app status
argocd app get flowise-dev

# Manual sync
argocd app sync flowise-dev

# Check sync errors
argocd app get flowise-dev --show-operation
```

### Issue: Pods không restart sau update image

**Cause**: Digest giống nhau (không có thay đổi)

**Solution**:
- Đảm bảo mỗi build có commit SHA khác nhau
- Digest sẽ khác nhau → Kubernetes detect change → restart pods

## Best Practices

1. **Luôn review workflow logs** trước khi deploy production
2. **Test trên dev environment** trước khi deploy staging/production
3. **Monitor ArgoCD UI** trong quá trình deployment
4. **Check pod health** sau khi deployment hoàn thành
5. **Backup database** trước khi deploy breaking changes
6. **Document breaking changes** trong commit message
7. **Use semantic versioning** cho production releases

## Next Steps

1. ✅ Deploy workflow files lên GitHub
2. ✅ Config secrets (AWS, GITOPS_TOKEN)
3. 🔄 Test end-to-end pipeline với test commit
4. 📊 Setup monitoring/alerts cho deployment failures
5. 🚀 Add staging/production environments
6. 📝 Document rollback procedures
