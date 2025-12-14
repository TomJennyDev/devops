# ArgoCD Secrets Directory

This directory contains sensitive credentials for ArgoCD access in the **dev** environment.

## 🔒 Security Notice

**⚠️ IMPORTANT:** This directory contains sensitive information and is git-ignored by default. Never commit these files to version control.

## 📁 Files

### 1. `argocd-credentials.env`
Full credentials file with export statements for shell usage.

**Usage:**
```bash
source environments/dev/secrets/argocd-credentials.env
# Now you can use $ARGOCD_SERVER and $ARGOCD_AUTH_TOKEN
```

### 2. `argocd-token.txt`
Auth token only - useful for scripts and CI/CD pipelines.

**Usage:**
```bash
TOKEN=$(cat environments/dev/secrets/argocd-token.txt)
curl -H "Authorization: Bearer $TOKEN" https://argocd.do2506.click/api/v1/applications
```

### 3. `argocd-server.txt`
Server URL only - useful for scripts and configuration.

**Usage:**
```bash
SERVER=$(cat environments/dev/secrets/argocd-server.txt)
echo "ArgoCD server: $SERVER"
```

## 🔄 Regenerating Credentials

To regenerate the credentials (e.g., after token expiration or rotation):

```bash
cd scripts
bash get-argocd-token.sh
```

This will:
1. Fetch the current ArgoCD server URL from Kubernetes
2. Retrieve the admin password from the cluster
3. Generate a new auth token via API
4. Save all credentials to this directory
5. Create/update `.gitignore` to protect secrets

## 🛠️ Using with ArgoCD CLI

```bash
# Load credentials
source environments/dev/secrets/argocd-credentials.env

# List applications
argocd app list --insecure

# Get application details
argocd app get <app-name> --insecure

# Sync application
argocd app sync <app-name> --insecure
```

## 🔗 Using with API (curl)

```bash
# Load credentials
source environments/dev/secrets/argocd-credentials.env

# List applications
curl -sk -H "Authorization: Bearer $ARGOCD_AUTH_TOKEN" \
  https://$ARGOCD_SERVER/api/v1/applications

# Get application status
curl -sk -H "Authorization: Bearer $ARGOCD_AUTH_TOKEN" \
  https://$ARGOCD_SERVER/api/v1/applications/<app-name>

# Sync application
curl -sk -X POST -H "Authorization: Bearer $ARGOCD_AUTH_TOKEN" \
  https://$ARGOCD_SERVER/api/v1/applications/<app-name>/sync
```

## 🚀 Using with GitHub Actions

Add these as repository secrets:

```yaml
# .github/workflows/deploy.yml
env:
  ARGOCD_SERVER: ${{ secrets.ARGOCD_SERVER }}
  ARGOCD_AUTH_TOKEN: ${{ secrets.ARGOCD_AUTH_TOKEN }}

steps:
  - name: Sync ArgoCD Application
    run: |
      curl -sk -X POST \
        -H "Authorization: Bearer $ARGOCD_AUTH_TOKEN" \
        https://$ARGOCD_SERVER/api/v1/applications/my-app/sync
```

**To get values for GitHub secrets:**
```bash
cat environments/dev/secrets/argocd-server.txt     # Copy to ARGOCD_SERVER
cat environments/dev/secrets/argocd-token.txt      # Copy to ARGOCD_AUTH_TOKEN
```

## 🔐 Security Best Practices

1. **Never commit:** Files in this directory are git-ignored. Keep it that way.
2. **Rotate regularly:** Generate new tokens periodically for security.
3. **Limit access:** Use file permissions (chmod 600) to restrict access.
4. **Use service accounts:** For production, create dedicated service accounts with limited permissions.
5. **Token expiration:** Consider setting token expiration for better security.
6. **Secrets management:** For production environments, use proper secrets management (AWS Secrets Manager, HashiCorp Vault, etc.).

## 📚 Additional Resources

- [ArgoCD API Documentation](https://argo-cd.readthedocs.io/en/stable/developer-guide/api-docs/)
- [ArgoCD CLI Documentation](https://argo-cd.readthedocs.io/en/stable/user-guide/commands/argocd/)
- [ArgoCD RBAC](https://argo-cd.readthedocs.io/en/stable/operator-manual/rbac/)

## 🆘 Troubleshooting

### Token expired or invalid
```bash
# Regenerate token
cd scripts && bash get-argocd-token.sh
```

### Cannot access ArgoCD API
```bash
# Test connectivity
curl -sk https://argocd.do2506.click/api/version

# Check if server is reachable
kubectl get pods -n argocd
kubectl get ingress -n argocd
```

### Permission denied errors
```bash
# Verify file permissions
ls -la environments/dev/secrets/

# Fix permissions if needed
chmod 600 environments/dev/secrets/argocd-*.txt
chmod 600 environments/dev/secrets/argocd-*.env
```
