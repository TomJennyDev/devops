# CloudFront CDN Deployment Guide

## Overview

This guide explains how to deploy AWS CloudFront CDN in front of your EKS Application Load Balancer to provide:

- **Global Edge Caching**: Improve performance for users worldwide
- **DDoS Protection**: AWS Shield Standard (included with CloudFront)
- **Cost Optimization**: Reduce ALB traffic through aggressive caching
- **Security**: WAF integration, custom security headers, origin verification
- **Monitoring**: CloudWatch alarms for 5xx errors and cache hit rate

## Architecture

```
Users → CloudFront (CDN) → ALB → EKS Pods
         (Edge Locations)   (VPC)
```

### Traffic Flow

1. **User Request** → CloudFront edge location (nearest to user)
2. **Cache Hit** → CloudFront serves from cache (fast)
3. **Cache Miss** → CloudFront fetches from ALB (origin)
4. **ALB** → Routes to EKS pods via Ingress
5. **Response** → Cached at CloudFront edge, served to user

## Prerequisites

### 1. ACM Certificate in us-east-1

CloudFront requires certificates in **us-east-1** region (global service).

```bash
# Switch to us-east-1
aws configure set region us-east-1

# Request certificate
aws acm request-certificate \
  --domain-name cdn-dev.do2506.click \
  --validation-method DNS \
  --subject-alternative-names "*.cdn-dev.do2506.click"

# Get certificate ARN (copy this)
aws acm list-certificates --region us-east-1
```

### 2. Validate Certificate via Route53

```bash
# Describe certificate to get validation CNAME records
aws acm describe-certificate \
  --certificate-arn arn:aws:acm:us-east-1:ACCOUNT:certificate/ID \
  --region us-east-1

# Add CNAME records to Route53 (or wait for auto-validation if using same AWS account)
```

### 3. S3 Bucket for Logs (Optional)

```bash
# Create S3 bucket for CloudFront access logs
aws s3 mb s3://cloudfront-logs-dev-372836560690 --region ap-southeast-1

# Enable logging in terraform.tfvars
cloudfront_enable_logging = true
cloudfront_logging_bucket = "cloudfront-logs-dev-372836560690"
```

## Configuration

### Step 1: Update terraform.tfvars

Edit `terraform-eks/environments/dev/terraform.tfvars`:

```hcl
# ==================== CLOUDFRONT CDN ====================
environment       = "dev"
enable_cloudfront = true

# Domain configuration
cloudfront_aliases            = ["cdn-dev.do2506.click"]
cloudfront_alb_domain_name    = "flowise-dev.do2506.click"  # Your ALB domain

# ACM Certificate (us-east-1)
cloudfront_acm_certificate_arn = "arn:aws:acm:us-east-1:372836560690:certificate/YOUR-CERT-ID"

# Price class
cloudfront_price_class = "PriceClass_100"  # US, Canada, Europe

# Caching
cloudfront_cache_default_ttl = 3600   # 1 hour
cloudfront_cache_max_ttl     = 86400  # 24 hours
cloudfront_cache_min_ttl     = 0

# Origin security header
cloudfront_origin_custom_header = "random-secret-string-12345"  # Change this!

# Logging (optional)
cloudfront_enable_logging = true
cloudfront_logging_bucket = "cloudfront-logs-dev-372836560690"

# Monitoring
cloudfront_enable_alarms         = true
cloudfront_error_rate_threshold  = 5    # Alert if 5xx > 5%
cloudfront_cache_hit_threshold   = 80   # Alert if hit rate < 80%
```

### Step 2: Deploy Infrastructure

```bash
cd terraform-eks/environments/dev

# Initialize (first time only)
terraform init

# Plan changes
terraform plan

# Apply
terraform apply
```

Expected output:

```
module.cloudfront.aws_cloudfront_distribution.main[0]: Creating...
module.cloudfront.aws_cloudfront_distribution.main[0]: Still creating... [10s elapsed]
module.cloudfront.aws_cloudfront_distribution.main[0]: Still creating... [5m0s elapsed]
module.cloudfront.aws_cloudfront_distribution.main[0]: Creation complete after 5m23s

Outputs:
cloudfront_distribution_id = "E1234567890ABC"
cloudfront_domain_name     = "d12345abcde.cloudfront.net"
cloudfront_status          = "Deployed"
```

### Step 3: Verify Deployment

```bash
# Get CloudFront distribution details
aws cloudfront get-distribution --id E1234567890ABC

# Test CloudFront domain (*.cloudfront.net)
curl -I https://d12345abcde.cloudfront.net

# Test custom domain (after DNS propagation)
curl -I https://cdn-dev.do2506.click
```

## Cache Behaviors

The CloudFront module includes optimized cache behaviors:

### 1. Static Assets (High Cache)

- **Paths**: `/static/*`, `*.css`, `*.js`, `*.png`, `*.jpg`, `*.svg`, `*.woff`, `*.woff2`
- **TTL**: Min 3600s (1h), Default 86400s (24h), Max 31536000s (365d)
- **Compression**: Gzip, Brotli
- **Methods**: GET, HEAD, OPTIONS

### 2. API Endpoints (No Cache)

- **Paths**: `/api/*`
- **TTL**: Min 0s, Default 0s, Max 0s (no caching)
- **Methods**: GET, HEAD, OPTIONS, PUT, POST, PATCH, DELETE
- **Forward**: All headers, query strings, cookies

### 3. Default Behavior (Medium Cache)

- **Path**: `/*` (everything else)
- **TTL**: Min 0s, Default 3600s (1h), Max 86400s (24h)
- **Methods**: GET, HEAD, OPTIONS

## Security Headers

CloudFront automatically adds security headers to all responses:

```
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 1; mode=block
Referrer-Policy: strict-origin-when-cross-origin
```

## Origin Verification

To ensure traffic comes only from CloudFront (not directly to ALB):

### Option 1: Custom Header (Recommended)

CloudFront sends a custom header to ALB:

```
X-Custom-Origin-Verify: random-secret-string-12345
```

Update ALB Ingress to verify this header:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    alb.ingress.kubernetes.io/conditions.deny: |
      [{"field":"http-header","httpHeaderConfig":{"httpHeaderName":"X-Custom-Origin-Verify","values":["!random-secret-string-12345"]}}]
    alb.ingress.kubernetes.io/actions.deny: |
      {"type":"fixed-response","fixedResponseConfig":{"statusCode":"403"}}
```

### Option 2: AWS WAF (Advanced)

Use AWS WAF to allow only CloudFront IPs:

```bash
# Create WAF Web ACL
aws wafv2 create-web-acl --name cloudfront-origin-waf --region us-east-1 ...

# Associate with CloudFront
cloudfront_waf_web_acl_id = "arn:aws:wafv2:us-east-1:ACCOUNT:global/webacl/..."
```

## Monitoring

### CloudWatch Metrics

Monitor these key metrics in CloudWatch:

1. **5xx Error Rate**
   - Namespace: `AWS/CloudFront`
   - Metric: `5xxErrorRate`
   - Alarm: > 5%

2. **Cache Hit Rate**
   - Namespace: `AWS/CloudFront`
   - Metric: `CacheHitRate`
   - Alarm: < 80%

3. **Origin Latency**
   - Metric: `OriginLatency`
   - Monitor: Avg, P90, P99

4. **Bytes Downloaded/Uploaded**
   - Track bandwidth usage
   - Cost optimization

### CloudWatch Dashboard

```bash
# View CloudFront metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/CloudFront \
  --metric-name CacheHitRate \
  --dimensions Name=DistributionId,Value=E1234567890ABC \
  --start-time 2025-01-28T00:00:00Z \
  --end-time 2025-01-28T23:59:59Z \
  --period 3600 \
  --statistics Average
```

## Invalidation

Clear CloudFront cache when deploying new versions:

```bash
# Invalidate all paths
aws cloudfront create-invalidation \
  --distribution-id E1234567890ABC \
  --paths "/*"

# Invalidate specific paths
aws cloudfront create-invalidation \
  --distribution-id E1234567890ABC \
  --paths "/static/*" "/index.html"

# Check invalidation status
aws cloudfront get-invalidation \
  --distribution-id E1234567890ABC \
  --id I1234567890ABC
```

**Note**: First 1000 invalidations/month are free, then $0.005 per path.

## Cost Optimization

### Price Classes

Choose based on your user distribution:

1. **PriceClass_100** (Cheapest) - $0.085/GB
   - US, Canada, Europe
   - Best for: Dev/staging environments

2. **PriceClass_200** (Medium) - $0.100/GB
   - + Asia Pacific (except Australia/NZ)
   - Best for: Global applications

3. **PriceClass_All** (Most Expensive) - $0.120/GB
   - All edge locations worldwide
   - Best for: Global production with users everywhere

### Cache Strategy

Optimize cache to reduce origin requests:

- **Static assets**: Long TTL (365 days)
- **Application pages**: Medium TTL (1 hour)
- **API endpoints**: No cache (0 seconds)
- **Compress content**: Enable Gzip/Brotli

### Example Cost Calculation (Dev)

```
Assumptions:
- 100GB data transfer/month
- 1M requests/month
- PriceClass_100

Costs:
- Data transfer: 100GB × $0.085 = $8.50
- Requests: 1M × $0.0075/10k = $0.75
- Total: ~$9.25/month
```

## Troubleshooting

### 1. 403 Forbidden

**Cause**: ACM certificate not validated or incorrect domain

**Solution**:

```bash
# Check certificate status
aws acm describe-certificate \
  --certificate-arn YOUR-ARN \
  --region us-east-1

# Ensure domain matches CloudFront alias
```

### 2. 502 Bad Gateway

**Cause**: Origin (ALB) is unhealthy or unreachable

**Solution**:

```bash
# Check ALB health
kubectl get ingress -n flowise

# Check pods
kubectl get pods -n flowise

# Check ALB target group
aws elbv2 describe-target-health --target-group-arn ARN
```

### 3. Cache Not Working

**Cause**: Cache-Control headers from origin

**Solution**:

- Check response headers: `curl -I https://your-domain.com`
- Verify cache behaviors in CloudFront
- Check CloudWatch `CacheHitRate` metric

### 4. High Latency

**Cause**: All requests going to origin (cache misses)

**Solution**:

- Review cache behaviors and TTLs
- Check if `Cache-Control: no-cache` is set by origin
- Verify query string/cookie forwarding settings

## Rollback

To disable CloudFront and revert to direct ALB access:

```bash
# Method 1: Disable in terraform.tfvars
enable_cloudfront = false
terraform apply

# Method 2: Update DNS to point to ALB
# Edit Route53 record to use ALB instead of CloudFront

# Method 3: Destroy distribution
terraform destroy -target=module.cloudfront
```

## Advanced Configuration

### S3 Origin for Static Assets

Offload static files to S3 for better performance:

```hcl
cloudfront_enable_s3_origin  = true
cloudfront_s3_bucket_domain  = "my-static-assets.s3.amazonaws.com"
cloudfront_s3_oai            = "origin-access-identity/cloudfront/E1234567890ABC"
```

### CloudFront Functions

Add custom logic at edge:

```javascript
// URL rewrite function
function handler(event) {
    var request = event.request;
    var uri = request.uri;

    // Redirect /old-path to /new-path
    if (uri === '/old-path') {
        request.uri = '/new-path';
    }

    return request;
}
```

Deploy function:

```bash
aws cloudfront create-function \
  --name url-rewrite \
  --function-code fileb://function.js \
  --function-config Comment="URL rewriting",Runtime="cloudfront-js-1.0"
```

Enable in terraform:

```hcl
cloudfront_enable_url_rewrite = true
cloudfront_function_arn       = "arn:aws:cloudfront::ACCOUNT:function/url-rewrite"
```

### Geo Restrictions

Restrict access by country:

```hcl
# Whitelist (allow only these countries)
cloudfront_geo_restriction_type      = "whitelist"
cloudfront_geo_restriction_locations = ["US", "CA", "GB", "DE", "FR", "VN"]

# Blacklist (block these countries)
cloudfront_geo_restriction_type      = "blacklist"
cloudfront_geo_restriction_locations = ["CN", "RU", "KP"]
```

## Next Steps

1. **Create ACM certificate** in us-east-1
2. **Update terraform.tfvars** with certificate ARN
3. **Deploy CloudFront** via Terraform
4. **Test distribution** using cloudfront.net domain
5. **Update DNS** to point to CloudFront
6. **Monitor metrics** in CloudWatch
7. **Optimize cache** based on hit rate

## Resources

- [AWS CloudFront Documentation](https://docs.aws.amazon.com/cloudfront/)
- [CloudFront Pricing](https://aws.amazon.com/cloudfront/pricing/)
- [CloudFront Security Best Practices](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/security-best-practices.html)
- [CloudFront Functions](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cloudfront-functions.html)
