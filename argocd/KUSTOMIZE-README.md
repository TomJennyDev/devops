# ArgoCD with Kustomize - Multi-Environment Setup

## Structure

```
argocd/
├── app-of-apps-kustomize-dev.yaml
├── app-of-apps-kustomize-staging.yaml
├── app-of-apps-kustomize-prod.yaml
└── system-apps-kustomize/
    ├── aws-load-balancer-controller/
    │   ├── base/
    │   │   ├── application.yaml        # Base template
    │   │   └── kustomization.yaml
    │   └── overlays/
    │       ├── dev/
    │       │   └── kustomization.yaml  # Dev-specific values
    │       ├── staging/
    │       │   └── kustomization.yaml  # Staging-specific values
    │       └── prod/
    │           └── kustomization.yaml  # Prod-specific values
    └── metrics-server/
        ├── base/
        │   ├── application.yaml
        │   └── kustomization.yaml
        └── overlays/
            ├── dev/
            ├── staging/
            └── prod/
```

## Kustomize Benefits

### ✅ DRY Principle
- Base configuration written once
- Overlays only contain environment-specific differences
- Easy to maintain and update

### ✅ Type Safety
- Kustomize validates patches at build time
- Catches configuration errors early

### ✅ Clear Environment Differences
- Easy to compare what's different between environments
- Patches clearly show what's being changed

## Usage

### Test Kustomize Build Locally

```bash
# Preview dev environment
kubectl kustomize argocd/system-apps-kustomize/aws-load-balancer-controller/overlays/dev

# Preview staging environment
kubectl kustomize argocd/system-apps-kustomize/aws-load-balancer-controller/overlays/staging

# Preview prod environment
kubectl kustomize argocd/system-apps-kustomize/aws-load-balancer-controller/overlays/prod
```

### Deploy via ArgoCD

```bash
# Deploy dev (automatic sync)
kubectl apply -f argocd/app-of-apps-kustomize-dev.yaml

# Deploy staging (automatic sync)
kubectl apply -f argocd/app-of-apps-kustomize-staging.yaml

# Deploy prod (manual sync required)
kubectl apply -f argocd/app-of-apps-kustomize-prod.yaml
# Then manually sync in ArgoCD UI
```

## Environment Comparison

| Environment | Replicas | CPU Request | Memory Request | Sync Policy |
|-------------|----------|-------------|----------------|-------------|
| **Dev** | 1 | 50m | 150Mi | Auto |
| **Staging** | 2 | 100m | 200Mi | Auto |
| **Prod** | 3 | 200m | 500Mi | Manual |

## Adding New Application

1. Create base configuration:
```bash
mkdir -p argocd/system-apps-kustomize/my-app/base
mkdir -p argocd/system-apps-kustomize/my-app/overlays/{dev,staging,prod}
```

2. Create `base/application.yaml` with placeholders

3. Create `base/kustomization.yaml`:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - application.yaml
```

4. Create overlay kustomization files with patches

5. Update app-of-apps files to include new application

## Kustomize Patches

### Strategic Merge Patch (Simple)
```yaml
patches:
  - path: patch.yaml
```

### JSON Patch (Precise)
```yaml
patches:
  - target:
      kind: Application
      name: my-app
    patch: |-
      - op: replace
        path: /spec/source/helm/values
        value: |
          replicaCount: 3
```

## Best Practices

1. **Keep base minimal** - Only common configuration
2. **Use patches for differences** - Environment-specific changes only
3. **Test locally** - Use `kubectl kustomize` before deploying
4. **Version control** - Commit all changes to Git
5. **Code review** - Review patches for prod carefully

## Troubleshooting

### Preview final manifest
```bash
kubectl kustomize argocd/system-apps-kustomize/aws-load-balancer-controller/overlays/dev | less
```

### Validate YAML
```bash
kubectl kustomize argocd/system-apps-kustomize/aws-load-balancer-controller/overlays/dev | kubectl apply --dry-run=client -f -
```

### Debug ArgoCD Application
```bash
# Get application status
kubectl get application -n argocd system-apps-dev-kustomize

# View details
kubectl describe application -n argocd system-apps-dev-kustomize

# View ArgoCD logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```
