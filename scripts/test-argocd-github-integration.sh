#!/bin/bash
# ============================================
# Test ArgoCD GitHub Workflow Integration
# ============================================
# This script tests ArgoCD configuration for GitHub Actions workflow
# Usage: bash test-argocd-github-integration.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
ARGOCD_SERVER="${ARGOCD_SERVER:-argocd.yourdomain.com}"
ARGOCD_AUTH_TOKEN="${ARGOCD_AUTH_TOKEN}"
GITOPS_REPO="https://github.com/TomJennyDev/flowise-gitops.git"

echo "============================================"
echo "🔍 Testing ArgoCD GitHub Workflow Integration"
echo "============================================"
echo ""

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✅ $2${NC}"
    else
        echo -e "${RED}❌ $2${NC}"
        exit 1
    fi
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Check if argocd CLI is installed
echo "1. Checking ArgoCD CLI..."
if command -v argocd &> /dev/null; then
    print_status 0 "ArgoCD CLI is installed"
    argocd version --client
else
    print_status 1 "ArgoCD CLI is not installed. Please install: https://argo-cd.readthedocs.io/en/stable/cli_installation/"
fi
echo ""

# Check environment variables
echo "2. Checking environment variables..."
if [ -z "$ARGOCD_SERVER" ]; then
    print_warning "ARGOCD_SERVER is not set"
    read -p "Enter ArgoCD server URL (e.g., argocd.yourdomain.com): " ARGOCD_SERVER
fi

if [ -z "$ARGOCD_AUTH_TOKEN" ]; then
    print_warning "ARGOCD_AUTH_TOKEN is not set"
    read -sp "Enter ArgoCD auth token: " ARGOCD_AUTH_TOKEN
    echo ""
fi
echo ""

# Test ArgoCD connectivity
echo "3. Testing ArgoCD connectivity..."
if curl -k -s -o /dev/null -w "%{http_code}" "https://${ARGOCD_SERVER}/healthz" | grep -q "200"; then
    print_status 0 "ArgoCD server is reachable"
else
    print_status 1 "Cannot reach ArgoCD server"
fi
echo ""

# Login to ArgoCD
echo "4. Testing ArgoCD login..."
if argocd login "${ARGOCD_SERVER}" \
    --auth-token "${ARGOCD_AUTH_TOKEN}" \
    --grpc-web \
    --insecure &> /dev/null; then
    print_status 0 "Successfully logged in to ArgoCD"
else
    print_status 1 "Failed to login to ArgoCD"
fi
echo ""

# Check GitOps repository
echo "5. Checking GitOps repository..."
if argocd repo list | grep -q "${GITOPS_REPO}"; then
    print_status 0 "GitOps repository is configured"
    argocd repo get "${GITOPS_REPO}"
else
    print_warning "GitOps repository not found"
    echo "   Add it with: argocd repo add ${GITOPS_REPO}"
fi
echo ""

# Check applications
echo "6. Checking ArgoCD applications..."
APPS=("flowise-dev" "flowise-staging" "flowise-production")
for app in "${APPS[@]}"; do
    if argocd app list | grep -q "${app}"; then
        echo -e "${GREEN}✅ Application '${app}' exists${NC}"
        
        # Get app status
        STATUS=$(argocd app get "${app}" --output json | jq -r '.status.sync.status')
        HEALTH=$(argocd app get "${app}" --output json | jq -r '.status.health.status')
        
        echo "   Sync Status: ${STATUS}"
        echo "   Health Status: ${HEALTH}"
    else
        echo -e "${YELLOW}⚠️  Application '${app}' not found${NC}"
    fi
done
echo ""

# Test sync operation (dry-run)
echo "7. Testing sync operation (dry-run)..."
if argocd app list | grep -q "flowise-dev"; then
    if argocd app sync flowise-dev --dry-run &> /dev/null; then
        print_status 0 "Dry-run sync successful"
    else
        print_warning "Dry-run sync failed (this might be expected if app doesn't exist yet)"
    fi
else
    print_warning "Cannot test sync - flowise-dev application not found"
fi
echo ""

# Check RBAC permissions
echo "8. Checking RBAC permissions..."
if argocd account can-i sync applications '*/*'; then
    print_status 0 "Account has sync permissions"
else
    print_warning "Account may not have sync permissions"
fi

if argocd account can-i get applications '*/*'; then
    print_status 0 "Account has get permissions"
else
    print_warning "Account may not have get permissions"
fi
echo ""

# Test refresh operation
echo "9. Testing refresh operation..."
if argocd app list | grep -q "flowise-dev"; then
    if argocd app get flowise-dev --refresh &> /dev/null; then
        print_status 0 "Refresh operation successful"
    else
        print_warning "Refresh operation failed"
    fi
else
    print_warning "Cannot test refresh - flowise-dev application not found"
fi
echo ""

# Check ArgoCD server settings
echo "10. Checking ArgoCD server configuration..."
echo "    Checking if gRPC-web is enabled..."
if kubectl get configmap argocd-cmd-params-cm -n argocd -o yaml 2>/dev/null | grep -q "server.enable.gzip"; then
    print_status 0 "gRPC compression is configured"
else
    print_warning "gRPC compression may not be configured"
fi
echo ""

# Summary
echo "============================================"
echo "📊 Test Summary"
echo "============================================"
echo ""
echo "ArgoCD Server: ${ARGOCD_SERVER}"
echo "GitOps Repo: ${GITOPS_REPO}"
echo ""
echo "Next steps for GitHub Actions setup:"
echo "1. Add ARGOCD_SERVER to GitHub Secrets"
echo "2. Add ARGOCD_AUTH_TOKEN to GitHub Secrets"
echo "3. Ensure GitOps repository is added to ArgoCD"
echo "4. Create ArgoCD applications for each environment"
echo "5. Test workflow by pushing to main branch"
echo ""
echo "GitHub Secrets required:"
echo "  - ARGOCD_SERVER=${ARGOCD_SERVER}"
echo "  - ARGOCD_AUTH_TOKEN=<your-token>"
echo "  - GITOPS_TOKEN=<github-pat>"
echo "  - AWS_ACCESS_KEY_ID=<aws-key>"
echo "  - AWS_SECRET_ACCESS_KEY=<aws-secret>"
echo ""
echo -e "${GREEN}✅ Test completed!${NC}"
