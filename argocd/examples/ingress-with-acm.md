# Example: Deploy Application with HTTPS using AWS ACM

This example shows how to deploy an application with HTTPS using AWS Certificate Manager (ACM).

## Prerequisites

1. Request or import a certificate in AWS Certificate Manager:
```bash
aws acm request-certificate \
  --domain-name example.com \
  --subject-alternative-names '*.example.com' \
  --validation-method DNS \
  --region ap-southeast-1
```

2. Validate the certificate (DNS validation)
3. Copy the certificate ARN

## Step 1: Deploy Application

```yaml
# app-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  namespace: default
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
      - name: app
        image: nginx:latest
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
---
apiVersion: v1
kind: Service
metadata:
  name: my-app
  namespace: default
spec:
  type: ClusterIP
  selector:
    app: my-app
  ports:
  - port: 80
    targetPort: 80
```

## Step 2: Create Ingress with ACM Certificate

```yaml
# app-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app-ingress
  namespace: default
  annotations:
    # ALB settings
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/group.name: shared-alb  # Share ALB across ingresses
    
    # SSL/TLS with ACM
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:ap-southeast-1:123456789012:certificate/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/ssl-redirect: '443'
    alb.ingress.kubernetes.io/ssl-policy: ELBSecurityPolicy-TLS13-1-2-2021-06
    
    # Health check
    alb.ingress.kubernetes.io/healthcheck-path: /health
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: '15'
    alb.ingress.kubernetes.io/healthcheck-timeout-seconds: '5'
    alb.ingress.kubernetes.io/healthy-threshold-count: '2'
    alb.ingress.kubernetes.io/unhealthy-threshold-count: '2'
    
    # Additional settings
    alb.ingress.kubernetes.io/load-balancer-attributes: idle_timeout.timeout_seconds=60
    alb.ingress.kubernetes.io/target-group-attributes: deregistration_delay.timeout_seconds=30
    
    # External DNS (if configured)
    external-dns.alpha.kubernetes.io/hostname: example.com,www.example.com
spec:
  ingressClassName: alb
  rules:
  - host: example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-app
            port:
              number: 80
  - host: www.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-app
            port:
              number: 80
```

## Step 3: Deploy

```bash
kubectl apply -f app-deployment.yaml
kubectl apply -f app-ingress.yaml

# Check ALB creation
kubectl get ingress my-app-ingress

# Get ALB DNS name
kubectl get ingress my-app-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

## Step 4: Update DNS (if not using External DNS)

Create a CNAME record in Route53:
```
example.com     -> CNAME -> k8s-default-myappingr-xxxxxxxxxx.ap-southeast-1.elb.amazonaws.com
www.example.com -> CNAME -> k8s-default-myappingr-xxxxxxxxxx.ap-southeast-1.elb.amazonaws.com
```

## Common Annotations

### SSL/TLS Options

```yaml
# Multiple certificates for different domains
alb.ingress.kubernetes.io/certificate-arn: >
  arn:aws:acm:region:account:certificate/cert-1,
  arn:aws:acm:region:account:certificate/cert-2

# SSL policy (choose based on security requirements)
alb.ingress.kubernetes.io/ssl-policy: ELBSecurityPolicy-TLS13-1-2-2021-06  # Modern (TLS 1.3)
# alb.ingress.kubernetes.io/ssl-policy: ELBSecurityPolicy-TLS-1-2-2017-01   # Compatible
# alb.ingress.kubernetes.io/ssl-policy: ELBSecurityPolicy-FS-1-2-Res-2020-10  # Forward Secrecy
```

### Access Control

```yaml
# Restrict to specific IP ranges
alb.ingress.kubernetes.io/inbound-cidrs: 10.0.0.0/8,172.16.0.0/12

# WAF WebACL
alb.ingress.kubernetes.io/wafv2-acl-arn: arn:aws:wafv2:region:account:regional/webacl/name/id
```

### Performance & Monitoring

```yaml
# Connection draining
alb.ingress.kubernetes.io/target-group-attributes: deregistration_delay.timeout_seconds=30

# Idle timeout
alb.ingress.kubernetes.io/load-balancer-attributes: idle_timeout.timeout_seconds=60

# Sticky sessions
alb.ingress.kubernetes.io/target-group-attributes: stickiness.enabled=true,stickiness.lb_cookie.duration_seconds=86400
```

## Troubleshooting

### Check ALB Controller logs
```bash
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

### Check Ingress status
```bash
kubectl describe ingress my-app-ingress
```

### Verify certificate
```bash
aws acm describe-certificate \
  --certificate-arn arn:aws:acm:region:account:certificate/xxx \
  --region ap-southeast-1
```

### Test HTTPS
```bash
curl -v https://example.com
```

## Best Practices

1. ✅ Use wildcard certificates (`*.example.com`) for flexibility
2. ✅ Enable SSL redirect (HTTP → HTTPS)
3. ✅ Use latest TLS policy (TLS 1.3)
4. ✅ Share ALB across multiple Ingresses (`group.name`)
5. ✅ Configure health checks appropriately
6. ✅ Use External DNS for automatic DNS management
7. ✅ Set appropriate timeout values
8. ✅ Enable connection draining
9. ✅ Consider using WAF for security
10. ✅ Monitor ALB metrics in CloudWatch
