# ============================================
# AWS WAF v2 MODULE
# ============================================
# Web Application Firewall for CloudFront and ALB protection

# ============================================
# WAF WEB ACL
# ============================================
resource "aws_wafv2_web_acl" "main" {
  count = var.enable_waf ? 1 : 0

  name        = "${var.cluster_name}-${var.environment}-waf"
  description = "WAF Web ACL for ${var.environment} environment"
  scope       = var.waf_scope # CLOUDFRONT or REGIONAL

  default_action {
    allow {}
  }

  # Rule 1: AWS Managed Rules - Core Rule Set
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"

        # Exclude rules that might cause false positives
        dynamic "rule_action_override" {
          for_each = var.core_rule_set_excluded_rules
          content {
            name = rule_action_override.value
            action_to_use {
              count {}
            }
          }
        }

        # Exclude CommonRuleSet for Flowise API paths
        scope_down_statement {
          not_statement {
            statement {
              byte_match_statement {
                search_string         = "/api/v1/"
                positional_constraint = "STARTS_WITH"

                field_to_match {
                  uri_path {}
                }

                text_transformation {
                  priority = 0
                  type     = "LOWERCASE"
                }
              }
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.cluster_name}-${var.environment}-core-rule-set"
      sampled_requests_enabled   = true
    }
  }

  # Rule 2: AWS Managed Rules - Known Bad Inputs
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"

        # Exclude KnownBadInputs for Flowise API paths
        scope_down_statement {
          not_statement {
            statement {
              byte_match_statement {
                search_string         = "/api/v1/"
                positional_constraint = "STARTS_WITH"

                field_to_match {
                  uri_path {}
                }

                text_transformation {
                  priority = 0
                  type     = "LOWERCASE"
                }
              }
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.cluster_name}-${var.environment}-known-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  # Rule 3: AWS Managed Rules - SQL Database
  dynamic "rule" {
    for_each = var.enable_sql_injection_rule ? [1] : []
    content {
      name     = "AWSManagedRulesSQLiRuleSet"
      priority = 3

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesSQLiRuleSet"
          vendor_name = "AWS"

          # Exclude SQLi rules for Flowise API paths
          scope_down_statement {
            not_statement {
              statement {
                byte_match_statement {
                  search_string         = "/api/v1/"
                  positional_constraint = "STARTS_WITH"

                  field_to_match {
                    uri_path {}
                  }

                  text_transformation {
                    priority = 0
                    type     = "LOWERCASE"
                  }
                }
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.cluster_name}-${var.environment}-sqli-rule-set"
        sampled_requests_enabled   = true
      }
    }
  }

  # Rule 4: AWS Managed Rules - Linux Operating System
  dynamic "rule" {
    for_each = var.enable_linux_rule ? [1] : []
    content {
      name     = "AWSManagedRulesLinuxRuleSet"
      priority = 4

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesLinuxRuleSet"
          vendor_name = "AWS"

          # Exclude LinuxRuleSet for Flowise API paths
          scope_down_statement {
            not_statement {
              statement {
                byte_match_statement {
                  search_string         = "/api/v1/"
                  positional_constraint = "STARTS_WITH"

                  field_to_match {
                    uri_path {}
                  }

                  text_transformation {
                    priority = 0
                    type     = "LOWERCASE"
                  }
                }
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.cluster_name}-${var.environment}-linux-rule-set"
        sampled_requests_enabled   = true
      }
    }
  }

  # Rule 5: Rate Limiting
  dynamic "rule" {
    for_each = var.enable_rate_limiting ? [1] : []
    content {
      name     = "RateLimitRule"
      priority = 5

      action {
        block {}
      }

      statement {
        rate_based_statement {
          limit              = var.rate_limit_requests
          aggregate_key_type = "IP"

          # Exclude Flowise API from rate limiting
          scope_down_statement {
            not_statement {
              statement {
                byte_match_statement {
                  search_string         = "/api/v1/"
                  positional_constraint = "STARTS_WITH"

                  field_to_match {
                    uri_path {}
                  }

                  text_transformation {
                    priority = 0
                    type     = "LOWERCASE"
                  }
                }
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.cluster_name}-${var.environment}-rate-limit"
        sampled_requests_enabled   = true
      }
    }
  }

  # Rule 6: Geo Blocking
  dynamic "rule" {
    for_each = var.enable_geo_blocking && length(var.blocked_countries) > 0 ? [1] : []
    content {
      name     = "GeoBlockingRule"
      priority = 6

      action {
        block {}
      }

      statement {
        geo_match_statement {
          country_codes = var.blocked_countries
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.cluster_name}-${var.environment}-geo-blocking"
        sampled_requests_enabled   = true
      }
    }
  }

  # Rule 7: IP Blacklist
  dynamic "rule" {
    for_each = var.enable_ip_blacklist && length(var.blacklist_ip_addresses) > 0 ? [1] : []
    content {
      name     = "IPBlacklistRule"
      priority = 7

      action {
        block {}
      }

      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.blacklist[0].arn
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.cluster_name}-${var.environment}-ip-blacklist"
        sampled_requests_enabled   = true
      }
    }
  }

  # Rule 8: IP Whitelist (Allow only specific IPs)
  dynamic "rule" {
    for_each = var.enable_ip_whitelist && length(var.whitelist_ip_addresses) > 0 ? [1] : []
    content {
      name     = "IPWhitelistRule"
      priority = 8

      action {
        allow {}
      }

      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.whitelist[0].arn
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.cluster_name}-${var.environment}-ip-whitelist"
        sampled_requests_enabled   = true
      }
    }
  }

  # Rule 9: Custom Regex Pattern Matching
  dynamic "rule" {
    for_each = var.enable_regex_pattern_matching && length(var.regex_patterns) > 0 ? [1] : []
    content {
      name     = "RegexPatternRule"
      priority = 9

      action {
        block {}
      }

      statement {
        regex_pattern_set_reference_statement {
          arn = aws_wafv2_regex_pattern_set.custom[0].arn

          field_to_match {
            uri_path {}
          }

          text_transformation {
            priority = 0
            type     = "LOWERCASE"
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.cluster_name}-${var.environment}-regex-pattern"
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.cluster_name}-${var.environment}-waf"
    sampled_requests_enabled   = true
  }

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.cluster_name}-${var.environment}-waf"
      Environment = var.environment
    }
  )
}

# ============================================
# IP SET - BLACKLIST
# ============================================
resource "aws_wafv2_ip_set" "blacklist" {
  count = var.enable_waf && var.enable_ip_blacklist && length(var.blacklist_ip_addresses) > 0 ? 1 : 0

  name               = "${var.cluster_name}-${var.environment}-blacklist"
  description        = "IP Blacklist for ${var.environment}"
  scope              = var.waf_scope
  ip_address_version = "IPV4"
  addresses          = var.blacklist_ip_addresses

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.cluster_name}-${var.environment}-blacklist"
      Environment = var.environment
    }
  )
}

# ============================================
# IP SET - WHITELIST
# ============================================
resource "aws_wafv2_ip_set" "whitelist" {
  count = var.enable_waf && var.enable_ip_whitelist && length(var.whitelist_ip_addresses) > 0 ? 1 : 0

  name               = "${var.cluster_name}-${var.environment}-whitelist"
  description        = "IP Whitelist for ${var.environment}"
  scope              = var.waf_scope
  ip_address_version = "IPV4"
  addresses          = var.whitelist_ip_addresses

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.cluster_name}-${var.environment}-whitelist"
      Environment = var.environment
    }
  )
}

# ============================================
# REGEX PATTERN SET
# ============================================
resource "aws_wafv2_regex_pattern_set" "custom" {
  count = var.enable_waf && var.enable_regex_pattern_matching && length(var.regex_patterns) > 0 ? 1 : 0

  name        = "${var.cluster_name}-${var.environment}-regex-patterns"
  description = "Custom regex patterns for ${var.environment}"
  scope       = var.waf_scope

  dynamic "regular_expression" {
    for_each = var.regex_patterns
    content {
      regex_string = regular_expression.value
    }
  }

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.cluster_name}-${var.environment}-regex-patterns"
      Environment = var.environment
    }
  )
}

# ============================================
# CLOUDWATCH LOG GROUP FOR WAF
# ============================================
resource "aws_cloudwatch_log_group" "waf_logs" {
  count = var.enable_waf && var.enable_waf_logging ? 1 : 0

  name              = "/aws/waf/${var.cluster_name}-${var.environment}"
  retention_in_days = var.waf_log_retention_days

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.cluster_name}-${var.environment}-waf-logs"
      Environment = var.environment
    }
  )
}

# ============================================
# WAF LOGGING CONFIGURATION
# ============================================
resource "aws_wafv2_web_acl_logging_configuration" "main" {
  count = var.enable_waf && var.enable_waf_logging ? 1 : 0

  resource_arn            = aws_wafv2_web_acl.main[0].arn
  log_destination_configs = [aws_cloudwatch_log_group.waf_logs[0].arn]

  # Redact sensitive fields
  dynamic "redacted_fields" {
    for_each = var.waf_redacted_fields
    content {
      dynamic "single_header" {
        for_each = redacted_fields.value.type == "single_header" ? [1] : []
        content {
          name = redacted_fields.value.name
        }
      }

      dynamic "uri_path" {
        for_each = redacted_fields.value.type == "uri_path" ? [1] : []
        content {}
      }

      dynamic "query_string" {
        for_each = redacted_fields.value.type == "query_string" ? [1] : []
        content {}
      }
    }
  }

  logging_filter {
    default_behavior = "KEEP"

    filter {
      behavior    = "KEEP"
      requirement = "MEETS_ANY"

      condition {
        action_condition {
          action = "BLOCK"
        }
      }

      condition {
        action_condition {
          action = "COUNT"
        }
      }
    }
  }
}

# ============================================
# CLOUDWATCH ALARMS
# ============================================

# Alarm: Blocked Requests
resource "aws_cloudwatch_metric_alarm" "blocked_requests" {
  count = var.enable_waf && var.enable_waf_alarms ? 1 : 0

  alarm_name          = "${var.cluster_name}-${var.environment}-waf-blocked-requests"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = 300
  statistic           = "Sum"
  threshold           = var.blocked_requests_threshold
  alarm_description   = "WAF blocked requests exceeded threshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    WebACL = aws_wafv2_web_acl.main[0].name
    Region = var.waf_scope == "CLOUDFRONT" ? "Global" : var.aws_region
    Rule   = "ALL"
  }

  alarm_actions = var.alarm_actions

  tags = var.common_tags
}

# Alarm: Rate Limited Requests
resource "aws_cloudwatch_metric_alarm" "rate_limited" {
  count = var.enable_waf && var.enable_waf_alarms && var.enable_rate_limiting ? 1 : 0

  alarm_name          = "${var.cluster_name}-${var.environment}-waf-rate-limited"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = 300
  statistic           = "Sum"
  threshold           = var.rate_limited_threshold
  alarm_description   = "Rate limiting triggered frequently"
  treat_missing_data  = "notBreaching"

  dimensions = {
    WebACL = aws_wafv2_web_acl.main[0].name
    Region = var.waf_scope == "CLOUDFRONT" ? "Global" : var.aws_region
    Rule   = "RateLimitRule"
  }

  alarm_actions = var.alarm_actions

  tags = var.common_tags
}
