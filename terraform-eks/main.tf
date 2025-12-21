# ========================================
# ROOT MODULE - MODULAR STRUCTURE
# ========================================
# Enterprise-level structure with separate modules

# ========================================
# PROVIDER CONFIGURATION
# ========================================
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.common_tags
  }
}

# ========================================
# VPC MODULE
# ========================================
module "vpc" {
  source = "./modules/vpc"

  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
  nat_gateway_count    = var.nat_gateway_count
  cluster_name         = var.cluster_name
  common_tags          = var.common_tags
}

# ========================================
# IAM MODULE
# ========================================
module "iam" {
  source = "./modules/iam"
  
  cluster_name = var.cluster_name
  common_tags  = var.common_tags
}

# ========================================
# SECURITY GROUPS MODULE
# ========================================
module "security_groups" {
  source = "./modules/security-groups"
  
  cluster_name            = var.cluster_name
  vpc_id                  = module.vpc.vpc_id
  enable_node_ssh_access  = var.enable_node_ssh_access
  ssh_allowed_cidr_blocks = var.ssh_allowed_cidr_blocks
  common_tags             = var.common_tags
}

# ========================================
# EKS MODULE
# ========================================
module "eks" {
  source = "./modules/eks"
  
  cluster_name                         = var.cluster_name
  cluster_version                      = var.cluster_version
  cluster_role_arn                     = module.iam.cluster_role_arn
  subnet_ids                           = concat(module.vpc.private_subnet_ids, module.vpc.public_subnet_ids)
  cluster_security_group_id            = module.security_groups.cluster_security_group_id
  cluster_endpoint_public_access       = var.cluster_endpoint_public_access
  cluster_endpoint_private_access      = var.cluster_endpoint_private_access
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs
  cluster_enabled_log_types            = var.cluster_enabled_log_types
  cluster_log_retention_days           = var.cluster_log_retention_days
  vpc_cni_version                      = var.vpc_cni_version
  coredns_version                      = var.coredns_version
  kube_proxy_version                   = var.kube_proxy_version
  enable_cluster_addons                = var.enable_cluster_addons
  common_tags                          = var.common_tags
  
  depends_on = [module.iam, module.security_groups]
}

# ========================================
# NODE GROUPS MODULE
# ========================================
module "node_groups" {
  source = "./modules/node-groups"
  
  cluster_name              = var.cluster_name
  cluster_version           = var.cluster_version
  node_group_name           = var.node_group_name
  node_role_arn             = module.iam.node_role_arn
  subnet_ids                = module.vpc.private_subnet_ids
  node_group_desired_size   = var.node_group_desired_size
  node_group_min_size       = var.node_group_min_size
  node_group_max_size       = var.node_group_max_size
  node_group_instance_types = var.node_group_instance_types
  node_group_capacity_type  = var.node_group_capacity_type
  node_group_disk_size      = var.node_group_disk_size
  node_group_ami_type       = var.node_group_ami_type
  node_group_labels         = var.node_group_labels
  node_group_taints         = var.node_group_taints
  enable_node_ssh_access    = var.enable_node_ssh_access
  node_ssh_key_name         = var.node_ssh_key_name
  common_tags               = var.common_tags
  
  depends_on = [module.eks]
}

# ========================================
# EKS ADDONS MODULE
# ========================================
module "eks_addons" {
  source = "./modules/eks-addons"

  cluster_name              = var.cluster_name
  enable_cluster_addons     = var.enable_cluster_addons
  vpc_cni_version           = var.vpc_cni_version
  coredns_version           = var.coredns_version
  kube_proxy_version        = var.kube_proxy_version
  ebs_csi_driver_version    = var.ebs_csi_driver_version
  ebs_csi_driver_role_arn   = aws_iam_role.ebs_csi_driver.arn
  common_tags               = var.common_tags

  depends_on = [module.eks, module.node_groups, aws_iam_role.ebs_csi_driver]
}

# ========================================
# EBS CSI DRIVER IAM ROLE (IRSA)
# ========================================
data "aws_iam_policy_document" "ebs_csi_driver_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_provider_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_provider_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi_driver" {
  name               = "${var.cluster_name}-ebs-csi-driver-role"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_driver_assume_role.json

  tags = var.common_tags
  
  depends_on = [module.eks]
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_driver.name
}

# ========================================
# ALB CONTROLLER MODULE
# ========================================
module "alb_controller" {
  source = "./modules/alb-controller"
  
  cluster_name                        = var.cluster_name
  oidc_provider_arn                   = module.eks.oidc_provider_arn
  oidc_provider_url                   = module.eks.oidc_provider_url
  enable_aws_load_balancer_controller = var.enable_aws_load_balancer_controller
  common_tags                         = var.common_tags
  
  depends_on = [module.eks]
}

# ========================================
# EXTERNAL DNS MODULE
# ========================================
module "external_dns" {
  source = "./modules/external-dns"
  
  cluster_name        = var.cluster_name
  oidc_provider_arn   = module.eks.oidc_provider_arn
  oidc_provider_url   = module.eks.oidc_provider_url
  enable_external_dns = var.enable_external_dns
  route53_zone_arns   = var.route53_zone_arns
  common_tags         = var.common_tags
  
  depends_on = [module.eks]
}

# ========================================
# ROUTE53 MODULE
# ========================================
module "route53" {
  source = "./modules/route53"
  
  domain_name             = var.domain_name
  create_dns_records      = var.create_dns_records
  argocd_enabled          = var.argocd_dns_enabled
  argocd_alb_dns_name     = var.argocd_alb_dns_name
  argocd_alb_zone_id      = var.argocd_alb_zone_id
  create_wildcard_record  = var.create_wildcard_dns_record
  wildcard_alb_dns_name   = var.wildcard_alb_dns_name
  wildcard_alb_zone_id    = var.wildcard_alb_zone_id
  
  depends_on = [module.eks]
}

# ========================================
# CLOUDFRONT DNS RECORDS
# ========================================
# Separate from Route53 module to avoid circular dependency
data "aws_route53_zone" "cloudfront" {
  count = var.create_dns_records && var.enable_cloudfront && length(var.cloudfront_aliases) > 0 ? 1 : 0
  
  name         = var.domain_name
  private_zone = false
}

resource "aws_route53_record" "cloudfront" {
  for_each = var.create_dns_records && var.enable_cloudfront && length(var.cloudfront_aliases) > 0 ? toset(var.cloudfront_aliases) : []
  
  zone_id = data.aws_route53_zone.cloudfront[0].zone_id
  name    = each.value
  type    = "A"
  
  alias {
    name                   = module.cloudfront.cloudfront_domain_name
    zone_id                = module.cloudfront.cloudfront_hosted_zone_id
    evaluate_target_health = false
  }
  
  depends_on = [module.cloudfront]
}

# ========================================
# RESOURCE LIMITS MODULE (K8s Resources)
# ========================================
module "resource_limits" {
  source = "./modules/resource-limits"
  
  count = var.enable_resource_limits ? 1 : 0
  
  namespaces              = var.resource_limit_namespaces
  limit_ranges            = var.limit_ranges
  resource_quotas         = var.resource_quotas
  priority_classes        = var.priority_classes
  pod_disruption_budgets  = var.pod_disruption_budgets
  enable_network_policies = var.enable_network_policies
  common_tags             = var.common_tags
  
  depends_on = [module.eks, module.node_groups]
}

# ========================================
# WAF MODULE (for CloudFront or ALB)
# ========================================
module "waf" {
  source = "./modules/waf"
  
  cluster_name                   = var.cluster_name
  environment                    = var.environment
  aws_region                     = var.aws_region
  enable_waf                     = var.enable_waf
  waf_scope                      = var.waf_scope
  core_rule_set_excluded_rules   = var.waf_core_rule_excluded
  enable_sql_injection_rule      = var.waf_enable_sqli_rule
  enable_linux_rule              = var.waf_enable_linux_rule
  enable_rate_limiting           = var.waf_enable_rate_limit
  rate_limit_requests            = var.waf_rate_limit_value
  enable_geo_blocking            = var.waf_enable_geo_blocking
  blocked_countries              = var.waf_blocked_countries
  enable_ip_blacklist            = var.waf_enable_ip_blacklist
  blacklist_ip_addresses         = var.waf_blacklist_ips
  enable_ip_whitelist            = var.waf_enable_ip_whitelist
  whitelist_ip_addresses         = var.waf_whitelist_ips
  enable_regex_pattern_matching  = var.waf_enable_regex
  regex_patterns                 = var.waf_regex_patterns
  enable_waf_logging             = var.waf_enable_logging
  waf_log_retention_days         = var.waf_log_retention_days
  waf_redacted_fields            = var.waf_redacted_fields
  enable_waf_alarms              = var.waf_enable_alarms
  blocked_requests_threshold     = var.waf_blocked_threshold
  rate_limited_threshold         = var.waf_rate_limited_threshold
  alarm_actions                  = var.waf_alarm_actions
  common_tags                    = var.common_tags
}

# ========================================
# CLOUDFRONT MODULE
# ========================================
module "cloudfront" {
  source = "./modules/cloudfront"
  
  cluster_name                  = var.cluster_name
  environment                   = var.environment
  enable_cloudfront             = var.enable_cloudfront
  cloudfront_aliases            = var.cloudfront_aliases
  cloudfront_price_class        = var.cloudfront_price_class
  default_root_object           = var.cloudfront_default_root_object
  alb_domain_name               = var.cloudfront_alb_domain_name
  origin_custom_header_value    = var.cloudfront_origin_custom_header
  enable_s3_origin              = var.cloudfront_enable_s3_origin
  s3_bucket_domain_name         = var.cloudfront_s3_bucket_domain
  s3_origin_access_identity     = var.cloudfront_s3_oai
  cache_default_ttl             = var.cloudfront_cache_default_ttl
  cache_max_ttl                 = var.cloudfront_cache_max_ttl
  cache_min_ttl                 = var.cloudfront_cache_min_ttl
  cache_header_whitelist        = var.cloudfront_cache_headers
  acm_certificate_arn           = var.cloudfront_acm_certificate_arn
  geo_restriction_type          = var.cloudfront_geo_restriction_type
  geo_restriction_locations     = var.cloudfront_geo_restriction_locations
  enable_logging                = var.cloudfront_enable_logging
  logging_bucket                = var.cloudfront_logging_bucket
  waf_web_acl_id                = module.waf.waf_web_acl_id
  enable_url_rewrite_function   = var.cloudfront_enable_url_rewrite
  viewer_request_function_arn   = var.cloudfront_function_arn
  enable_cloudwatch_alarms      = var.cloudfront_enable_alarms
  error_rate_threshold          = var.cloudfront_error_rate_threshold
  cache_hit_rate_threshold      = var.cloudfront_cache_hit_threshold
  alarm_actions                 = var.cloudfront_alarm_actions
  common_tags                   = var.common_tags
  
  depends_on = [module.alb_controller, module.route53, module.waf]
}
