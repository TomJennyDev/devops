# ArgoCD System Apps - Sources & References

## 📚 Official Documentation & Standards

All files in this repository follow official specifications and best practices from:

### 1. **ArgoCD Applications**
- **Official Documentation**: https://argo-cd.readthedocs.io/en/stable/
- **Application Spec**: https://argo-cd.readthedocs.io/en/stable/user-guide/application-specification/
- **CRD Definition**: https://github.com/argoproj/argo-cd/blob/master/manifests/crds/application-crd.yaml
- **API Reference**: https://argo-cd.readthedocs.io/en/stable/operator-manual/
- **Examples**: https://github.com/argoproj/argocd-example-apps
- **App of Apps Pattern**: https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/
- **Maintainer**: Argo Project (CNCF)
- **License**: Apache 2.0

### 2. **Kustomize**
- **Official Docs**: https://kubectl.docs.kubernetes.io/references/kustomize/
- **Kustomization API**: https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/
- **GitHub**: https://github.com/kubernetes-sigs/kustomize
- **Kubernetes Docs**: https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/
- **Patches Reference**: https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/patches/
- **Maintainer**: Kubernetes SIG CLI
- **License**: Apache 2.0

### 3. **JSON Patch (for Kustomize patches)**
- **RFC 6902**: https://tools.ietf.org/html/rfc6902
- **JSON Pointer (RFC 6901)**: https://tools.ietf.org/html/rfc6901
- **Standard**: IETF Internet Standard

### 4. **Prometheus Stack (Helm Chart)**
- **Chart Repository**: https://github.com/prometheus-community/helm-charts
- **Chart Location**: https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack
- **Helm Repository**: https://prometheus-community.github.io/helm-charts
- **ArtifactHub**: https://artifacthub.io/packages/helm/prometheus-community/kube-prometheus-stack
- **Chart Version**: 65.2.0
- **Maintainer**: Prometheus Community
- **License**: Apache 2.0

#### Component Documentation:
- **Prometheus**: https://prometheus.io/docs/
- **Grafana**: https://grafana.com/docs/grafana/latest/
- **AlertManager**: https://prometheus.io/docs/alerting/latest/alertmanager/
- **Prometheus Operator**: https://prometheus-operator.dev/
- **Node Exporter**: https://github.com/prometheus/node_exporter
- **Kube State Metrics**: https://github.com/kubernetes/kube-state-metrics

### 5. **Helm**
- **Official Docs**: https://helm.sh/docs/
- **Values Files**: https://helm.sh/docs/chart_template_guide/values_files/
- **Chart Development**: https://helm.sh/docs/chart_template_guide/
- **Best Practices**: https://helm.sh/docs/chart_best_practices/
- **Maintainer**: CNCF
- **License**: Apache 2.0

### 6. **Kubernetes**
- **Official Docs**: https://kubernetes.io/docs/
- **API Reference**: https://kubernetes.io/docs/reference/kubernetes-api/
- **Custom Resources**: https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/

## 🎯 Design Patterns Used

### 1. **App of Apps Pattern**
**Source**: https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/

The "App of Apps" pattern allows managing multiple ArgoCD Applications as a single Application. This is the recommended approach for cluster bootstrapping.

**Files implementing this pattern:**
- `app-of-apps-kustomize-dev.yaml`
- `app-of-apps-kustomize-staging.yaml`
- `app-of-apps-kustomize-prod.yaml`

### 2. **Kustomize Overlays Pattern**
**Source**: https://kubectl.docs.kubernetes.io/references/kustomize/glossary/#overlay

Base + Overlays pattern for managing environment-specific configurations.

**Structure:**
```
base/          # Common configuration
overlays/
  dev/         # Dev-specific overrides
  staging/     # Staging-specific overrides
  prod/        # Production-specific overrides
```

### 3. **GitOps Pattern**
**Source**: https://www.gitops.tech/

Git as single source of truth for declarative infrastructure and applications.

### 4. **Helm with Separate Values**
**Source**: https://helm.sh/docs/chart_template_guide/values_files/

Separating Helm values into environment-specific files for better maintainability.

## 📋 File Format Specifications

### ArgoCD Application YAML
```yaml
# API Version: argoproj.io/v1alpha1
# Kind: Application
# Spec: https://argo-cd.readthedocs.io/en/stable/user-guide/application-specification/

apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: string
  namespace: argocd
spec:
  project: string
  source: {...}        # Single source
  sources: [{...}]     # Multiple sources (ArgoCD 2.6+)
  destination: {...}
  syncPolicy: {...}
```

### Kustomization YAML
```yaml
# API Version: kustomize.config.k8s.io/v1beta1
# Kind: Kustomization
# Spec: https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/

apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: string
resources: []string
patches: []Patch
```

### JSON Patch Format
```yaml
# RFC 6902: https://tools.ietf.org/html/rfc6902
# Operations: add, remove, replace, move, copy, test

patches:
  - target:
      kind: string
      name: string
    patch: |-
      - op: replace
        path: /spec/replicas
        value: 3
```

## ✅ Validation & Testing

### Validate ArgoCD Application
```bash
# Using kubectl
kubectl apply --dry-run=client -f app-of-apps-kustomize-dev.yaml

# Using ArgoCD CLI
argocd app create --file app-of-apps-kustomize-dev.yaml --dry-run
```

### Validate Kustomize
```bash
# Build and validate
kubectl kustomize argocd/system-apps-kustomize/prometheus/overlays/dev

# Apply with dry-run
kubectl apply --dry-run=server -k argocd/system-apps-kustomize/prometheus/overlays/dev
```

### Validate Helm Values
```bash
# Template with values
helm template prometheus prometheus-community/kube-prometheus-stack \
  -f argocd/helm-values/prometheus/dev-values.yaml \
  --validate

# Lint values
helm lint prometheus-community/kube-prometheus-stack \
  -f argocd/helm-values/prometheus/dev-values.yaml
```

### YAML Syntax Validation
```bash
# Using yamllint
yamllint argocd/

# Using kubectl
kubectl apply --dry-run=client -f <file>
```

## 📖 Additional References

### Best Practices
- **ArgoCD Best Practices**: https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/
- **Kustomize Best Practices**: https://kubectl.docs.kubernetes.io/guides/
- **Helm Best Practices**: https://helm.sh/docs/chart_best_practices/
- **Kubernetes Best Practices**: https://kubernetes.io/docs/concepts/configuration/overview/

### Community Examples
- **ArgoCD Examples**: https://github.com/argoproj/argocd-example-apps
- **Kustomize Examples**: https://github.com/kubernetes-sigs/kustomize/tree/master/examples
- **Prometheus Stack Examples**: https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack/examples

## 🔄 Version Information

| Component | Version | Release Date | Notes |
|-----------|---------|--------------|-------|
| **ArgoCD API** | v1alpha1 | Stable | CRD version |
| **Kustomize API** | v1beta1 | Stable | Current stable |
| **kube-prometheus-stack** | 65.2.0 | 2024 | Chart version |
| **Prometheus** | 2.x | Latest | Included in stack |
| **Grafana** | 10.x | Latest | Included in stack |

## 📝 License

All configurations are based on open-source projects:
- **ArgoCD**: Apache 2.0
- **Kustomize**: Apache 2.0
- **Helm**: Apache 2.0
- **Prometheus**: Apache 2.0
- **Grafana**: AGPL 3.0

This repository's configurations: MIT License (or your chosen license)

## 🆘 Support & Issues

For issues with:
- **ArgoCD**: https://github.com/argoproj/argo-cd/issues
- **Kustomize**: https://github.com/kubernetes-sigs/kustomize/issues
- **Prometheus Stack**: https://github.com/prometheus-community/helm-charts/issues
- **Helm**: https://github.com/helm/helm/issues

---

**Last Updated**: 2025-11-25
**Maintained by**: DevOps Team
