#!/bin/bash
# ============================================
# Install ArgoCD on EKS Cluster
# ============================================
# Usage: bash scripts/install-argocd.sh [environment]
# Example: bash scripts/install-argocd.sh dev

set -e

ENVIRONMENT=${1:-dev}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "============================================"
echo "Installing ArgoCD for $ENVIRONMENT environment"
echo "============================================"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if kubectl is configured
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${YELLOW}⚠️  kubectl not configured. Please run:${NC}"
    echo "aws eks update-kubeconfig --region ap-southeast-1 --name my-eks-$ENVIRONMENT"
    exit 1
fi

echo -e "${GREEN}✓ kubectl configured${NC}"

# Step 1: Create ArgoCD namespace (if not exists)
if kubectl get namespace argocd &> /dev/null; then
    echo -e "${GREEN}✓ ArgoCD namespace already exists${NC}"
else
    echo "Creating ArgoCD namespace..."
    kubectl create namespace argocd
    echo -e "${GREEN}✓ Created ArgoCD namespace${NC}"
fi

# Step 2: Install ArgoCD
echo ""
echo "Installing ArgoCD..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Step 3: Wait for ArgoCD pods to be ready
echo ""
echo "Waiting for ArgoCD pods to be ready (this may take 2-3 minutes)..."
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=5m

echo -e "${GREEN}✓ ArgoCD installed successfully${NC}"

# Step 4: Get admin password
echo ""
echo "============================================"
echo "ArgoCD Access Information"
echo "============================================"
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

echo ""
echo -e "${GREEN}Username:${NC} admin"
echo -e "${GREEN}Password:${NC} $ARGOCD_PASSWORD"
echo ""
echo -e "${YELLOW}⚠️  Save this password! It will not be shown again.${NC}"

# Step 5: Port forward instructions
echo ""
echo "============================================"
echo "Access ArgoCD UI"
echo "============================================"
echo ""
echo "Run this command in a separate terminal:"
echo -e "${GREEN}kubectl port-forward svc/argocd-server -n argocd 8080:443${NC}"
echo ""
echo "Then open: https://localhost:8080"
echo ""
echo "Or expose via LoadBalancer:"
echo -e "${GREEN}kubectl patch svc argocd-server -n argocd -p '{\"spec\": {\"type\": \"LoadBalancer\"}}'${NC}"
echo ""

# Step 6: Install ArgoCD CLI (optional)
echo "============================================"
echo "Optional: Install ArgoCD CLI"
echo "============================================"
echo ""
echo "Windows (PowerShell):"
echo "  choco install argocd-cli"
echo ""
echo "Linux:"
echo "  curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64"
echo "  sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd"
echo ""
echo "macOS:"
echo "  brew install argocd"
echo ""

# Step 7: Next steps
echo "============================================"
echo "Next Steps"
echo "============================================"
echo ""
echo "1. Access ArgoCD UI (port-forward or LoadBalancer)"
echo "2. Login with admin credentials above"
echo "3. Deploy system applications:"
echo -e "   ${GREEN}kubectl apply -f argocd/app-of-apps.yaml${NC}"
echo ""
echo "   This will automatically install:"
echo "   - AWS Load Balancer Controller"
echo "   - Metrics Server"
echo "   - External DNS (if enabled)"
echo ""

echo -e "${GREEN}✓ Setup complete!${NC}"
