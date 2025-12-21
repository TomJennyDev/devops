# ============================================
# CLOUDFRONT MODULE
# ============================================
# This module creates CloudFront distribution for:
# - Global CDN for applications (Flowise, etc.)
# - Cache static content at edge locations
# - SSL/TLS termination with ACM certificate
# - Origin: ALB from EKS cluster
# - Optional WAF integration for security
# ============================================

# ============================================
# CLOUDFRONT ORIGIN ACCESS CONTROL (OAC)
# ============================================
# For ALB origin, we use custom headers for security
# OAC is primarily for S3, but we set up custom headers for ALB

resource "aws_cloudfront_origin_access_control" "alb_oac" {
  count = var.enable_cloudfront ? 1 : 0

  name                              = "${var.cluster_name}-${var.environment}-alb-oac"
  description                       = "Origin Access Control for ALB"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ============================================
# CLOUDFRONT CACHE POLICY
# ============================================
# Custom cache policy for application content

resource "aws_cloudfront_cache_policy" "app_cache_policy" {
  count = var.enable_cloudfront ? 1 : 0

  name        = "${var.cluster_name}-${var.environment}-app-cache"
  comment     = "Cache policy for application content"
  default_ttl = var.cache_default_ttl
  max_ttl     = var.cache_max_ttl
  min_ttl     = var.cache_min_ttl

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "all"
    }

    headers_config {
      header_behavior = "whitelist"
      headers {
        items = var.cache_header_whitelist
      }
    }

    query_strings_config {
      query_string_behavior = "all"
    }

    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true
  }
}

# Cache policy for static content (aggressive caching)
resource "aws_cloudfront_cache_policy" "static_cache_policy" {
  count = var.enable_cloudfront ? 1 : 0

  name        = "${var.cluster_name}-${var.environment}-static-cache"
  comment     = "Aggressive cache policy for static content"
  default_ttl = 86400  # 1 day
  max_ttl     = 31536000  # 1 year
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }

    headers_config {
      header_behavior = "none"
    }

    query_strings_config {
      query_string_behavior = "none"
    }

    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true
  }
}

# ============================================
# CLOUDFRONT ORIGIN REQUEST POLICY
# ============================================
# Policy for forwarding requests to ALB origin

resource "aws_cloudfront_origin_request_policy" "alb_origin_policy" {
  count = var.enable_cloudfront ? 1 : 0

  name    = "${var.cluster_name}-${var.environment}-alb-origin"
  comment = "Origin request policy for ALB"

  cookies_config {
    cookie_behavior = "all"
  }

  headers_config {
    header_behavior = "allViewer"
  }

  query_strings_config {
    query_string_behavior = "all"
  }
}

# ============================================
# CLOUDFRONT RESPONSE HEADERS POLICY
# ============================================
# Security headers for responses

resource "aws_cloudfront_response_headers_policy" "security_headers" {
  count = var.enable_cloudfront ? 1 : 0

  name    = "${var.cluster_name}-${var.environment}-security-headers"
  comment = "Security headers policy"

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }

    content_type_options {
      override = true
    }

    frame_options {
      frame_option = "SAMEORIGIN"
      override     = true
    }

    xss_protection {
      mode_block = true
      protection = true
      override   = true
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }
  }

  custom_headers_config {
    items {
      header   = "X-Environment"
      value    = var.environment
      override = true
    }
  }
}

# ============================================
# CLOUDFRONT DISTRIBUTION
# ============================================
# Main CloudFront distribution

resource "aws_cloudfront_distribution" "main" {
  count = var.enable_cloudfront ? 1 : 0

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CloudFront distribution for ${var.cluster_name} ${var.environment}"
  price_class         = var.cloudfront_price_class
  aliases             = var.cloudfront_aliases
  default_root_object = var.default_root_object

  # ============================================
  # ORIGIN: ALB
  # ============================================
  origin {
    domain_name = var.alb_domain_name
    origin_id   = "alb-${var.environment}"

    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_protocol_policy   = "https-only"
      origin_ssl_protocols     = ["TLSv1.2"]
      origin_keepalive_timeout = 60
      origin_read_timeout      = 60
    }

    # Custom headers for origin identification
    custom_header {
      name  = "X-Origin-Verify"
      value = var.origin_custom_header_value
    }
  }

  # ============================================
  # ORIGIN: S3 (Optional - for static assets)
  # ============================================
  dynamic "origin" {
    for_each = var.enable_s3_origin ? [1] : []

    content {
      domain_name = var.s3_bucket_domain_name
      origin_id   = "s3-${var.environment}"

      s3_origin_config {
        origin_access_identity = var.s3_origin_access_identity
      }
    }
  }

  # ============================================
  # DEFAULT CACHE BEHAVIOR (ALB Origin)
  # ============================================
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "alb-${var.environment}"

    # Use custom cache policy
    cache_policy_id          = aws_cloudfront_cache_policy.app_cache_policy[0].id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.alb_origin_policy[0].id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security_headers[0].id

    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    # Function associations (optional)
    dynamic "function_association" {
      for_each = var.viewer_request_function_arn != "" ? [1] : []

      content {
        event_type   = "viewer-request"
        function_arn = var.viewer_request_function_arn
      }
    }
  }

  # ============================================
  # ORDERED CACHE BEHAVIORS
  # ============================================

  # Static assets: images, css, js (aggressive caching)
  ordered_cache_behavior {
    path_pattern     = "/static/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "alb-${var.environment}"

    cache_policy_id          = aws_cloudfront_cache_policy.static_cache_policy[0].id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.alb_origin_policy[0].id

    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  ordered_cache_behavior {
    path_pattern     = "*.css"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "alb-${var.environment}"

    cache_policy_id          = aws_cloudfront_cache_policy.static_cache_policy[0].id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.alb_origin_policy[0].id

    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  ordered_cache_behavior {
    path_pattern     = "*.js"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "alb-${var.environment}"

    cache_policy_id          = aws_cloudfront_cache_policy.static_cache_policy[0].id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.alb_origin_policy[0].id

    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  # API endpoints (no caching)
  ordered_cache_behavior {
    path_pattern     = "/api/*"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "alb-${var.environment}"

    cache_policy_id          = aws_cloudfront_cache_policy.app_cache_policy[0].id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.alb_origin_policy[0].id

    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
  }

  # ============================================
  # SSL/TLS CERTIFICATE
  # ============================================
  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  # ============================================
  # RESTRICTIONS
  # ============================================
  restrictions {
    geo_restriction {
      restriction_type = var.geo_restriction_type
      locations        = var.geo_restriction_locations
    }
  }

  # ============================================
  # LOGGING
  # ============================================
  dynamic "logging_config" {
    for_each = var.enable_logging ? [1] : []

    content {
      include_cookies = false
      bucket          = var.logging_bucket
      prefix          = "cloudfront/${var.environment}/"
    }
  }

  # ============================================
  # CUSTOM ERROR RESPONSES
  # ============================================
  custom_error_response {
    error_code            = 403
    response_code         = 404
    response_page_path    = "/404.html"
    error_caching_min_ttl = 300
  }

  custom_error_response {
    error_code            = 404
    response_code         = 404
    response_page_path    = "/404.html"
    error_caching_min_ttl = 300
  }

  custom_error_response {
    error_code            = 500
    response_code         = 500
    response_page_path    = "/500.html"
    error_caching_min_ttl = 60
  }

  # ============================================
  # WAF ASSOCIATION (Optional)
  # ============================================
  web_acl_id = var.waf_web_acl_id

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.cluster_name}-${var.environment}-cloudfront"
      Environment = var.environment
      Component   = "cdn"
    }
  )
}

# ============================================
# CLOUDFRONT FUNCTION (Optional)
# ============================================
# Example: URL rewrite, request manipulation

resource "aws_cloudfront_function" "url_rewrite" {
  count = var.enable_cloudfront && var.enable_url_rewrite_function ? 1 : 0

  name    = "${var.cluster_name}-${var.environment}-url-rewrite"
  runtime = "cloudfront-js-1.0"
  comment = "URL rewrite function"
  publish = true

  code = <<-EOT
    function handler(event) {
      var request = event.request;
      var uri = request.uri;

      // Redirect /old-path to /new-path
      if (uri === '/old-path') {
        var response = {
          statusCode: 301,
          statusDescription: 'Moved Permanently',
          headers: {
            'location': { value: '/new-path' }
          }
        };
        return response;
      }

      // Add trailing slash to directories
      if (uri.endsWith('/')) {
        request.uri += 'index.html';
      } else if (!uri.includes('.')) {
        request.uri += '/index.html';
      }

      return request;
    }
  EOT
}

# ============================================
# CLOUDFRONT MONITORING ALARM (Optional)
# ============================================
resource "aws_cloudwatch_metric_alarm" "cloudfront_5xx_errors" {
  count = var.enable_cloudfront && var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.cluster_name}-${var.environment}-cloudfront-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "5xxErrorRate"
  namespace           = "AWS/CloudFront"
  period              = "300"
  statistic           = "Average"
  threshold           = var.error_rate_threshold
  alarm_description   = "CloudFront 5xx error rate is too high"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DistributionId = aws_cloudfront_distribution.main[0].id
  }

  alarm_actions = var.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "cloudfront_cache_hit_rate" {
  count = var.enable_cloudfront && var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.cluster_name}-${var.environment}-cloudfront-cache-hit-rate"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CacheHitRate"
  namespace           = "AWS/CloudFront"
  period              = "300"
  statistic           = "Average"
  threshold           = var.cache_hit_rate_threshold
  alarm_description   = "CloudFront cache hit rate is too low"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DistributionId = aws_cloudfront_distribution.main[0].id
  }

  alarm_actions = var.alarm_actions
}
