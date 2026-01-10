# WAF Architecture Position

## Current Setup (Đã implement)

```
┌─────────────────────────────────────────────────────────────┐
│                         Internet                            │
│                  flowise-dev.do2506.click                   │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ HTTPS (443)
                         ▼
                ┌────────────────┐
                │   Route53 DNS  │
                │  CNAME Record  │
                └────────┬───────┘
                         │
                         ▼
┌────────────────────────────────────────────────────────────┐
│              AWS WAF (Regional)                            │
│  Rules:                                                    │
│  - SQL Injection Protection                                │
│  - XSS Protection                                          │
│  - Rate Limiting (2000 req/5min)                           │
│  - AWS Managed Rules                                       │
│                                                            │
│  Attached to: ALB via annotation                           │
│  alb.ingress.kubernetes.io/wafv2-acl-arn: arn:aws:...     │
└────────────────────────┬───────────────────────────────────┘
                         │
                         │ Filtered Traffic
                         ▼
┌────────────────────────────────────────────────────────────┐
│      Application Load Balancer (ALB)                       │
│      flowise-dev-alb                                       │
│                                                            │
│  Listeners:                                                │
│  - Port 80 → Redirect to 443                               │
│  - Port 443 → Target Groups                                │
│                                                            │
│  ACM Certificate: *.do2506.click                           │
└────────────────────────┬───────────────────────────────────┘
                         │
         ┌───────────────┴───────────────┐
         │                               │
         ▼                               ▼
┌──────────────────┐          ┌──────────────────┐
│  Target Group 1  │          │  Target Group 2  │
│  flowise-ui:80   │          │  flowise-srv:3000│
└────────┬─────────┘          └────────┬─────────┘
         │                              │
         │   Inside Kubernetes (EKS)   │
         │                              │
         ▼                              ▼
┌─────────────────────────────────────────────┐
│        AWS Load Balancer Controller         │
│        (quản lý ALB từ trong K8s)           │
└─────────────────┬───────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────┐
│              Ingress Resource               │
│         flowise-ingress (flowise-dev ns)    │
│                                             │
│  Rules:                                     │
│  - Path: /     → flowise-ui:80              │
│  - Path: /api  → flowise-server:3000        │
└─────────────────┬───────────────────────────┘
                  │
         ┌────────┴────────┐
         │                 │
         ▼                 ▼
  ┌──────────┐      ┌──────────┐
  │Service UI│      │Service   │
  │ClusterIP │      │Server    │
  └────┬─────┘      └────┬─────┘
       │                 │
       ▼                 ▼
  ┌──────────┐      ┌──────────┐
  │Pod UI    │      │Pod Server│
  │Flowise   │      │Flowise   │
  │Frontend  │      │Backend   │
  └──────────┘      └──────────┘
```

## Vị trí WAF trong Diagram của bạn

Looking at your architecture diagram:

1. **Top section** - GitHub Actions/Terraform
2. **Middle section** - AWS Services (ALB màu đỏ, EKS clusters)
3. **Bottom section** - 3 environments (Route53, ArgoCD, Apps)

**WAF should be drawn as:**

```
[Internet] 
    ↓
[Route53 DNS]
    ↓
┌─────────────────────┐
│   AWS WAF (Shield)  │  ← ⚠️ MISSING in diagram
│   Regional WebACL   │
└─────────────────────┘
    ↓
[ALB - màu đỏ ở giữa]
    ↓
[Ingress Controller]
    ↓
[Services/Pods]
```

## Where WAF Lives in Your Terraform

```
terraform-eks/
├── modules/
│   └── waf/              ← WAF module
│       ├── main.tf       ← Creates WAF WebACL
│       ├── variables.tf
│       └── outputs.tf    ← waf_web_acl_arn
├── main.tf               ← Calls module.waf
└── environments/
    └── dev/
        ├── main.tf       ← Pass WAF variables ✅
        └── terraform.tfvars  ← enable_waf = true
```

## Where WAF is Referenced

```
argocd/apps/flowise/overlays/dev/ingress.yaml
    ↓
annotations:
  alb.ingress.kubernetes.io/wafv2-acl-arn: arn:aws:wafv2:...
    ↓
AWS Load Balancer Controller reads annotation
    ↓
Associates WAF with ALB
```

## Visual Layers

```
Layer 7 (App)      │ Flowise Application
Layer 6 (K8s)      │ Ingress → Service → Pods
Layer 5 (Network)  │ AWS ALB (Load Balancer)
Layer 4 (Security) │ ⭐ AWS WAF ← HERE!
Layer 3 (CDN)      │ (Optional) CloudFront
Layer 2 (DNS)      │ Route53
Layer 1 (User)     │ Internet/Browser
```

## Recommendation: Update Diagram

Add WAF icon (shield) between Route53 and ALB:

```
User → Internet → Route53
                    ↓
                [AWS WAF 🛡️]  ← Add this
                    ↓
                  [ALB]
                    ↓
                [Ingress]
```

**Icon suggestion:** 
- AWS WAF Shield icon (purple/pink shield)
- Position: Between Route53 and ALB
- Connection: Shows traffic filtering
