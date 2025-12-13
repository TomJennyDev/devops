# ==================================================
# ECR Repository Module
# ==================================================
# Creates ECR repositories with security best practices:
# - Encryption at rest
# - Image scanning on push
# - Lifecycle policies
# - Tag immutability (optional)
# ==================================================

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# ==================================================
# ECR Repository
# ==================================================
resource "aws_ecr_repository" "this" {
  for_each = var.repositories

  name                 = each.key
  image_tag_mutability = each.value.image_tag_mutability

  # Encryption configuration
  encryption_configuration {
    encryption_type = var.encryption_type
    kms_key        = var.kms_key_arn
  }

  # Image scanning configuration
  image_scanning_configuration {
    scan_on_push = each.value.scan_on_push
  }

  # Force delete even if contains images
  force_delete = var.force_delete

  tags = merge(
    var.common_tags,
    {
      Name = each.key
    },
    each.value.tags
  )
}

# ==================================================
# ECR Lifecycle Policy
# ==================================================
resource "aws_ecr_lifecycle_policy" "this" {
  for_each = var.repositories

  repository = aws_ecr_repository.this[each.key].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images older than ${each.value.untagged_days} days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = each.value.untagged_days
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep last ${each.value.max_image_count} images"
        selection = {
          tagStatus     = "any"
          countType     = "imageCountMoreThan"
          countNumber   = each.value.max_image_count
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ==================================================
# ECR Repository Policy (Optional)
# ==================================================
resource "aws_ecr_repository_policy" "this" {
  for_each = {
    for k, v in var.repositories : k => v
    if v.repository_policy != null
  }

  repository = aws_ecr_repository.this[each.key].name
  policy     = each.value.repository_policy
}

# ==================================================
# ECR Pull Through Cache Rule (Optional)
# ==================================================
# Allows caching images from public registries (e.g., Docker Hub)
resource "aws_ecr_pull_through_cache_rule" "this" {
  for_each = var.pull_through_cache_rules

  ecr_repository_prefix = each.key
  upstream_registry_url = each.value.upstream_registry_url
  credential_arn        = each.value.credential_arn
}
