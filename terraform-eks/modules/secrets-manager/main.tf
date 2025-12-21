# ========================================
# AWS SECRETS MANAGER
# ========================================
# Store sensitive values securely
# Rotation: Manual for now, can be automated

resource "aws_secretsmanager_secret" "secrets" {
  for_each = var.secrets

  name                    = "${var.cluster_name}-${var.environment}-${each.key}"
  description             = each.value.description
  recovery_window_in_days = var.recovery_window_days

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.cluster_name}-${var.environment}-${each.key}"
      Environment = var.environment
      ManagedBy   = "Terraform"
      SecretType  = each.value.type
    }
  )
}

resource "aws_secretsmanager_secret_version" "secret_values" {
  for_each = var.secrets

  secret_id     = aws_secretsmanager_secret.secrets[each.key].id
  secret_string = jsonencode(each.value.value)
}

# ========================================
# IAM POLICY FOR SECRET ACCESS
# ========================================
# Allow specific services to read secrets

resource "aws_iam_policy" "secrets_access" {
  count = var.create_access_policy ? 1 : 0

  name        = "${var.cluster_name}-${var.environment}-secrets-access"
  description = "Allow reading secrets from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          for secret in aws_secretsmanager_secret.secrets :
          secret.arn
        ]
      }
    ]
  })

  tags = var.common_tags
}
