# EKS Addons Guide

Complete guide to EKS addons management and their purposes.

## 📋 Table of Contents

- [Core Addons (Required)](#core-addons-required)
- [Optional System Addons](#optional-system-addons)
- [Version Management](#version-management)
- [Troubleshooting](#troubleshooting)

---

## Core Addons (Required)

These 3 addons are **essential** for EKS cluster to function. Automatically installed by EKS, managed by Terraform.

### 1. VPC CNI (`amazon-vpc-cni`)

**Purpose:** Networking plugin that assigns VPC IP addresses to pods

**Current Version:** `v1.20.4-eksbuild.3` (EKS 1.34)

**Key Features:**
- Each pod gets a real IP address from your VPC subnet
- Pods can communicate directly with AWS services
- No overlay network (unlike Calico/Flannel)
- Supports Security Groups for Pods (SGP)
- ENI-based networking with multiple IPs per node

**How it works:**
```
VPC Subnet: 10.0.11.0/24
├─ EC2 Node: 10.0.11.10
│   ├─ Pod 1: 10.0.11.45
│   ├─ Pod 2: 10.0.11.46
│   └─ Pod 3: 10.0.11.47
└─ All IPs are "first-class citizens" in VPC
```

**Configuration:**
```hcl
# terraform.tfvars
vpc_cni_version = "v1.20.4-eksbuild.3"
```

**IAM Permissions Required:**
- `ec2:AssignPrivateIpAddresses`
- `ec2:AttachNetworkInterface`
- `ec2:CreateNetworkInterface`
- `ec2:DescribeNetworkInterfaces`

**Common Issues:**
- **IP exhaustion:** Subnet too small for pod count
  - Solution: Use larger subnets or enable prefix delegation
- **Pods pending:** No available IPs
  - Solution: Check subnet CIDR ranges

**Monitoring:**
```bash
# Check VPC CNI pods
kubectl get pods -n kube-system -l k8s-app=aws-node

# Check available IPs
kubectl describe node <node-name> | grep Allocatable
```

---

### 2. CoreDNS (`coredns`)

**Purpose:** DNS server for service discovery within the cluster

**Current Version:** `v1.12.4-eksbuild.1` (EKS 1.34)

**Key Features:**
- Resolves Kubernetes service names to IP addresses
- DNS-based service discovery
- Caching for performance
- Customizable with ConfigMap

**How it works:**
```
Request: curl http://my-backend-service

1. Pod queries CoreDNS: "my-backend-service.default.svc.cluster.local"
2. CoreDNS returns: 10.100.45.23 (Service ClusterIP)
3. Pod connects to Service IP
```

**DNS Records Automatically Created:**
```
Services:
  my-service.default.svc.cluster.local → Service ClusterIP
  my-service.default → Short form
  my-service → Even shorter (same namespace)

Pods:
  pod-10-0-11-45.default.pod.cluster.local → Pod IP
```

**Configuration:**
```hcl
# terraform.tfvars
coredns_version = "v1.12.4-eksbuild.1"
```

**ConfigMap Customization:**
```bash
# Edit CoreDNS config
kubectl edit configmap coredns -n kube-system
```

**Common Issues:**
- **DEGRADED status:** No nodes available
  - Solution: Ensure node group is created
- **DNS resolution slow:** Too many queries
  - Solution: Increase CoreDNS replicas or adjust caching

**Monitoring:**
```bash
# Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Check DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default
```

**Performance Tuning:**
```yaml
# Increase replicas for high-traffic clusters
kubectl scale deployment coredns -n kube-system --replicas=3
```

---

### 3. kube-proxy (`kube-proxy`)

**Purpose:** Network proxy that implements Kubernetes Service abstraction

**Current Version:** `v1.34.1-eksbuild.2` (EKS 1.34)

**Key Features:**
- Load balances traffic to Service endpoints
- Implements iptables/ipvs rules on each node
- Enables Service networking (ClusterIP, NodePort, LoadBalancer)
- Session affinity support

**How it works:**
```
Service Definition:
  apiVersion: v1
  kind: Service
  metadata:
    name: my-app
  spec:
    type: ClusterIP
    ports:
    - port: 80
      targetPort: 8080
    selector:
      app: my-app

kube-proxy creates iptables rules:
  Service IP: 10.100.45.23:80
    ↓ (round-robin load balancing)
    ├─ Pod 1: 10.0.11.45:8080
    ├─ Pod 2: 10.0.11.46:8080
    └─ Pod 3: 10.0.11.47:8080
```

**Configuration:**
```hcl
# terraform.tfvars
kube_proxy_version = "v1.34.1-eksbuild.2"
```

**Proxy Modes:**
- **iptables** (default): Fast, but O(n) rules
- **ipvs**: Better for large clusters (10k+ services)

**Common Issues:**
- **Service unreachable:** iptables rules missing
  - Solution: Restart kube-proxy pods
- **High latency:** Too many iptables rules
  - Solution: Switch to IPVS mode

**Monitoring:**
```bash
# Check kube-proxy pods
kubectl get pods -n kube-system -l k8s-app=kube-proxy

# Check iptables rules
kubectl exec -it <kube-proxy-pod> -n kube-system -- iptables -t nat -L KUBE-SERVICES
```

---

## Optional System Addons

These addons are deployed via ArgoCD (not Terraform) after cluster creation.

### AWS Load Balancer Controller

**Purpose:** Provisions AWS ALB/NLB for Kubernetes Ingress/Service

**Installation:** See [ALB-CONTROLLER-README.md](ALB-CONTROLLER-README.md)

**When to use:**
- Need Application Load Balancer (ALB) for HTTP/HTTPS
- Need Network Load Balancer (NLB) for TCP/UDP
- Want AWS WAF integration
- Certificate management with AWS ACM

**Example:**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:...
spec:
  ingressClassName: alb
  rules:
  - host: api.example.com
    http:
      paths:
      - path: /
        backend:
          service:
            name: my-api
            port:
              number: 80
```

---

### External DNS

**Purpose:** Automatically creates Route53 DNS records for Ingress/Service

**Installation:** See [DNS-ARCHITECTURE.md](DNS-ARCHITECTURE.md)

**When to use:**
- Automate DNS record creation
- Multiple microservices with different domains
- Don't want to manually update Route53

**Example:**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    external-dns.alpha.kubernetes.io/hostname: api.example.com
spec:
  rules:
  - host: api.example.com
    # ...
```

**External DNS automatically creates:**
```
Route53 Record:
  api.example.com → ALB DNS (xxx.elb.amazonaws.com)
```

---

### Metrics Server

**Purpose:** Cluster-wide resource metrics for HPA and kubectl top

**Installation:**
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

**When to use:**
- Enable Horizontal Pod Autoscaler (HPA)
- Monitor resource usage with `kubectl top`

**Example:**
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: my-app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

**Usage:**
```bash
# View pod resource usage
kubectl top pods

# View node resource usage
kubectl top nodes
```

---

## Version Management

### Checking Available Versions

```bash
# List available VPC CNI versions
aws eks describe-addon-versions \
  --kubernetes-version 1.34 \
  --addon-name vpc-cni \
  --query 'addons[0].addonVersions[0:5].[addonVersion]' \
  --output table \
  --region ap-southeast-1

# List available CoreDNS versions
aws eks describe-addon-versions \
  --kubernetes-version 1.34 \
  --addon-name coredns \
  --query 'addons[0].addonVersions[0:5].[addonVersion]' \
  --output table \
  --region ap-southeast-1

# List available kube-proxy versions
aws eks describe-addon-versions \
  --kubernetes-version 1.34 \
  --addon-name kube-proxy \
  --query 'addons[0].addonVersions[0:5].[addonVersion]' \
  --output table \
  --region ap-southeast-1
```

### Updating Addon Versions

1. **Update terraform.tfvars:**
```hcl
vpc_cni_version    = "v1.20.4-eksbuild.3"
coredns_version    = "v1.12.4-eksbuild.1"
kube_proxy_version = "v1.34.1-eksbuild.2"
```

2. **Plan and apply:**
```bash
cd environments/dev
terraform plan
terraform apply
```

3. **Verify update:**
```bash
# Check addon status
aws eks describe-addon \
  --cluster-name my-eks-dev \
  --addon-name vpc-cni \
  --region ap-southeast-1

# Check pod versions
kubectl get pods -n kube-system -l k8s-app=aws-node -o jsonpath='{.items[0].spec.containers[0].image}'
```

### Version Compatibility Matrix

| EKS Version | VPC CNI | CoreDNS | kube-proxy |
|-------------|---------|---------|------------|
| 1.34 | v1.20.4+ | v1.12.4+ | v1.34.1+ |
| 1.33 | v1.19.0+ | v1.11.3+ | v1.33.0+ |
| 1.32 | v1.18.5+ | v1.11.1+ | v1.32.0+ |

**Best Practice:**
- Always use latest patch version for your EKS version
- Test updates in dev before prod
- Update one addon at a time

---

## Troubleshooting

### Addon Status Check

```bash
# List all addons
aws eks list-addons \
  --cluster-name my-eks-dev \
  --region ap-southeast-1

# Check addon health
aws eks describe-addon \
  --cluster-name my-eks-dev \
  --addon-name coredns \
  --region ap-southeast-1 \
  --query 'addon.health'
```

### Common Issues

#### 1. Addon stuck in DEGRADED state

**Cause:** No nodes available to schedule pods

**Solution:**
```bash
# Check if node group exists
aws eks list-nodegroups \
  --cluster-name my-eks-dev \
  --region ap-southeast-1

# Check node status
kubectl get nodes

# If no nodes, ensure terraform created node group
terraform state list | grep node_group
```

#### 2. Addon CREATE_FAILED

**Cause:** Version incompatibility or existing addon

**Solution:**
```bash
# Import existing addon to Terraform state
terraform import 'module.eks.module.eks.aws_eks_addon.coredns[0]' my-eks-dev:coredns

# Or remove and recreate
terraform state rm 'module.eks.module.eks.aws_eks_addon.coredns[0]'
terraform import 'module.eks.module.eks.aws_eks_addon.coredns[0]' my-eks-dev:coredns
```

#### 3. Pods not getting IP addresses

**Cause:** VPC CNI issue or subnet IP exhaustion

**Solution:**
```bash
# Check VPC CNI pods
kubectl get pods -n kube-system -l k8s-app=aws-node

# Check VPC CNI logs
kubectl logs -n kube-system -l k8s-app=aws-node --tail=50

# Check subnet available IPs
aws ec2 describe-subnets \
  --subnet-ids subnet-xxx \
  --query 'Subnets[0].AvailableIpAddressCount'
```

#### 4. DNS resolution not working

**Cause:** CoreDNS pods not running or misconfigured

**Solution:**
```bash
# Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Test DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default

# Check CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=50

# Restart CoreDNS
kubectl rollout restart deployment coredns -n kube-system
```

#### 5. Service not accessible

**Cause:** kube-proxy not working properly

**Solution:**
```bash
# Check kube-proxy pods
kubectl get pods -n kube-system -l k8s-app=kube-proxy

# Check kube-proxy logs
kubectl logs -n kube-system -l k8s-app=kube-proxy --tail=50

# Restart kube-proxy
kubectl delete pods -n kube-system -l k8s-app=kube-proxy
```

---

## Workflow Summary

```
1. Terraform creates EKS cluster
   └─ Installs core addons: VPC CNI, CoreDNS, kube-proxy

2. Terraform creates Node Groups
   └─ Addon pods get scheduled on nodes

3. Deploy system apps via ArgoCD
   ├─ AWS Load Balancer Controller (optional)
   ├─ External DNS (optional)
   └─ Metrics Server (optional)

4. Deploy your applications
   └─ Use Services, Ingress, HPA, etc.
```

---

## Best Practices

1. **Version Management:**
   - Use latest stable versions
   - Test in dev before prod
   - Update one addon at a time

2. **Monitoring:**
   - Check addon status regularly
   - Monitor pod logs for errors
   - Set up CloudWatch alerts

3. **High Availability:**
   - CoreDNS: 2+ replicas
   - Distribute pods across AZs
   - Use Pod Disruption Budgets

4. **Security:**
   - Use IRSA for addon permissions
   - Restrict VPC CNI to minimum IAM
   - Enable audit logs

5. **Performance:**
   - Tune CoreDNS caching
   - Consider IPVS for kube-proxy
   - Enable VPC CNI prefix delegation for large clusters

---

## Additional Resources

- [AWS EKS Addons Documentation](https://docs.aws.amazon.com/eks/latest/userguide/eks-add-ons.html)
- [VPC CNI GitHub](https://github.com/aws/amazon-vpc-cni-k8s)
- [CoreDNS Documentation](https://coredns.io/plugins/kubernetes/)
- [kube-proxy Documentation](https://kubernetes.io/docs/reference/command-line-tools-reference/kube-proxy/)
- [ALB Controller Guide](ALB-CONTROLLER-README.md)
- [DNS Architecture Guide](DNS-ARCHITECTURE.md)
