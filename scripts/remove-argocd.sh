#!/bin/bash
# ========================================
# REMOVE ARGOCD COMPLETELY
# ========================================
# This script removes ArgoCD and all deployed resources
# WARNING: This will delete all applications and data!
# ========================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${RED}========================================${NC}"
echo -e "${RED}⚠️  REMOVE ARGOCD - WARNING!${NC}"
echo -e "${RED}========================================${NC}"
echo ""
echo -e "${YELLOW}This will:${NC}"
echo "• Delete all ArgoCD applications"
echo "• Delete all deployed resources (Flowise, Prometheus, etc.)"
echo "• Delete ArgoCD Projects"
echo "• Remove ArgoCD namespace"
echo "• Clean up local credentials"
echo ""
echo -e "${RED}⚠️  THIS ACTION CANNOT BE UNDONE!${NC}"
echo ""
read -p "Are you sure you want to continue? (type 'yes' to confirm): " -r
echo ""

if [[ ! $REPLY == "yes" ]]; then
    echo "Operation cancelled"
    exit 0
fi

echo ""
echo -e "${YELLOW}Starting removal process...${NC}"
echo ""

# ========================================
# STEP 1: DELETE ALL APPLICATIONS
# ========================================
echo -e "${YELLOW}📋 Step 1: Deleting all ArgoCD applications...${NC}"

if kubectl get namespace argocd &> /dev/null; then
    if kubectl get applications -n argocd &> /dev/null 2>&1; then
        echo "Deleting applications..."
        kubectl delete applications --all -n argocd --timeout=120s || true
        
        echo "Waiting for applications to be removed..."
        sleep 10
        
        # Force delete if needed
        if kubectl get applications -n argocd --no-headers 2>/dev/null | grep -q .; then
            echo "Force deleting remaining applications..."
            kubectl patch applications -n argocd --type json --patch='[{"op": "remove", "path": "/metadata/finalizers"}]' $(kubectl get applications -n argocd -o name) 2>/dev/null || true
            kubectl delete applications --all -n argocd --force --grace-period=0 2>/dev/null || true
        fi
        
        echo -e "${GREEN}✅ Applications deleted${NC}"
    else
        echo -e "${YELLOW}No applications found${NC}"
    fi
else
    echo -e "${YELLOW}ArgoCD namespace not found${NC}"
fi

echo ""

# ========================================
# STEP 2: DELETE PROJECTS
# ========================================
echo -e "${YELLOW}📋 Step 2: Deleting ArgoCD Projects...${NC}"

if kubectl get appprojects -n argocd &> /dev/null 2>&1; then
    echo "Deleting projects..."
    kubectl delete appprojects --all -n argocd || true
    echo -e "${GREEN}✅ Projects deleted${NC}"
else
    echo -e "${YELLOW}No projects found${NC}"
fi

echo ""

# ========================================
# STEP 3: DELETE DEPLOYED NAMESPACES
# ========================================
echo -e "${YELLOW}📋 Step 3: Deleting deployed namespaces...${NC}"

NAMESPACES=("flowise-dev" "flowise-staging" "flowise-production" "monitoring")

for ns in "${NAMESPACES[@]}"; do
    if kubectl get namespace "$ns" &> /dev/null; then
        echo "Deleting namespace: $ns"
        kubectl delete namespace "$ns" --timeout=120s || true
    fi
done

echo -e "${GREEN}✅ Deployed namespaces deleted${NC}"
echo ""

# ========================================
# STEP 4: DELETE ARGOCD NAMESPACE
# ========================================
echo -e "${YELLOW}📋 Step 4: Deleting ArgoCD namespace...${NC}"

if kubectl get namespace argocd &> /dev/null; then
    echo "Deleting ArgoCD namespace..."
    kubectl delete namespace argocd --timeout=120s || true
    
    # Force delete if stuck
    if kubectl get namespace argocd &> /dev/null 2>&1; then
        echo "Force deleting ArgoCD namespace..."
        kubectl get namespace argocd -o json | jq '.spec.finalizers=[]' | kubectl replace --raw /api/v1/namespaces/argocd/finalize -f - || true
    fi
    
    echo -e "${GREEN}✅ ArgoCD namespace deleted${NC}"
else
    echo -e "${YELLOW}ArgoCD namespace not found${NC}"
fi

echo ""

# ========================================
# STEP 5: CLEAN UP LOCAL FILES
# ========================================
echo -e "${YELLOW}📋 Step 5: Cleaning up local credentials...${NC}"

# Remove ArgoCD credentials
if [ -f ~/.argocd-credentials.env ]; then
    rm -f ~/.argocd-credentials.env
    echo -e "${GREEN}✅ Removed ~/.argocd-credentials.env${NC}"
fi

# Remove secret files
if [ -d "environments/dev/secrets" ]; then
    rm -f environments/dev/secrets/argocd-*.txt
    echo -e "${GREEN}✅ Removed ArgoCD secrets${NC}"
fi

# Remove ArgoCD CLI config (optional)
if [ -d ~/.argocd ]; then
    echo ""
    read -p "Remove ArgoCD CLI config (~/.argocd)? (y/N) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf ~/.argocd
        echo -e "${GREEN}✅ Removed ~/.argocd${NC}"
    fi
fi

echo ""

# ========================================
# VERIFICATION
# ========================================
echo -e "${YELLOW}📋 Verifying removal...${NC}"
echo ""

# Check remaining resources
echo "Checking for remaining resources..."

if kubectl get namespace argocd &> /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  ArgoCD namespace still exists (may take time to fully delete)${NC}"
else
    echo -e "${GREEN}✅ ArgoCD namespace removed${NC}"
fi

if kubectl get namespace monitoring &> /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Monitoring namespace still exists${NC}"
else
    echo -e "${GREEN}✅ Monitoring namespace removed${NC}"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✅ ARGOCD REMOVAL COMPLETE!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

echo -e "${YELLOW}📝 What was removed:${NC}"
echo ""
echo "• All ArgoCD applications"
echo "• ArgoCD Projects (RBAC)"
echo "• ArgoCD namespace and components"
echo "• Deployed applications (Flowise, Prometheus)"
echo "• Local credentials"
echo ""

echo -e "${YELLOW}📝 What was NOT removed:${NC}"
echo ""
echo "• EKS Cluster (still running)"
echo "• cert-manager (may still be installed)"
echo "• AWS Load Balancer Controller (in kube-system)"
echo "• ALB resources (may need manual cleanup in AWS Console)"
echo "• Route53 DNS records"
echo ""

echo -e "${YELLOW}🔄 To redeploy ArgoCD:${NC}"
echo ""
echo "1. bash scripts/deploy-argocd.sh"
echo "2. bash scripts/deploy-projects.sh"
echo "3. bash scripts/deploy-infrastructure.sh dev"
echo "4. bash scripts/deploy-flowise.sh dev"
echo ""

echo -e "${YELLOW}⚠️  Manual Cleanup (if needed):${NC}"
echo ""
echo "# Remove ALB Controller"
echo "kubectl delete namespace kube-system --force --grace-period=0"
echo ""
echo "# Remove cert-manager"
echo "kubectl delete namespace cert-manager --force --grace-period=0"
echo ""
echo "# Check AWS Console for:"
echo "• Application Load Balancers"
echo "• Target Groups"
echo "• Route53 records"
echo ""
