# 🏗️ Architecture Explained - Tại sao cấu trúc như vậy?

Giải thích **TẠI SAO** phải tạo cấu trúc này và **TÁC DỤNG** của từng file.

---

## 🎯 Vấn đề cần giải quyết

### ❌ Cách cũ (không tốt)

```bash
# Cài bằng Helm trực tiếp
helm install prometheus prometheus-community/kube-prometheus-stack \
  --set prometheus.retention=7d \
  --set grafana.adminPassword=admin123 \
  --set prometheus.replicas=1
  # ... 50+ dòng --set khác

# Vấn đề:
# 1. Không có version control (không biết ai đổi gì, khi nào)
# 2. Không tái sử dụng được cho dev/staging/prod
# 3. Phải nhớ tất cả --set flags
# 4. Không tự động sync khi code thay đổi
# 5. Không có audit trail
```

### ✅ Cách mới (GitOps)

```bash
# Chỉ cần 1 command
kubectl apply -f app-of-apps-kustomize-dev.yaml

# Ưu điểm:
# ✅ Code trong Git = Single source of truth
# ✅ Tự động sync khi code thay đổi
# ✅ Rollback dễ dàng (git revert)
# ✅ Review changes qua Pull Requests
# ✅ Audit trail đầy đủ (git log)
# ✅ Reuse cho nhiều environments
```

---

## 📂 Cấu trúc và Lý do

### Cấu trúc tổng quan

```
argocd/
├── 📄 app-of-apps-kustomize-dev.yaml       → ENTRY POINT cho Dev
├── 📄 app-of-apps-kustomize-staging.yaml   → ENTRY POINT cho Staging
├── 📄 app-of-apps-kustomize-prod.yaml      → ENTRY POINT cho Prod
│
├── 📁 system-apps-kustomize/               → App definitions
│   └── prometheus/
│       ├── base/                           → Common template
│       └── overlays/                       → Environment-specific
│           ├── dev/
│           ├── staging/
│           └── prod/
│
└── 📁 helm-values/                         → Configuration
    └── prometheus/
        ├── dev-values.yaml
        ├── staging-values.yaml
        └── prod-values.yaml
```

---

## 🔍 Chi tiết từng file

### 1️⃣ **app-of-apps-kustomize-dev.yaml**

**Tác dụng:** Entry point để deploy TẤT CẢ apps cho Dev environment

**Tại sao cần:**

- ❌ **Không có:** Phải `kubectl apply` từng app một → mất thời gian
- ✅ **Có:** Deploy tất cả apps bằng 1 command → nhanh, đồng bộ

**Nội dung:**

```yaml
# File này là "master app" quản lý các apps khác
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: system-apps-dev-kustomize
spec:
  sources:
    - path: argocd/system-apps-kustomize/prometheus/overlays/dev
    # - path: argocd/system-apps-kustomize/grafana/overlays/dev
    # - path: argocd/system-apps-kustomize/nginx/overlays/dev
    # Thêm apps khác ở đây
```

**Pattern:** App of Apps

- **Nguồn:** <https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/>
- **Tại sao:** Quản lý nhiều apps như 1 đơn vị duy nhất
- **Lợi ích:** Bootstrap cả cluster chỉ với 1 file

---

### 2️⃣ **system-apps-kustomize/prometheus/base/application.yaml**

**Tác dụng:** Template chung cho Prometheus Application (dùng cho tất cả environments)

**Tại sao cần:**

- ❌ **Không có:** Phải duplicate code cho dev/staging/prod → vi phạm DRY principle
- ✅ **Có:** Viết 1 lần, override chỗ khác biệt → maintainable

**Nội dung:**

```yaml
# Template này chứa phần GIỐNG NHAU giữa dev/staging/prod
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: prometheus  # ← Sẽ được override thành prometheus-dev, prometheus-staging
spec:
  sources:
    - repoURL: https://prometheus-community.github.io/helm-charts
      chart: kube-prometheus-stack
      targetRevision: 65.2.0  # ← Version giống nhau
      helm:
        valueFiles:
          - REPLACE_ENV-values.yaml  # ← Sẽ được override
  destination:
    namespace: monitoring  # ← Giống nhau
  syncPolicy:
    automated: true  # ← Giống nhau
```

**Pattern:** DRY (Don't Repeat Yourself)

- **Lợi ích:** Sửa 1 chỗ → apply cho tất cả environments
- **Example:** Upgrade chart từ 65.2.0 → 66.0.0 → chỉ sửa base, tất cả envs được upgrade

---

### 3️⃣ **system-apps-kustomize/prometheus/base/kustomization.yaml**

**Tác dụng:** Kustomize manifest cho base layer

**Tại sao cần:**

- Kustomize yêu cầu file này để biết resources nào cần load
- Định nghĩa namespace chung

**Nội dung:**

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: argocd  # Tất cả ArgoCD Applications đều trong namespace argocd

resources:
  - application.yaml  # Load base template
```

**Không có file này:** Kustomize sẽ báo lỗi không tìm thấy resources

---

### 4️⃣ **system-apps-kustomize/prometheus/overlays/dev/kustomization.yaml**

**Tác dụng:** Customize base template cho Dev environment

**Tại sao cần:**

- ❌ **Không có:** Dev và Prod dùng cấu hình giống nhau → không hợp lý
  - Dev cần resources thấp, Prod cần resources cao
  - Dev có thể auto-sync, Prod cần manual approve
- ✅ **Có:** Mỗi environment có config phù hợp

**Nội dung:**

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base  # Kế thừa base template

patches:  # Override những gì khác biệt
  - target:
      name: prometheus
    patch: |-
      # Đổi tên: prometheus → prometheus-dev
      - op: replace
        path: /metadata/name
        value: prometheus-dev

      # Add label environment
      - op: add
        path: /metadata/labels
        value:
          environment: dev

      # Đổi values file: dev-values.yaml
      - op: replace
        path: /spec/sources/0/helm/valueFiles/0
        value: $values/argocd/helm-values/prometheus/dev-values.yaml
```

**Pattern:** Kustomize Overlays

- **Nguồn:** <https://kubectl.docs.kubernetes.io/references/kustomize/glossary/#overlay>
- **Lợi ích:** Inheritance + Customization
- **Format:** JSON Patch (RFC 6902) - <https://tools.ietf.org/html/rfc6902>

---

### 5️⃣ **helm-values/prometheus/dev-values.yaml**

**Tác dụng:** Prometheus configuration cho Dev environment

**Tại sao cần:**

- Tách configuration ra khỏi application definition
- Dễ review changes (chỉ xem config, không lẫn với infrastructure code)
- Reusable cho Helm upgrade trực tiếp (nếu cần)

**Nội dung:**

```yaml
# Dev: Low resources, short retention (cost optimization)
prometheus:
  prometheusSpec:
    retention: 7d      # Dev: 7 days
    replicas: 1        # Dev: Single replica
    resources:
      requests:
        cpu: 200m      # Dev: 0.2 CPU core
        memory: 1Gi

grafana:
  adminPassword: "admin123"  # Dev: Simple password
  replicas: 1
  ingress:
    enabled: false   # Dev: No public access
```

**So sánh với Prod:**

```yaml
# Prod: High resources, long retention (HA + history)
prometheus:
  prometheusSpec:
    retention: 30d     # Prod: 30 days (4x longer)
    replicas: 3        # Prod: HA with 3 replicas
    resources:
      requests:
        cpu: 1000m     # Prod: 1 CPU core (5x more)
        memory: 4Gi    # Prod: 4GB (4x more)

grafana:
  adminPassword: "USE_SEALED_SECRET"  # Prod: Secure
  replicas: 3
  ingress:
    enabled: true    # Prod: Public access with SSL
```

**Tại sao tách file:**

- ✅ Dễ so sánh diff giữa environments
- ✅ Dễ review trong Pull Request
- ✅ Có thể test với Helm trước khi commit

---

### 6️⃣ **helm-values/prometheus/default-values-reference.yaml**

**Tác dụng:** Reference đầy đủ ALL options từ official chart (5413 dòng)

**Tại sao cần:**

- ❌ **Không có:** Phải mở browser, search docs, copy/paste → chậm
- ✅ **Có:** Tất cả options trong 1 file local → search nhanh

**Cách dùng:**

```bash
# Tìm option cần customize
grep -n "retention" default-values-reference.yaml

# Output:
# 1234: retention: 10d
# 1235: retentionSize: "50GB"

# Copy structure vào dev-values.yaml và customize
```

**Nguồn:**

```bash
helm show values prometheus-community/kube-prometheus-stack > default-values-reference.yaml
```

---

## 🔄 Flow hoạt động (End-to-End)

### Scenario: Deploy Prometheus cho Dev

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Developer chạy command                                   │
│    $ kubectl apply -f app-of-apps-kustomize-dev.yaml       │
└────────────────────────┬────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. Kubernetes API tạo ArgoCD Application                    │
│    Name: system-apps-dev-kustomize                          │
│    Type: Application (ArgoCD CRD)                           │
└────────────────────────┬────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. ArgoCD Controller nhận notification                      │
│    "New Application created"                                │
└────────────────────────┬────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. ArgoCD đọc source path                                   │
│    Path: system-apps-kustomize/prometheus/overlays/dev     │
│    Clone Git repo                                           │
└────────────────────────┬────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ 5. ArgoCD chạy Kustomize build                              │
│    $ kustomize build overlays/dev                           │
│                                                             │
│    5a. Load base/application.yaml                           │
│    5b. Apply patches từ dev/kustomization.yaml             │
│    5c. Output: Final Application YAML                       │
└────────────────────────┬────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ 6. ArgoCD tạo child Application                             │
│    Name: prometheus-dev (sau khi patch)                     │
│    Values: dev-values.yaml (sau khi patch)                  │
└────────────────────────┬────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ 7. ArgoCD Helm Controller process Application               │
│    - Download chart từ Helm repo                            │
│    - Download values từ Git repo                            │
│    - Merge values với chart defaults                        │
└────────────────────────┬────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ 8. Helm template generation                                 │
│    $ helm template prometheus \                             │
│      prometheus-community/kube-prometheus-stack \           │
│      -f dev-values.yaml                                     │
│    Output: ~1000 Kubernetes manifests                       │
└────────────────────────┬────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ 9. ArgoCD apply manifests to cluster                        │
│    - Create namespace: monitoring                           │
│    - Create ServiceAccounts                                 │
│    - Create ConfigMaps                                      │
│    - Create Deployments (Prometheus, Grafana)               │
│    - Create StatefulSets (Prometheus, AlertManager)         │
│    - Create Services                                        │
│    - Create PVCs (persistent volumes)                       │
└────────────────────────┬────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ 10. Kubernetes Scheduler deploy pods                        │
│     - prometheus-kube-prometheus-prometheus-0               │
│     - prometheus-grafana-xxx                                │
│     - prometheus-kube-state-metrics-xxx                     │
│     - alertmanager-xxx                                      │
└────────────────────────┬────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ 11. ArgoCD Health Check                                     │
│     - Check all pods Running                                │
│     - Check all services Ready                              │
│     - Report: Synced + Healthy                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 🎓 Tại sao mỗi layer?

### Layer 1: App of Apps (app-of-apps-kustomize-dev.yaml)

**Giải quyết:** Deploy multiple apps as a unit

**Ví dụ thực tế:**

```bash
# Không có App of Apps:
kubectl apply -f prometheus.yaml
kubectl apply -f grafana.yaml
kubectl apply -f nginx.yaml
kubectl apply -f cert-manager.yaml
# ... 20 apps khác

# Có App of Apps:
kubectl apply -f app-of-apps-dev.yaml  # Deploy tất cả
```

### Layer 2: Kustomize Base (base/)

**Giải quyết:** Share common config

**Ví dụ thực tế:**

```yaml
# Chart version upgrade
# Không có base: Sửa 3 files (dev, staging, prod)
# Có base: Sửa 1 file (base), tất cả envs update
```

### Layer 3: Kustomize Overlays (overlays/dev, staging, prod)

**Giải quyết:** Environment-specific customization

**Ví dụ thực tế:**

```yaml
Dev:
  - 1 replica (đủ dùng)
  - 7d retention (không cần history lâu)
  - No ingress (chỉ port-forward)
  - Simple password

Prod:
  - 3 replicas (HA)
  - 30d retention (compliance requirement)
  - Public ingress with SSL
  - Sealed Secret password
```

### Layer 4: Helm Values (helm-values/)

**Giải quyết:** Separate configuration from code

**Ví dụ thực tế:**

```bash
# Developer muốn review change
git diff dev-values.yaml

# Output:
- retention: 7d
+ retention: 15d

# Dễ hiểu, không lẫn với infrastructure code
```

---

## 💡 Best Practices được apply

### 1. **GitOps**

- **Source:** <https://www.gitops.tech/>
- **Benefit:** Git = Single source of truth
- **Files:** Tất cả configs trong Git

### 2. **DRY (Don't Repeat Yourself)**

- **Source:** <https://en.wikipedia.org/wiki/Don%27t_repeat_yourself>
- **Benefit:** Maintainable, less bugs
- **Files:** base/ chứa common code

### 3. **Separation of Concerns**

- **Source:** <https://en.wikipedia.org/wiki/Separation_of_concerns>
- **Benefit:** Easy to understand, test, debug
- **Files:**
  - App definition: system-apps-kustomize/
  - Configuration: helm-values/
  - Entry points: app-of-apps-*.yaml

### 4. **Infrastructure as Code**

- **Source:** <https://www.terraform.io/use-cases/infrastructure-as-code>
- **Benefit:** Version control, reproducible, auditable
- **Files:** Tất cả YAML files

### 5. **Environment Parity**

- **Source:** <https://12factor.net/dev-prod-parity>
- **Benefit:** Dev gần giống Prod → ít bugs
- **Files:** base/ giống nhau, overlays/ khác biệt tối thiểu

---

## 🔍 So sánh với các approaches khác

### Approach 1: Manual Helm (❌ Không tốt)

```bash
# Dev
helm install prometheus ... --set retention=7d --set replicas=1

# Staging
helm install prometheus ... --set retention=15d --set replicas=2

# Prod
helm install prometheus ... --set retention=30d --set replicas=3

# Vấn đề:
# - Không có Git history
# - Không tự động sync
# - Dễ quên commands
# - Không có review process
```

### Approach 2: Helm + Values files (🟡 OK nhưng chưa tốt)

```bash
# Có values files nhưng deploy bằng Helm CLI
helm install prometheus -f dev-values.yaml

# Vấn đề:
# - Vẫn phải chạy command manual
# - Không tự động sync khi Git thay đổi
# - Không có centralized management
```

### Approach 3: ArgoCD + Helm + Kustomize (✅ Tốt nhất)

```bash
# Deploy 1 lần, ArgoCD tự động sync mãi mãi
kubectl apply -f app-of-apps-dev.yaml

# Lợi ích:
# ✅ GitOps workflow
# ✅ Auto sync
# ✅ Multi-environment support
# ✅ Centralized management
# ✅ Audit trail
# ✅ Rollback easy
```

---

## 📊 Metrics & Benefits

### Trước khi có cấu trúc này

- ⏱️ Deploy time: 30-60 phút (manual, error-prone)
- 🐛 Config drift: Thường xuyên (dev ≠ prod)
- 📝 Documentation: Outdated (docs ≠ actual state)
- 🔄 Rollback: Khó (không biết config cũ như thế nào)
- 👥 Collaboration: Khó (không có review process)

### Sau khi có cấu trúc này

- ⏱️ Deploy time: 5-10 phút (automated)
- 🐛 Config drift: Không có (Git = source of truth)
- 📝 Documentation: Always updated (code = docs)
- 🔄 Rollback: Dễ (`git revert` + ArgoCD sync)
- 👥 Collaboration: Dễ (Pull Requests + reviews)

---

## 🎯 Tổng kết

| File/Folder | Tác dụng | Tại sao cần | Pattern |
|-------------|----------|-------------|---------|
| **app-of-apps-*.yaml** | Entry point | Deploy tất cả apps cùng lúc | App of Apps |
| **base/application.yaml** | Common template | Tránh duplicate code | DRY |
| **base/kustomization.yaml** | Kustomize manifest | Kustomize yêu cầu | Kustomize Spec |
| **overlays/*/kustomization.yaml** | Env customization | Mỗi env khác config | Overlays Pattern |
| **helm-values/*.yaml** | Prometheus config | Tách config khỏi code | Separation of Concerns |
| **default-values-reference.yaml** | Full chart options | Reference nhanh | Documentation |

**Cốt lõi:**

- 📝 **Write once** (base)
- 🔧 **Customize minimal** (overlays)
- 🔄 **Auto sync forever** (ArgoCD)
- 🎯 **Git is truth** (GitOps)

---

**Đọc tiếp:**

- GETTING-STARTED.md → Cách deploy thực tế
- PROMETHEUS-README.md → Chi tiết về stack
- SOURCES.md → Tài liệu chính thức
