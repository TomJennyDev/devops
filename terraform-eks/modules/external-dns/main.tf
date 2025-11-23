# ========================================
# EXTERNAL DNS IAM ROLE (IRSA)
# ========================================
# Creates IAM role for External DNS to manage Route53 records

# IAM Policy for External DNS
data "aws_iam_policy_document" "external_dns" {
  count = var.enable_external_dns ? 1 : 0

  statement {
    sid    = "ChangeResourceRecordSets"
    effect = "Allow"
    actions = [
      "route53:ChangeResourceRecordSets"
    ]
    resources = length(var.route53_zone_arns) > 0 ? var.route53_zone_arns : ["arn:aws:route53:::hostedzone/*"]
  }

  statement {
    sid    = "ListResourceRecordSets"
    effect = "Allow"
    actions = [
      "route53:ListHostedZones",
      "route53:ListResourceRecordSets",
      "route53:ListTagsForResource"
    ]
    resources = ["*"]
  }
}

# IAM Policy
resource "aws_iam_policy" "external_dns" {
  count = var.enable_external_dns ? 1 : 0

  name_prefix = "${var.cluster_name}-external-dns-"
  description = "IAM policy for External DNS to manage Route53 records"
  policy      = data.aws_iam_policy_document.external_dns[0].json

  tags = merge(
    var.common_tags,
    {
      Name = "${var.cluster_name}-external-dns-policy"
    }
  )
}

# Trust Policy for IRSA
data "aws_iam_policy_document" "external_dns_assume_role" {
  count = var.enable_external_dns ? 1 : 0

  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:external-dns:external-dns"]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# IAM Role
resource "aws_iam_role" "external_dns" {
  count = var.enable_external_dns ? 1 : 0

  name_prefix        = "${var.cluster_name}-external-dns-"
  assume_role_policy = data.aws_iam_policy_document.external_dns_assume_role[0].json

  tags = merge(
    var.common_tags,
    {
      Name = "${var.cluster_name}-external-dns-role"
    }
  )
}

# Attach Policy to Role
resource "aws_iam_role_policy_attachment" "external_dns" {
  count = var.enable_external_dns ? 1 : 0

  role       = aws_iam_role.external_dns[0].name
  policy_arn = aws_iam_policy.external_dns[0].arn
}
