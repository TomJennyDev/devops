output "aws_load_balancer_controller_role_arn" {
  description = "ARN of IAM role for AWS Load Balancer Controller"
  value       = var.enable_aws_load_balancer_controller ? aws_iam_role.aws_load_balancer_controller[0].arn : null
}

output "aws_load_balancer_controller_policy_arn" {
  description = "ARN of IAM policy for AWS Load Balancer Controller"
  value       = var.enable_aws_load_balancer_controller ? aws_iam_policy.aws_load_balancer_controller[0].arn : null
}
