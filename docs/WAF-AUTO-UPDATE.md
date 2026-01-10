# Giải pháp Dynamic WAF Configuration - Thực tế

## Vấn đề
Sau khi chạy `terraform apply`, WAF ARN mới được tạo nhưng ingress vẫn dùng ARN cũ hoặc chưa có.

## Giải pháp Đã Implement

### 1. Auto-Update trong Terraform (terraform-eks/main.tf)
```hcl
resource "null_resource" "update_waf_ingress" {
  count = var.enable_waf ? 1 : 0

  triggers = {
    waf_arn = module.waf.waf_web_acl_arn
  }

  provisioner "local-exec" {
    command = "sed -i 's|alb.ingress.kubernetes.io/wafv2-acl-arn:.*|alb.ingress.kubernetes.io/wafv2-acl-arn: ${module.waf.waf_web_acl_arn}|' ../../argocd/apps/flowise/overlays/${var.environment}/ingress.yaml"
  }

  depends_on = [module.waf]
}
```

**Cách hoạt động:**
- Terraform tạo WAF
- `local-exec` tự động update ingress.yaml với WAF ARN mới
- File thay đổi trong git working directory
- Bạn chỉ cần commit & push

### 2. Post-Deployment Script (scripts/post-terraform-deploy.sh)
```bash
#!/bin/bash
# Auto-commit ingress changes after terraform
cd /path/to/repo
git add argocd/apps/flowise/overlays/*/ingress.yaml
git commit -m "chore: auto-update WAF ARN [terraform]"
git push origin main  # optional - cần confirm
```

## Workflow Đơn Giản

### Cách 1: Manual (có control)
```bash
# Bước 1: Deploy infrastructure
cd terraform-eks/environments/dev
terraform apply

# Ingress đã được update tự động bởi local-exec

# Bước 2: Commit changes
cd ../../..
./scripts/post-terraform-deploy.sh

# Bước 3: Verify
./scripts/check-flowise-health.sh
```

### Cách 2: Một lệnh (fully automated)
```bash
./scripts/deploy-dev.sh

# Script này sẽ:
# 1. terraform apply
# 2. auto-commit ingress changes
# 3. (optional) push to git
```

## Testing

```bash
# Test WAF ARN đã update chưa
cd terraform-eks/environments/dev
terraform output waf_web_acl_arn

# Check ingress file
cat ../../argocd/apps/flowise/overlays/dev/ingress.yaml | grep wafv2-acl-arn

# Chúng phải match!
```

## Ưu điểm

✅ **Tự động**: Terraform tự update ingress  
✅ **Đơn giản**: Không cần script phức tạp  
✅ **GitOps**: Vẫn commit vào git, ArgoCD sync  
✅ **Safe**: File thay đổi trong working dir, bạn review trước khi push  
✅ **Multi-env**: Dùng `${var.environment}` để support dev/staging/prod  

## Nhược điểm

⚠️ **File local thay đổi**: Cần commit sau terraform apply  
⚠️ **sed command**: Có thể khác trên macOS vs Linux  

## Cải tiến (Optional)

### Option A: Store WAF ARN in Kubernetes ConfigMap
```bash
# Terraform creates ConfigMap
resource "kubernetes_config_map" "terraform_outputs" {
  metadata {
    name      = "terraform-outputs"
    namespace = "flowise-dev"
  }
  data = {
    waf_arn = module.waf.waf_web_acl_arn
  }
}

# Ingress references ConfigMap (requires custom operator or manual)
```

### Option B: External Secrets Operator (Production)
- Store WAF ARN in AWS SSM Parameter Store
- External Secrets Operator sync to K8s Secret
- Ingress references Secret

## Recommendation

**Hiện tại (Dev):** Dùng giải pháp đã implement  
**Production:** Upgrade to External Secrets Operator

## Files Liên Quan

- `terraform-eks/main.tf` - Auto-update logic
- `scripts/post-terraform-deploy.sh` - Commit helper
- `scripts/deploy-dev.sh` - One-command deploy
- `argocd/apps/flowise/overlays/dev/ingress.yaml` - Target file
