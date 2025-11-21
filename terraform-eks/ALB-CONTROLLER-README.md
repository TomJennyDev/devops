# AWS Load Balancer Controller Guide

Hướng dẫn cấu hình và sử dụng AWS Load Balancer Controller cho EKS để tạo ALB (Application Load Balancer) và NLB (Network Load Balancer).

## 📋 Tổng quan

AWS Load Balancer Controller quản lý AWS Elastic Load Balancers cho Kubernetes cluster:
- **ALB (Application Load Balancer)** - Layer 7 (HTTP/HTTPS)
- **NLB (Network Load Balancer)** - Layer 4 (TCP/UDP)

## 🚀 Setup

### Step 1: Enable trong Terraform

File `alb-controller.tf` đã được tạo sẵn. Enable trong `terraform.tfvars`:

```hcl
enable_aws_load_balancer_controller = true
```

### Step 2: Apply Terraform

```bash
terraform apply
```

Terraform sẽ tạo:
- ✅ IAM Role với IRSA (IAM Roles for Service Accounts)
- ✅ IAM Policy với đủ quyền cho ALB/NLB
- ✅ OIDC Provider integration

### Step 3: Install AWS Load Balancer Controller

#### Option A: Sử dụng Helm (Recommended)

```bash
# Add Helm repo
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Get IAM role ARN from Terraform output
export AWS_LOAD_BALANCER_ROLE_ARN=$(terraform output -raw aws_load_balancer_controller_role_arn)
export CLUSTER_NAME=$(terraform output -raw cluster_name)
export AWS_REGION=$(terraform output -json | jq -r '.aws_region.value')

# Install AWS Load Balancer Controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=${CLUSTER_NAME} \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=${AWS_LOAD_BALANCER_ROLE_ARN} \
  --set region=${AWS_REGION} \
  --set vpcId=$(terraform output -raw vpc_id)
```

#### Option B: Sử dụng kubectl

Download và apply manifest:

```bash
curl -Lo v2_7_2_full.yaml https://github.com/kubernetes-sigs/aws-load-balancer-controller/releases/download/v2.7.2/v2_7_2_full.yaml

# Edit file - thay YOUR_CLUSTER_NAME
sed -i.bak -e "s|your-cluster-name|${CLUSTER_NAME}|" v2_7_2_full.yaml

# Apply
kubectl apply -f v2_7_2_full.yaml
```

### Step 4: Verify Installation

```bash
# Check deployment
kubectl get deployment -n kube-system aws-load-balancer-controller

# Check logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Check service account
kubectl describe sa aws-load-balancer-controller -n kube-system
```

---

## 🌐 Sử dụng ALB (Application Load Balancer)

### Example 1: Basic ALB Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app-ingress
  annotations:
    # ALB annotations
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
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
            name: my-app-service
            port:
              number: 80
```

Apply:
```bash
kubectl apply -f alb-ingress.yaml

# Get ALB DNS
kubectl get ingress my-app-ingress
```

### Example 2: ALB with HTTPS (SSL Certificate)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app-https
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/ssl-redirect: '443'
    # Certificate ARN from ACM
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-west-2:123456789:certificate/xxx
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
            name: my-app-service
            port:
              number: 80
```

### Example 3: Multiple Paths (Microservices)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: microservices-ingress
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  ingressClassName: alb
  rules:
  - host: api.example.com
    http:
      paths:
      - path: /users
        pathType: Prefix
        backend:
          service:
            name: user-service
            port:
              number: 80
      - path: /products
        pathType: Prefix
        backend:
          service:
            name: product-service
            port:
              number: 80
      - path: /orders
        pathType: Prefix
        backend:
          service:
            name: order-service
            port:
              number: 80
```

### Example 4: Internal ALB (Private)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: internal-app
  annotations:
    alb.ingress.kubernetes.io/scheme: internal  # Private ALB
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/subnets: subnet-xxx,subnet-yyy  # Private subnets
spec:
  ingressClassName: alb
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: internal-service
            port:
              number: 80
```

---

## 🔌 Sử dụng NLB (Network Load Balancer)

### Example 1: Basic NLB Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app-nlb
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "external"
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "ip"
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
spec:
  type: LoadBalancer
  loadBalancerClass: service.k8s.aws/nlb
  selector:
    app: my-app
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP
```

### Example 2: NLB with TLS Termination

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app-nlb-tls
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "external"
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "ip"
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
    # TLS Certificate ARN
    service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "arn:aws:acm:us-west-2:123456789:certificate/xxx"
    service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "443"
    service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "tcp"
spec:
  type: LoadBalancer
  loadBalancerClass: service.k8s.aws/nlb
  selector:
    app: my-app
  ports:
  - name: https
    port: 443
    targetPort: 8080
    protocol: TCP
  - name: http
    port: 80
    targetPort: 8080
    protocol: TCP
```

### Example 3: Internal NLB

```yaml
apiVersion: v1
kind: Service
metadata:
  name: internal-nlb
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "external"
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "ip"
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internal"  # Private
    service.beta.kubernetes.io/aws-load-balancer-subnets: "subnet-xxx,subnet-yyy"
spec:
  type: LoadBalancer
  loadBalancerClass: service.k8s.aws/nlb
  selector:
    app: internal-app
  ports:
  - port: 3306
    targetPort: 3306
    protocol: TCP
```

---

## 🎯 Common Annotations

### ALB Annotations

```yaml
# Scheme
alb.ingress.kubernetes.io/scheme: internet-facing  # or internal

# Target type
alb.ingress.kubernetes.io/target-type: ip  # or instance

# Listen ports
alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'

# SSL Certificate
alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:...

# SSL Redirect
alb.ingress.kubernetes.io/ssl-redirect: '443'

# Health check
alb.ingress.kubernetes.io/healthcheck-path: /health
alb.ingress.kubernetes.io/healthcheck-interval-seconds: '30'
alb.ingress.kubernetes.io/healthcheck-timeout-seconds: '5'
alb.ingress.kubernetes.io/healthy-threshold-count: '2'
alb.ingress.kubernetes.io/unhealthy-threshold-count: '2'

# WAF
alb.ingress.kubernetes.io/wafv2-acl-arn: arn:aws:wafv2:...

# Security groups
alb.ingress.kubernetes.io/security-groups: sg-xxx,sg-yyy

# Subnets
alb.ingress.kubernetes.io/subnets: subnet-xxx,subnet-yyy

# Tags
alb.ingress.kubernetes.io/tags: Environment=prod,Team=platform

# Load balancer attributes
alb.ingress.kubernetes.io/load-balancer-attributes: idle_timeout.timeout_seconds=60

# Target group attributes
alb.ingress.kubernetes.io/target-group-attributes: deregistration_delay.timeout_seconds=30
```

### NLB Annotations

```yaml
# Type
service.beta.kubernetes.io/aws-load-balancer-type: external

# NLB target type
service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip  # or instance

# Scheme
service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing  # or internal

# SSL Certificate
service.beta.kubernetes.io/aws-load-balancer-ssl-cert: arn:aws:acm:...

# SSL Ports
service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "443"

# Backend protocol
service.beta.kubernetes.io/aws-load-balancer-backend-protocol: tcp

# Cross-zone load balancing
service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"

# Subnets
service.beta.kubernetes.io/aws-load-balancer-subnets: subnet-xxx,subnet-yyy

# Tags
service.beta.kubernetes.io/aws-load-balancer-additional-resource-tags: Environment=prod
```

---

## 💰 Cost Considerations

### ALB Pricing (us-west-2)
- **ALB Hours**: $0.0225/hour (~$16/month)
- **LCU (Load Balancer Capacity Units)**: $0.008/LCU-hour
- **Average cost**: ~$20-50/month per ALB

### NLB Pricing (us-west-2)
- **NLB Hours**: $0.0225/hour (~$16/month)
- **NLCU**: $0.006/NLCU-hour
- **Average cost**: ~$20-40/month per NLB

### Cost Optimization Tips

1. **Share ALB across multiple Ingresses**
```yaml
# Use IngressGroup to share one ALB
alb.ingress.kubernetes.io/group.name: shared-alb
```

2. **Use internal ALBs when possible**
```yaml
alb.ingress.kubernetes.io/scheme: internal
```

3. **Cleanup unused load balancers**
```bash
kubectl get ingress --all-namespaces
kubectl get svc -A | grep LoadBalancer
```

---

## 🔍 Monitoring & Debugging

### Check ALB/NLB Creation

```bash
# Get Ingress
kubectl get ingress -A

# Describe Ingress (shows ALB creation status)
kubectl describe ingress <ingress-name>

# Get Services
kubectl get svc -A

# Check controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller --follow
```

### Check AWS Console

```bash
# Get ALB ARN from tags
aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[?contains(Tags[?Key==`elbv2.k8s.aws/cluster`].Value, `my-eks-cluster`)]'

# Get NLB
aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[?Type==`network`]'
```

### Common Issues

**Issue 1: Ingress stuck in pending**
```bash
# Check controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Check IAM role
kubectl describe sa aws-load-balancer-controller -n kube-system
```

**Issue 2: 503 Service Unavailable**
```bash
# Check target health
aws elbv2 describe-target-health --target-group-arn <arn>

# Check pod health
kubectl get pods -l app=my-app
```

**Issue 3: Certificate errors**
```bash
# Verify certificate ARN
aws acm describe-certificate --certificate-arn <arn>
```

---

## 🎯 Best Practices

### 1. Use IngressClass
```yaml
spec:
  ingressClassName: alb  # Always specify
```

### 2. Group Ingresses (Share ALB)
```yaml
annotations:
  alb.ingress.kubernetes.io/group.name: my-group
  alb.ingress.kubernetes.io/group.order: '10'
```

### 3. Configure Health Checks
```yaml
annotations:
  alb.ingress.kubernetes.io/healthcheck-path: /health
  alb.ingress.kubernetes.io/healthcheck-interval-seconds: '30'
```

### 4. Use SSL/TLS
```yaml
annotations:
  alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:...
  alb.ingress.kubernetes.io/ssl-redirect: '443'
```

### 5. Add Tags for Cost Allocation
```yaml
annotations:
  alb.ingress.kubernetes.io/tags: Environment=prod,CostCenter=engineering
```

### 6. Configure Timeouts
```yaml
annotations:
  alb.ingress.kubernetes.io/load-balancer-attributes: idle_timeout.timeout_seconds=60
  alb.ingress.kubernetes.io/target-group-attributes: deregistration_delay.timeout_seconds=30
```

---

## 📚 Examples Repository

Check `examples/` folder for more examples:
- ALB with multiple domains
- NLB with TCP/UDP
- gRPC load balancing
- WebSocket support
- Rate limiting with WAF

---

## 🔗 References

- [AWS Load Balancer Controller Docs](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [ALB Ingress Annotations](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.7/guide/ingress/annotations/)
- [NLB Service Annotations](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.7/guide/service/annotations/)
- [AWS ALB Pricing](https://aws.amazon.com/elasticloadbalancing/pricing/)
- [Troubleshooting Guide](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.7/deploy/troubleshooting/)

---

## ✅ Quick Start Checklist

- [ ] Enable `enable_aws_load_balancer_controller = true` in terraform.tfvars
- [ ] Run `terraform apply`
- [ ] Install controller via Helm or kubectl
- [ ] Verify installation: `kubectl get deployment -n kube-system aws-load-balancer-controller`
- [ ] Create first Ingress/Service
- [ ] Check ALB/NLB created in AWS Console
- [ ] Test application access
- [ ] Configure SSL certificate (optional)
- [ ] Add monitoring/alerts
