# DNS trong EKS Cluster

Có 2 loại DNS trong kiến trúc EKS:

## 1. 🔵 CoreDNS (Internal DNS - ĐÃ CÓ SẴN)

**Mục đích:** DNS resolution BÊN TRONG cluster

### Đã được Terraform cài đặt
- ✅ CoreDNS được enable mặc định trong EKS
- ✅ Terraform đã cấu hình addon: `coredns_version = "v1.11.3-eksbuild.1"`
- ✅ Runs như một Deployment trong `kube-system` namespace

### Chức năng
```
Pod A → Service Name → CoreDNS → Service ClusterIP → Pod B

Examples:
- my-service.default.svc.cluster.local
- database.production.svc.cluster.local
- redis.default
```

### Kiểm tra CoreDNS
```bash
# Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Check CoreDNS config
kubectl get configmap coredns -n kube-system -o yaml

# Test DNS resolution from pod
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default
```

### CoreDNS Config
```yaml
# Default CoreDNS config (managed by EKS)
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        health {
            lameduck 5s
        }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
            pods insecure
            fallthrough in-addr.arpa ip6.arpa
        }
        prometheus :9153
        forward . /etc/resolv.conf
        cache 30
        loop
        reload
        loadbalance
    }
```

### ✅ KHÔNG CẦN CẤU HÌNH GÌ THÊM
CoreDNS tự động hoạt động cho:
- Service discovery (service-name → ClusterIP)
- Pod-to-Pod communication
- Namespace DNS resolution

---

## 2. 🔴 External DNS (External DNS - OPTIONAL)

**Mục đích:** Tạo DNS records trên Route53 cho traffic từ INTERNET

### Cần cài đặt thủ công (qua ArgoCD)
- ❌ KHÔNG có sẵn trong EKS
- ❌ Cần enable trong Terraform: `enable_external_dns = true`
- ❌ Cần deploy qua ArgoCD

### Chức năng
```
Internet Users → Route53 → ALB/NLB → Service → Pods

Examples:
- www.example.com → ALB → frontend-service
- api.example.com → NLB → backend-service
```

### Khi nào cần External DNS?
✅ **CẦN** nếu:
- Expose apps ra Internet với custom domain
- Muốn tự động tạo Route53 records
- Sử dụng Ingress/LoadBalancer với domain names

❌ **KHÔNG CẦN** nếu:
- Chỉ internal services
- Sử dụng ALB DNS name (k8s-xxx.elb.amazonaws.com)
- Quản lý DNS manually

---

## 🔄 So sánh

| Feature | CoreDNS | External DNS |
|---------|---------|--------------|
| **Scope** | Internal cluster | External (Internet) |
| **Provider** | Kubernetes | AWS Route53 |
| **Managed by** | EKS addon | ArgoCD Helm chart |
| **Setup** | ✅ Automatic | ❌ Manual install |
| **Use case** | Service discovery | Public DNS records |
| **Example** | redis.default → 10.0.1.5 | api.example.com → ALB |
| **Required** | ✅ Yes (always) | ❌ No (optional) |

---

## 📊 Workflow Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    Internet Users                        │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ↓
            ┌──────────────────────┐
            │   Route53 DNS        │  ← External DNS creates/updates
            │   example.com        │
            └──────────┬───────────┘
                       │
                       ↓
            ┌──────────────────────┐
            │   AWS ALB/NLB        │
            └──────────┬───────────┘
                       │
                       ↓
┌──────────────────────────────────────────────────────────┐
│                    EKS Cluster                           │
│                                                          │
│  ┌───────────────────────────────────────────────────┐  │
│  │  CoreDNS (kube-system)                            │  │ ← EKS Addon (automatic)
│  │  - Resolves: service-name → ClusterIP            │  │
│  └───────────────────────────────────────────────────┘  │
│                                                          │
│  ┌─────────┐      ┌─────────┐      ┌─────────┐        │
│  │ Pod A   │─────→│ Service │─────→│ Pod B   │        │
│  │ (app)   │      │ (redis) │      │ (redis) │        │
│  └─────────┘      └─────────┘      └─────────┘        │
│       │                                                 │
│       └─→ nslookup redis.default → CoreDNS → ClusterIP │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

---

## 🎯 Ví dụ Thực tế

### Scenario 1: Internal Service (Chỉ dùng CoreDNS)

```yaml
# backend-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: backend-api
  namespace: default
spec:
  type: ClusterIP  # Internal only
  ports:
  - port: 8080
  selector:
    app: backend
```

**DNS Resolution:**
```bash
# Từ bất kỳ pod nào trong cluster
curl http://backend-api.default.svc.cluster.local:8080
curl http://backend-api.default:8080  # Short form
curl http://backend-api:8080          # Same namespace
```
✅ CoreDNS tự động resolve, không cần External DNS!

---

### Scenario 2: Public Service (CoreDNS + External DNS)

```yaml
# frontend-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: frontend
  annotations:
    # External DNS tạo Route53 record
    external-dns.alpha.kubernetes.io/hostname: www.example.com
spec:
  ingressClassName: alb
  rules:
  - host: www.example.com
    http:
      paths:
      - path: /
        backend:
          service:
            name: frontend
            port:
              number: 80
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
spec:
  type: ClusterIP  # Internal service
  ports:
  - port: 80
  selector:
    app: frontend
```

**DNS Resolution:**
1. **External (Internet):** `www.example.com` → Route53 (External DNS) → ALB → Service
2. **Internal (Cluster):** `frontend.default` → CoreDNS → ClusterIP

---

## ✅ Khuyến nghị cho Project của bạn

### Đã có sẵn (EKS Addon):
- ✅ **CoreDNS**: Service discovery trong cluster
- ✅ **VPC CNI**: Pod networking
- ✅ **kube-proxy**: Service routing

### Cần cài thêm (ArgoCD):
- 🔵 **AWS Load Balancer Controller**: Bắt buộc cho Ingress/ALB
- 🟡 **Metrics Server**: Bắt buộc cho HPA
- 🟢 **External DNS**: **Optional** - chỉ khi cần public domains

### Quyết định External DNS:

**Enable External DNS nếu:**
```
✅ Có domain riêng (example.com)
✅ Muốn tự động quản lý DNS
✅ Nhiều Ingress/Services cần expose
✅ CI/CD tự động deploy
```

**Không cần External DNS nếu:**
```
❌ Chỉ internal services
❌ OK với ALB DNS name (k8s-xxx.elb.amazonaws.com)
❌ Quản lý DNS manually qua AWS Console
❌ Dev/Test environment đơn giản
```

---

## 🛠️ Cấu hình trong Terraform

```hcl
# terraform.tfvars

# CoreDNS - ĐÃ ENABLE MẶC ĐỊNH
enable_cluster_addons = true
coredns_version       = "v1.11.3-eksbuild.1"

# External DNS - TÙY CHỌN
enable_external_dns = false  # Set true nếu cần
route53_zone_arns = [
  # "arn:aws:route53:::hostedzone/Z1234567890ABC"
]
```

---

## 📚 Tài liệu liên quan

- CoreDNS: Built-in, xem EKS addon documentation
- External DNS: `argocd/examples/external-dns-route53-setup.md`
- Ingress with ACM: `argocd/examples/ingress-with-acm.md`
