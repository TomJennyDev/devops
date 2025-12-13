# ==================================================
# ECR Module Outputs
# ==================================================

output "repository_urls" {
  description = "Map of repository names to URLs"
  value = {
    for k, v in aws_ecr_repository.this : k => v.repository_url
  }
}

output "repository_arns" {
  description = "Map of repository names to ARNs"
  value = {
    for k, v in aws_ecr_repository.this : k => v.arn
  }
}

output "repository_registry_ids" {
  description = "Map of repository names to registry IDs"
  value = {
    for k, v in aws_ecr_repository.this : k => v.registry_id
  }
}

output "repositories" {
  description = "Full repository objects"
  value       = aws_ecr_repository.this
  sensitive   = false
}

# ==================================================
# Convenience outputs for specific repositories
# ==================================================

output "flowise_server_url" {
  description = "ECR URL for flowise-server repository"
  value       = try(aws_ecr_repository.this["flowise-server"].repository_url, null)
}

output "flowise_ui_url" {
  description = "ECR URL for flowise-ui repository"
  value       = try(aws_ecr_repository.this["flowise-ui"].repository_url, null)
}

output "docker_login_command" {
  description = "Command to authenticate Docker with ECR"
  value       = length(aws_ecr_repository.this) > 0 ? "aws ecr get-login-password --region ${data.aws_region.current.name} | docker login --username AWS --password-stdin ${split("/", values(aws_ecr_repository.this)[0].repository_url)[0]}" : null
}

# ==================================================
# Data Sources
# ==================================================
data "aws_region" "current" {}


