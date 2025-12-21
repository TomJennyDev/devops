# ============================================
# CLOUDFRONT DISTRIBUTION OUTPUTS
# ============================================

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = var.enable_cloudfront ? aws_cloudfront_distribution.main[0].id : ""
}

output "cloudfront_distribution_arn" {
  description = "CloudFront distribution ARN"
  value       = var.enable_cloudfront ? aws_cloudfront_distribution.main[0].arn : ""
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = var.enable_cloudfront ? aws_cloudfront_distribution.main[0].domain_name : ""
}

output "cloudfront_hosted_zone_id" {
  description = "CloudFront distribution hosted zone ID (for Route53 ALIAS records)"
  value       = var.enable_cloudfront ? aws_cloudfront_distribution.main[0].hosted_zone_id : ""
}

output "cloudfront_status" {
  description = "CloudFront distribution status"
  value       = var.enable_cloudfront ? aws_cloudfront_distribution.main[0].status : ""
}

output "cloudfront_etag" {
  description = "CloudFront distribution ETag (version identifier)"
  value       = var.enable_cloudfront ? aws_cloudfront_distribution.main[0].etag : ""
}

# ============================================
# CLOUDFRONT POLICIES OUTPUTS
# ============================================

output "cache_policy_id_app" {
  description = "CloudFront cache policy ID for application content"
  value       = var.enable_cloudfront ? aws_cloudfront_cache_policy.app_cache_policy[0].id : ""
}

output "cache_policy_id_static" {
  description = "CloudFront cache policy ID for static content"
  value       = var.enable_cloudfront ? aws_cloudfront_cache_policy.static_cache_policy[0].id : ""
}

output "origin_request_policy_id" {
  description = "CloudFront origin request policy ID for ALB"
  value       = var.enable_cloudfront ? aws_cloudfront_origin_request_policy.alb_origin_policy[0].id : ""
}

output "response_headers_policy_id" {
  description = "CloudFront response headers policy ID for security headers"
  value       = var.enable_cloudfront ? aws_cloudfront_response_headers_policy.security_headers[0].id : ""
}

# ============================================
# CLOUDFRONT ORIGIN ACCESS CONTROL OUTPUTS
# ============================================

output "origin_access_control_id" {
  description = "CloudFront Origin Access Control ID"
  value       = var.enable_cloudfront ? aws_cloudfront_origin_access_control.alb_oac[0].id : ""
}

# ============================================
# CLOUDFRONT FUNCTION OUTPUTS
# ============================================

output "url_rewrite_function_arn" {
  description = "CloudFront function ARN for URL rewriting"
  value       = var.enable_url_rewrite_function && var.enable_cloudfront ? aws_cloudfront_function.url_rewrite[0].arn : ""
}

# ============================================
# MONITORING OUTPUTS
# ============================================

output "cloudwatch_alarm_5xx_arn" {
  description = "CloudWatch alarm ARN for 5xx errors"
  value       = var.enable_cloudwatch_alarms && var.enable_cloudfront ? aws_cloudwatch_metric_alarm.cloudfront_5xx_errors[0].arn : ""
}

output "cloudwatch_alarm_cache_hit_rate_arn" {
  description = "CloudWatch alarm ARN for cache hit rate"
  value       = var.enable_cloudwatch_alarms && var.enable_cloudfront ? aws_cloudwatch_metric_alarm.cloudfront_cache_hit_rate[0].arn : ""
}
