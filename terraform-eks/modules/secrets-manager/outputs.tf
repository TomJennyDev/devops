# ========================================
# SECRETS MANAGER MODULE - OUTPUTS
# ========================================

output "secret_arns" {
  description = "ARNs of created secrets"
  value = {
    for k, v in aws_secretsmanager_secret.secrets :
    k => v.arn
  }
}

output "secret_ids" {
  description = "IDs of created secrets"
  value = {
    for k, v in aws_secretsmanager_secret.secrets :
    k => v.id
  }
}

output "secret_names" {
  description = "Names of created secrets"
  value = {
    for k, v in aws_secretsmanager_secret.secrets :
    k => v.name
  }
}

output "access_policy_arn" {
  description = "ARN of IAM policy for secret access"
  value       = var.create_access_policy ? aws_iam_policy.secrets_access[0].arn : null
}
