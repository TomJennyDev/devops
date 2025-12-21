# Prometheus + Grafana Monitoring Stack

Complete monitoring solution using **kube-prometheus-stack** (official Prometheus Community Helm Chart) deployed via ArgoCD.

## 📦 Official Chart Information

- **Chart**: kube-prometheus-stack
- **Version**: 65.2.0
- **Repository**: <https://prometheus-community.github.io/helm-charts>
- **Source Code**: <https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack>
- **ArtifactHub**: <https://artifacthub.io/packages/helm/prometheus-community/kube-prometheus-stack>
- **License**: Apache 2.0
- **Maintained by**: Prometheus Community

### Official Documentation

- **Prometheus**: <https://prometheus.io/docs/>
- **Grafana**: <https://grafana.com/docs/>
- **AlertManager**: <https://prometheus.io/docs/alerting/latest/alertmanager/>
- **Prometheus Operator**: <https://prometheus-operator.dev/>

## 📦 What's Included

**kube-prometheus-stack** includes:

- **Prometheus Server** - Metrics collection & storage
- **Grafana** - Visualization dashboards
- **AlertManager** - Alert routing & notification
- **Node Exporter** - Host/node metrics
- **Kube State Metrics** - Kubernetes object metrics
- **Prometheus Operator** - CRD-based management

## 📁 Structure

```
argocd/
├── system-apps-kustomize/
│   └── prometheus/
│       ├── base/
│       │   ├── application.yaml       # Base ArgoCD Application
│       │   └── kustomization.yaml
│       └── overlays/
│           ├── dev/                   # Dev environment
│           ├── staging/               # Staging environment
│           └── prod/                  # Production environment
└── helm-values/
    └── prometheus/
        ├── dev-values.yaml            # Dev configuration
        ├── staging-values.yaml        # Staging configuration
        └── prod-values.yaml           # Production configuration
```

## 🚀 Quick Start

### Deploy Dev Environment

```bash
# Deploy via app-of-apps (includes Metrics Server + Prometheus)
kubectl apply -f argocd/app-of-apps-kustomize-dev.yaml

# Or deploy Prometheus only
kubectl apply -k argocd/system-apps-kustomize/prometheus/overlays/dev

# Wait for deployment
kubectl get pods -n monitoring
```

### Access Grafana

```bash
# Port-forward to Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Open browser
open http://localhost:3000

# Login credentials (dev)
Username: admin
Password: admin123  # CHANGE IN PRODUCTION!
```

### Access Prometheus UI

```bash
# Port-forward to Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Open browser
open http://localhost:9090
```

### Access AlertManager

```bash
# Port-forward to AlertManager
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-alertmanager 9093:9093

# Open browser
open http://localhost:9093
```

## 🎯 Environment Configurations

### Dev Environment

```yaml
Prometheus:
  - Retention: 7 days
  - Storage: 20GB
  - Replicas: 1
  - Resources: Low (200m CPU, 1Gi RAM)
  - Scrape: 30s

Grafana:
  - Storage: 5GB
  - Replicas: 1
  - Access: Port-forward only
  - Password: admin123

AlertManager:
  - Replicas: 1
  - Alerts: Disabled (dev testing)
```

### Staging Environment

```yaml
Prometheus:
  - Retention: 15 days
  - Storage: 50GB
  - Replicas: 2 (HA)
  - Resources: Medium (500m CPU, 2Gi RAM)
  - Scrape: 30s

Grafana:
  - Storage: 10GB
  - Replicas: 2 (HA)
  - Ingress: Optional (ALB)
  - Alerts: Slack notifications

AlertManager:
  - Replicas: 2 (HA)
  - Alerts: Slack (#staging-alerts)
```

### Production Environment

```yaml
Prometheus:
  - Retention: 30 days
  - Storage: 100GB
  - Replicas: 3 (HA + anti-affinity)
  - Resources: High (1 CPU, 4Gi RAM)
  - Scrape: 15s (more frequent)

Grafana:
  - Storage: 20GB
  - Replicas: 3 (HA + anti-affinity)
  - Ingress: ALB with SSL (grafana.example.com)
  - Alerts: Slack + PagerDuty

AlertManager:
  - Replicas: 3 (HA + anti-affinity)
  - Alerts: Slack + PagerDuty (critical)
  - PDB: maxUnavailable=1
```

## 📊 Default Dashboards

Grafana comes with pre-configured dashboards:

1. **Kubernetes / Compute Resources / Cluster** - Overall cluster resources
2. **Kubernetes / Compute Resources / Namespace (Pods)** - Per-namespace metrics
3. **Kubernetes / Compute Resources / Node (Pods)** - Per-node metrics
4. **Kubernetes / Compute Resources / Pod** - Individual pod metrics
5. **Kubernetes / Networking / Cluster** - Network traffic
6. **Node Exporter / Nodes** - Node hardware metrics
7. **Prometheus / Overview** - Prometheus server stats

## 🔍 Common Queries

### Pod CPU Usage

```promql
rate(container_cpu_usage_seconds_total{pod="my-pod"}[5m])
```

### Pod Memory Usage

```promql
container_memory_usage_bytes{pod="my-pod"}
```

### HTTP Request Rate

```promql
rate(http_requests_total[5m])
```

### Pod Restart Count

```promql
kube_pod_container_status_restarts_total
```

## 🔧 Customization

### Add Custom ServiceMonitor

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-app
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: my-app
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
```

### Add Custom Alert Rules

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: my-app-alerts
  namespace: monitoring
spec:
  groups:
  - name: my-app
    interval: 30s
    rules:
    - alert: HighErrorRate
      expr: rate(http_requests_total{status="500"}[5m]) > 0.05
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "High error rate detected"
        description: "Error rate is {{ $value }}"
```

### Configure Slack Alerts

Edit `helm-values/prometheus/<env>-values.yaml`:

```yaml
alertmanager:
  config:
    global:
      slack_api_url: "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
    receivers:
      - name: 'slack-notifications'
        slack_configs:
          - channel: '#alerts'
            title: 'Prometheus Alert'
```

## 🔐 Security Best Practices

### 1. Change Default Passwords

```bash
# Generate strong password
PASSWORD=$(openssl rand -base64 32)

# Update values file
grafana:
  adminPassword: "${PASSWORD}"
```

### 2. Use Sealed Secrets (Recommended)

```bash
# Create secret
kubectl create secret generic grafana-admin \
  --from-literal=admin-password=STRONG_PASSWORD \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > sealed-secret.yaml

# Reference in values
grafana:
  admin:
    existingSecret: grafana-admin
    userKey: admin-user
    passwordKey: admin-password
```

### 3. Enable HTTPS with ALB

```yaml
grafana:
  ingress:
    enabled: true
    annotations:
      alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:..."
      alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS": 443}]'
```

## 📈 Storage Costs

| Environment | Prometheus | Grafana | Total | Monthly Cost (gp3) |
|-------------|------------|---------|-------|-------------------|
| Dev | 20GB | 5GB | 25GB | ~$2.50 |
| Staging | 50GB | 10GB | 60GB | ~$6.00 |
| Prod | 100GB | 20GB | 120GB | ~$12.00 |

*Prices based on AWS EBS gp3 at $0.10/GB/month*

## 🔄 Upgrade

```bash
# Check current version
helm list -n monitoring

# Update chart version in base/application.yaml
targetRevision: 65.2.0  # Update this

# Commit and push
git add argocd/
git commit -m "chore: Upgrade kube-prometheus-stack to 65.2.0"
git push

# ArgoCD will auto-sync
```

## 🆘 Troubleshooting

### Prometheus Pod Not Starting

```bash
# Check logs
kubectl logs -n monitoring prometheus-prometheus-kube-prometheus-prometheus-0

# Common issues:
# - Insufficient PVC storage
# - Invalid scrape configs
# - RBAC permissions
```

### Grafana Login Issues

```bash
# Reset admin password
kubectl exec -n monitoring prometheus-grafana-0 -- grafana-cli admin reset-admin-password NEW_PASSWORD
```

### AlertManager Not Sending Alerts

```bash
# Check AlertManager config
kubectl get secret -n monitoring alertmanager-prometheus-kube-prometheus-alertmanager -o yaml

# Test Slack webhook
curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"Test from AlertManager"}' \
  YOUR_SLACK_WEBHOOK_URL
```

### High Memory Usage

```bash
# Reduce retention or scrape interval
prometheus:
  prometheusSpec:
    retention: 7d  # Reduce from 30d
    scrapeInterval: 60s  # Increase from 15s
```

## 📚 References

- [kube-prometheus-stack Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [AlertManager Configuration](https://prometheus.io/docs/alerting/latest/configuration/)
- [PromQL Query Language](https://prometheus.io/docs/prometheus/latest/querying/basics/)
