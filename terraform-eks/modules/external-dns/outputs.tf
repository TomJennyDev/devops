output "external_dns_role_arn" {
  description = "ARN of the IAM role for External DNS"
  value       = var.enable_external_dns ? aws_iam_role.external_dns[0].arn : ""
}

output "external_dns_role_name" {
  description = "Name of the IAM role for External DNS"
  value       = var.enable_external_dns ? aws_iam_role.external_dns[0].name : ""
}

output "external_dns_policy_arn" {
  description = "ARN of the IAM policy for External DNS"
  value       = var.enable_external_dns ? aws_iam_policy.external_dns[0].arn : ""
}
