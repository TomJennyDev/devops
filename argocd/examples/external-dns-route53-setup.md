# External DNS Setup Guide for Route53

External DNS tự động tạo và quản lý Route53 DNS records từ Kubernetes Ingress và Services.

## 🎯 Tổng quan

```
Kubernetes Ingress/Service
    ↓ (External DNS watches)
Route53 Hosted Zone
    ↓ (Auto create/update/delete records)
DNS Records → ALB/NLB
```

## 📋 Prerequisites

1. **Route53 Hosted Zone** đã được tạo
2. **Domain** đã được configure nameservers

## 🚀 Setup Guide

### Step 1: Tạo Route53 Hosted Zone (nếu chưa có)

```bash
# Create hosted zone
aws route53 create-hosted-zone \
  --name example.com \
  --caller-reference $(date +%s)

# Get hosted zone ID and ARN
aws route53 list-hosted-zones-by-name \
  --dns-name example.com \
  --query 'HostedZones[0].[Id,Name]' \
  --output table

# Get full ARN
export ZONE_ID="Z1234567890ABC"
export ZONE_ARN="arn:aws:route53:::hostedzone/${ZONE_ID}"
```

### Step 2: Enable External DNS trong Terraform

Edit `terraform.tfvars`:

```hcl
# Enable External DNS
enable_external_dns = true

# Restrict to specific hosted zones (recommended)
route53_zone_arns = [
  "arn:aws:route53:::hostedzone/Z1234567890ABC"  # example.com
]

# Or allow all zones (not recommended for production)
# route53_zone_arns = []
```

### Step 3: Apply Terraform

```bash
cd environments/dev  # or staging/prod
terraform plan
terraform apply

# Get External DNS IAM Role ARN
terraform output external_dns_role_arn
```

Output:
```
external_dns_role_arn = "arn:aws:iam::123456789012:role/my-eks-dev-external-dns-xxxxx"
```

### Step 4: Update ArgoCD Configuration

Edit `argocd/system-apps/external-dns.yaml`:

```yaml
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/my-eks-dev-external-dns-xxxxx

domainFilters:
  - example.com
  - subdomain.example.com
```

### Step 5: Deploy External DNS via ArgoCD

```bash
# Deploy External DNS
kubectl apply -f argocd/system-apps/external-dns.yaml

# Check deployment
kubectl get pods -n external-dns
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns
```

## 📝 Usage Examples

### Example 1: Ingress with External DNS

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  namespace: default
  annotations:
    # ALB configuration
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:...
    
    # External DNS annotation
    external-dns.alpha.kubernetes.io/hostname: myapp.example.com,www.myapp.example.com
    
    # Optional: TTL
    external-dns.alpha.kubernetes.io/ttl: "300"
spec:
  ingressClassName: alb
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp
            port:
              number: 80
```

**Result:**
```
myapp.example.com     → CNAME → k8s-default-myappingr-xxxxx.region.elb.amazonaws.com
www.myapp.example.com → CNAME → k8s-default-myappingr-xxxxx.region.elb.amazonaws.com
```

### Example 2: LoadBalancer Service with External DNS

```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp-nlb
  namespace: default
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    external-dns.alpha.kubernetes.io/hostname: api.example.com
    external-dns.alpha.kubernetes.io/ttl: "60"
spec:
  type: LoadBalancer
  selector:
    app: myapp
  ports:
  - port: 443
    targetPort: 8443
```

**Result:**
```
api.example.com → A record → NLB IP addresses
```

### Example 3: Multiple Domains

```yaml
annotations:
  external-dns.alpha.kubernetes.io/hostname: >
    app.example.com,
    app.staging.example.com,
    app.dev.example.com
```

### Example 4: Exclude from External DNS

```yaml
annotations:
  # Don't create DNS records
  external-dns.alpha.kubernetes.io/exclude: "true"
```

## 🔍 Verification

### Check DNS Records

```bash
# List records in hosted zone
aws route53 list-resource-record-sets \
  --hosted-zone-id Z1234567890ABC \
  --query "ResourceRecordSets[?contains(Name, 'myapp')]"

# Test DNS resolution
nslookup myapp.example.com
dig myapp.example.com
```

### Check External DNS Logs

```bash
# Watch External DNS logs
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns -f

# Expected output:
# time="2025-11-23T10:00:00Z" level=info msg="Desired change: CREATE myapp.example.com CNAME"
# time="2025-11-23T10:00:01Z" level=info msg="2 record(s) in zone example.com were successfully updated"
```

## 🔧 Configuration Options

### Policy Modes

```yaml
# sync: Create and delete records (recommended)
policy: sync

# upsert-only: Only create/update, never delete
policy: upsert-only

# create-only: Only create new records
policy: create-only
```

### TXT Registry

External DNS creates TXT records to track ownership:

```
myapp.example.com              → CNAME → ALB
txt.myapp.example.com          → TXT   → "heritage=external-dns,external-dns/owner=my-cluster"
```

### Domain Filters

```yaml
# Allow specific domains only
domainFilters:
  - example.com
  - api.example.com

# No filters = all domains (not recommended)
domainFilters: []
```

## 🐛 Troubleshooting

### DNS records not created

```bash
# Check External DNS pods
kubectl get pods -n external-dns

# Check logs
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns

# Common issues:
# 1. IAM role not attached
kubectl describe sa external-dns -n external-dns | grep Annotations

# 2. Domain not in domainFilters
# 3. Wrong hosted zone ARN in terraform
# 4. Ingress missing hostname annotation
```

### DNS records not deleted

```bash
# Check policy mode (should be "sync" not "upsert-only")
kubectl get deployment external-dns -n external-dns -o yaml | grep policy

# Check TXT registry
aws route53 list-resource-record-sets \
  --hosted-zone-id Z1234567890ABC \
  --query "ResourceRecordSets[?Type=='TXT']"
```

### Permission errors

```bash
# Verify IAM role
aws iam get-role --role-name my-eks-dev-external-dns-xxxxx

# Test IAM permissions
aws route53 list-hosted-zones
aws route53 list-resource-record-sets --hosted-zone-id Z1234567890ABC
```

## 💡 Best Practices

1. ✅ **Use domainFilters**: Restrict to specific domains
2. ✅ **Use route53_zone_arns**: Limit access to specific hosted zones
3. ✅ **Use sync policy**: Allow automatic cleanup
4. ✅ **Set appropriate TTL**: Lower TTL (60-300s) for faster updates
5. ✅ **Monitor logs**: Watch for errors and DNS changes
6. ✅ **Use TXT registry**: Enables ownership tracking
7. ✅ **Separate zones**: Use different zones for dev/staging/prod
8. ✅ **Test in dev first**: Validate DNS changes before prod

## 🚨 Security Considerations

### Least Privilege IAM

Terraform tạo IAM policy với quyền tối thiểu:
- `route53:ChangeResourceRecordSets` - Chỉ cho zones được chỉ định
- `route53:ListHostedZones` - Read-only
- `route53:ListResourceRecordSets` - Read-only

### Production Recommendations

```hcl
# Production terraform.tfvars
enable_external_dns = true
route53_zone_arns = [
  "arn:aws:route53:::hostedzone/Z1111111111AAA"  # prod.example.com only
]
```

```yaml
# Production external-dns config
domainFilters:
  - prod.example.com  # Only production domain
policy: sync
logLevel: warning  # Reduce log verbosity
```

## 📚 Resources

- [External DNS Documentation](https://github.com/kubernetes-sigs/external-dns)
- [AWS Route53 Documentation](https://docs.aws.amazon.com/route53/)
- [ExternalDNS FAQ](https://github.com/kubernetes-sigs/external-dns/blob/master/docs/faq.md)
