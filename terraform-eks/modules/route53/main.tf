# ========================================
# Route53 DNS Records
# ========================================

data "aws_route53_zone" "main" {
  count = var.create_dns_records ? 1 : 0

  name         = var.domain_name
  private_zone = false
}

# ArgoCD DNS Record
resource "aws_route53_record" "argocd" {
  count = var.create_dns_records && var.argocd_enabled ? 1 : 0

  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = "argocd.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.argocd_alb_dns_name
    zone_id                = var.argocd_alb_zone_id
    evaluate_target_health = true
  }
}

# Wildcard DNS Record (Optional - for app ingresses)
resource "aws_route53_record" "wildcard" {
  count = var.create_dns_records && var.create_wildcard_record ? 1 : 0

  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = "*.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.wildcard_alb_dns_name
    zone_id                = var.wildcard_alb_zone_id
    evaluate_target_health = true
  }
}
