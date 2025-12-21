# ============================================
# WAF MODULE OUTPUTS
# ============================================

output "waf_web_acl_id" {
  description = "WAF Web ACL ID"
  value       = var.enable_waf ? aws_wafv2_web_acl.main[0].id : ""
}

output "waf_web_acl_arn" {
  description = "WAF Web ACL ARN"
  value       = var.enable_waf ? aws_wafv2_web_acl.main[0].arn : ""
}

output "waf_web_acl_name" {
  description = "WAF Web ACL name"
  value       = var.enable_waf ? aws_wafv2_web_acl.main[0].name : ""
}

output "waf_web_acl_capacity" {
  description = "WAF Web ACL capacity units used"
  value       = var.enable_waf ? aws_wafv2_web_acl.main[0].capacity : 0
}

output "ip_blacklist_arn" {
  description = "IP blacklist set ARN"
  value       = var.enable_waf && var.enable_ip_blacklist && length(var.blacklist_ip_addresses) > 0 ? aws_wafv2_ip_set.blacklist[0].arn : ""
}

output "ip_whitelist_arn" {
  description = "IP whitelist set ARN"
  value       = var.enable_waf && var.enable_ip_whitelist && length(var.whitelist_ip_addresses) > 0 ? aws_wafv2_ip_set.whitelist[0].arn : ""
}

output "regex_pattern_set_arn" {
  description = "Regex pattern set ARN"
  value       = var.enable_waf && var.enable_regex_pattern_matching && length(var.regex_patterns) > 0 ? aws_wafv2_regex_pattern_set.custom[0].arn : ""
}

output "waf_log_group_name" {
  description = "CloudWatch log group name for WAF logs"
  value       = var.enable_waf && var.enable_waf_logging ? aws_cloudwatch_log_group.waf_logs[0].name : ""
}

output "waf_log_group_arn" {
  description = "CloudWatch log group ARN for WAF logs"
  value       = var.enable_waf && var.enable_waf_logging ? aws_cloudwatch_log_group.waf_logs[0].arn : ""
}
