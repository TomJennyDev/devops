# AWS WAF Module - Deployment Guide

## Overview

AWS WAF (Web Application Firewall) module bảo vệ ứng dụng khỏi các cuộc tấn công web phổ biến và bot traffic. Module hỗ trợ cả CloudFront (global) và ALB (regional).

## Tính năng chính

### 1. AWS Managed Rules
- ✅ **Core Rule Set**: Bảo vệ OWASP Top 10
- ✅ **Known Bad Inputs**: Chặn các pattern độc hại đã biết
- ✅ **SQL Injection**: Chống SQL injection attacks
- ✅ **Linux OS**: Bảo vệ khỏi Linux-specific attacks

### 2. Rate Limiting
- Giới hạn requests từ 1 IP trong 5 phút
- Ngăn chặn DDoS và brute force attacks
- Cấu hình linh hoạt (default: 2000 req/5min)

### 3. Geo Blocking
- Chặn traffic từ các quốc gia cụ thể
- Sử dụng ISO 3166-1 alpha-2 codes
- Example: `["CN", "RU", "KP"]`

### 4. IP Filtering
- **Blacklist**: Chặn IPs cụ thể
- **Whitelist**: Chỉ cho phép IPs cụ thể
- Hỗ trợ CIDR notation

### 5. Custom Regex Patterns
- Tạo rules dựa trên regex
- Áp dụng cho URI paths
- Chặn các patterns nguy hiểm

### 6. Logging & Monitoring
- CloudWatch Logs integration
- Redact sensitive fields (auth, cookies)
- CloudWatch alarms cho blocked requests

## Kiến trúc

### CloudFront WAF (Global)
```
Users → CloudFront → WAF (us-east-1) → Origin (ALB)
```

### ALB WAF (Regional)
```
Users → ALB → WAF (ap-southeast-1) → EKS Pods
```

## Configuration

### 1. Enable WAF for CloudFront

```hcl
# terraform.tfvars
enable_waf = true
waf_scope  = "CLOUDFRONT"  # Must be CLOUDFRONT for CloudFront distribution

# AWS Managed Rules
waf_enable_sqli_rule  = true
waf_enable_linux_rule = true

# Rate Limiting
waf_enable_rate_limit = true
waf_rate_limit_value  = 2000  # 2000 requests per 5 minutes

# Logging
waf_enable_logging     = true
waf_log_retention_days = 30
```

### 2. Enable WAF for ALB

```hcl
# terraform.tfvars
enable_waf = true
waf_scope  = "REGIONAL"  # Must be REGIONAL for ALB

# Rest of config same as above
```

### 3. Geo Blocking

```hcl
# Block specific countries
waf_enable_geo_blocking = true
waf_blocked_countries   = ["CN", "RU", "KP", "IR"]
```

### 4. IP Blacklist

```hcl
# Block malicious IPs
waf_enable_ip_blacklist = true
waf_blacklist_ips = [
  "1.2.3.4/32",
  "5.6.7.0/24"
]
```

### 5. IP Whitelist (Allow only specific IPs)

```hcl
# Only allow office/VPN IPs
waf_enable_ip_whitelist = true
waf_whitelist_ips = [
  "203.0.113.0/24",  # Office network
  "198.51.100.5/32"   # VPN gateway
]
```

### 6. Custom Regex Patterns

```hcl
# Block suspicious paths
waf_enable_regex = true
waf_regex_patterns = [
  ".*\\.php$",           # Block .php files
  ".*/admin/.*",         # Block admin paths
  ".*/wp-admin/.*",      # Block WordPress admin
  ".*\\.\\..*",          # Block path traversal
  ".*<script>.*"         # Block XSS attempts
]
```

## Deployment

### Step 1: Initialize Terraform

```bash
cd terraform-eks/environments/dev
terraform init
```

### Step 2: Validate Configuration

```bash
terraform validate
```

### Step 3: Plan

```bash
terraform plan
```

Expected output:
```
# module.waf.aws_wafv2_web_acl.main[0] will be created
  + resource "aws_wafv2_web_acl" "main" {
      + name  = "my-eks-dev-waf"
      + scope = "CLOUDFRONT"
      ...
    }

# module.waf.aws_cloudwatch_log_group.waf_logs[0] will be created
  + resource "aws_cloudwatch_log_group" "waf_logs" {
      + name              = "/aws/waf/my-eks-dev"
      + retention_in_days = 30
    }
```

### Step 4: Apply

```bash
terraform apply
```

## Testing WAF Rules

### 1. Test Rate Limiting

```bash
# Send 2000+ requests in 5 minutes
for i in {1..2100}; do
  curl https://cdn-dev.do2506.click/ &
done

# Check WAF logs
aws logs tail /aws/waf/my-eks-dev --follow --region us-east-1
```

### 2. Test SQL Injection Protection

```bash
# Try SQL injection
curl "https://cdn-dev.do2506.click/?id=1' OR '1'='1"

# Should be blocked with 403 Forbidden
```

### 3. Test XSS Protection

```bash
# Try XSS attack
curl "https://cdn-dev.do2506.click/?search=<script>alert('XSS')</script>"

# Should be blocked
```

### 4. Test Geo Blocking

```bash
# Use VPN to blocked country
curl https://cdn-dev.do2506.click/

# Should return 403 if country is blocked
```

### 5. Test IP Blacklist

```bash
# Add your IP to blacklist temporarily
waf_blacklist_ips = ["YOUR_IP/32"]
terraform apply

# Try to access
curl https://cdn-dev.do2506.click/

# Should be blocked
```

## Monitoring

### CloudWatch Metrics

```bash
# View blocked requests
aws cloudwatch get-metric-statistics \
  --namespace AWS/WAFV2 \
  --metric-name BlockedRequests \
  --dimensions Name=WebACL,Value=my-eks-dev-waf Name=Region,Value=Global \
  --start-time 2025-12-18T00:00:00Z \
  --end-time 2025-12-18T23:59:59Z \
  --period 300 \
  --statistics Sum

# View allowed requests
aws cloudwatch get-metric-statistics \
  --namespace AWS/WAFV2 \
  --metric-name AllowedRequests \
  --dimensions Name=WebACL,Value=my-eks-dev-waf Name=Region,Value=Global \
  --start-time 2025-12-18T00:00:00Z \
  --end-time 2025-12-18T23:59:59Z \
  --period 300 \
  --statistics Sum
```

### WAF Logs

```bash
# Tail WAF logs
aws logs tail /aws/waf/my-eks-dev --follow --region us-east-1

# Search for blocked requests
aws logs filter-log-events \
  --log-group-name /aws/waf/my-eks-dev \
  --filter-pattern "{ $.action = \"BLOCK\" }" \
  --region us-east-1
```

### CloudWatch Alarms

Module tự động tạo alarms:

1. **Blocked Requests Alarm**
   - Threshold: >100 blocked requests trong 5 phút
   - Action: Send SNS notification

2. **Rate Limited Alarm**
   - Threshold: >50 rate limited requests trong 5 phút
   - Action: Send SNS notification

## Cost

### WAF Pricing (us-east-1)

- **Web ACL**: $5/month
- **Rules**: $1/month per rule
- **Requests**: $0.60 per million requests

### Example Cost Calculation (Dev)

```
Assumptions:
- 1 Web ACL: $5
- 9 rules (Core, Bad Inputs, SQLi, Linux, Rate Limit, Geo, IP Black/White, Regex): $9
- 1M requests/month: $0.60
- Logging: ~$0.50/GB

Total: ~$15-20/month for dev
```

## Production Best Practices

### 1. Start with COUNT Mode

Trước khi BLOCK, test với COUNT mode:

```hcl
# In main.tf, temporarily change action
action {
  count {}  # Instead of block
}
```

Monitor logs để tránh false positives.

### 2. Tune Rate Limiting

Adjust based on traffic patterns:

```hcl
# Dev: Lenient
waf_rate_limit_value = 2000

# Staging: Moderate
waf_rate_limit_value = 1000

# Production: Strict
waf_rate_limit_value = 500
```

### 3. Exclude Rules Causing False Positives

```hcl
waf_core_rule_excluded = [
  "SizeRestrictions_BODY",  # If you have large POST bodies
  "GenericRFI_BODY"          # If causing false positives
]
```

### 4. Enable Sampling

Để giảm cost:

```hcl
visibility_config {
  sampled_requests_enabled = true  # Only log sample of requests
}
```

### 5. Configure Alarms with SNS

```hcl
# Create SNS topic first
resource "aws_sns_topic" "waf_alerts" {
  name = "waf-alerts-${var.environment}"
}

# Add to WAF config
waf_alarm_actions = [aws_sns_topic.waf_alerts.arn]
```

## Troubleshooting

### Issue 1: False Positives

**Problem**: Legitimate requests blocked

**Solution**:
```bash
# Check WAF logs
aws logs filter-log-events \
  --log-group-name /aws/waf/my-eks-dev \
  --filter-pattern "{ $.action = \"BLOCK\" }"

# Identify problematic rule
# Add to excluded rules
waf_core_rule_excluded = ["RuleName"]
```

### Issue 2: Rate Limiting Too Aggressive

**Problem**: Users getting rate limited

**Solution**:
```hcl
# Increase limit
waf_rate_limit_value = 5000

# Or disable temporarily
waf_enable_rate_limit = false
```

### Issue 3: Geo Blocking Blocking Legitimate Traffic

**Problem**: VPN users or travelers blocked

**Solution**:
```hcl
# Use IP whitelist instead
waf_enable_ip_whitelist = true
waf_whitelist_ips = ["known_user_ips"]
```

### Issue 4: High WAF Costs

**Problem**: Costs higher than expected

**Solution**:
- Reduce sampled requests
- Decrease log retention
- Optimize rules (fewer rules = lower cost)

## Integration with CloudFront

WAF module tự động integrate với CloudFront:

```hcl
# In main.tf
module "cloudfront" {
  ...
  waf_web_acl_id = module.waf.waf_web_acl_id
  ...
}
```

CloudFront sẽ apply WAF rules cho tất cả requests.

## Advanced: Custom Rules

Để tạo custom rules, edit `modules/waf/main.tf`:

```hcl
# Example: Block user agents
rule {
  name     = "BlockBadUserAgents"
  priority = 10

  action {
    block {}
  }

  statement {
    byte_match_statement {
      field_to_match {
        single_header {
          name = "user-agent"
        }
      }

      positional_constraint = "CONTAINS"
      search_string         = "badbot"

      text_transformation {
        priority = 0
        type     = "LOWERCASE"
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "bad-user-agents"
    sampled_requests_enabled   = true
  }
}
```

## Rollback

Disable WAF nếu gặp vấn đề:

```hcl
# terraform.tfvars
enable_waf = false

# Apply
terraform apply
```

CloudFront sẽ vẫn hoạt động bình thường.

## Resources Created

- `aws_wafv2_web_acl.main` - WAF Web ACL
- `aws_wafv2_ip_set.blacklist` - IP blacklist
- `aws_wafv2_ip_set.whitelist` - IP whitelist  
- `aws_wafv2_regex_pattern_set.custom` - Regex patterns
- `aws_cloudwatch_log_group.waf_logs` - CloudWatch logs
- `aws_wafv2_web_acl_logging_configuration.main` - Logging config
- `aws_cloudwatch_metric_alarm.blocked_requests` - Alarm
- `aws_cloudwatch_metric_alarm.rate_limited` - Alarm

## Next Steps

1. ✅ Deploy WAF module
2. ✅ Monitor CloudWatch logs for false positives
3. ✅ Tune rules based on traffic patterns
4. ✅ Configure SNS alerts
5. ✅ Test all rules thoroughly
6. ✅ Document any custom rules added
