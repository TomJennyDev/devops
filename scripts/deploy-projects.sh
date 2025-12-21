#!/bin/bash
# ========================================
# DEPLOY ARGOCD PROJECTS (RBAC)
# ========================================
# This script deploys ArgoCD Projects for RBAC
# Must be run after ArgoCD is deployed
# ========================================
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory and paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECTS_DIR="$PROJECT_ROOT/argocd/projects"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}🔐 DEPLOY ARGOCD PROJECTS (RBAC)${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# ========================================
# STEP 1: VERIFY PREREQUISITES
# ========================================
echo -e "${YELLOW}📋 Step 1: Verifying prerequisites...${NC}"

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl not found${NC}"
    exit 1
fi
echo -e "${GREEN}✅ kubectl installed${NC}"

# Check cluster access
if ! kubectl get nodes &> /dev/null; then
    echo -e "${RED}❌ Cannot access cluster${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Cluster access verified${NC}"

# Check if ArgoCD is installed
if ! kubectl get namespace argocd &> /dev/null; then
    echo -e "${RED}❌ ArgoCD namespace not found${NC}"
    echo -e "${YELLOW}Run: bash scripts/deploy-argocd.sh first${NC}"
    exit 1
fi
echo -e "${GREEN}✅ ArgoCD namespace exists${NC}"

# Check if ArgoCD CRDs are installed
if ! kubectl get crd appprojects.argoproj.io &> /dev/null; then
    echo -e "${RED}❌ ArgoCD CRDs not found${NC}"
    echo -e "${YELLOW}ArgoCD must be fully deployed first${NC}"
    exit 1
fi
echo -e "${GREEN}✅ ArgoCD CRDs installed${NC}"

echo ""

# ========================================
# STEP 2: DEPLOY PROJECTS
# ========================================
echo -e "${YELLOW}📋 Step 2: Deploying ArgoCD Projects...${NC}"

# Deploy infrastructure project
echo ""
echo "Deploying Infrastructure Project..."
if kubectl apply -f "$PROJECTS_DIR/infrastructure.yaml"; then
    echo -e "${GREEN}✅ Infrastructure project deployed${NC}"
else
    echo -e "${RED}❌ Failed to deploy infrastructure project${NC}"
    exit 1
fi

# Deploy applications project
echo ""
echo "Deploying Applications Project..."
if kubectl apply -f "$PROJECTS_DIR/applications.yaml"; then
    echo -e "${GREEN}✅ Applications project deployed${NC}"
else
    echo -e "${RED}❌ Failed to deploy applications project${NC}"
    exit 1
fi

echo ""

# ========================================
# STEP 3: VERIFY DEPLOYMENT
# ========================================
echo -e "${YELLOW}📋 Step 3: Verifying deployment...${NC}"

echo ""
echo "Waiting for projects to be ready..."
sleep 3

# List all projects
echo ""
echo -e "${BLUE}Deployed Projects:${NC}"
kubectl get appprojects -n argocd

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✅ ARGOCD PROJECTS DEPLOYED!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
 
# Get project details
echo -e "${YELLOW}📝 Project Details:${NC}"
echo ""

echo "1️⃣  ${BLUE}Infrastructure Project:${NC}"
echo "   • Manages: ALB Controller, Prometheus, System Components"
echo "   • Roles: infrastructure-admin, infrastructure-readonly"
echo "   • Cluster Resources: Allowed"
echo ""

echo "2️⃣  ${BLUE}Applications Project:${NC}"
echo "   • Manages: Flowise, Business Applications"
echo "   • Roles: app-admin, app-developer, app-readonly"
echo "   • Namespaces: flowise-*, app-*, default"
echo "   • Resources: Namespace-scoped only"
echo ""

echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}📝 Next Steps:${NC}"
echo ""
echo "1️⃣  ${YELLOW}Deploy Infrastructure App-of-Apps:${NC}"
echo "   kubectl apply -f argocd/bootstrap/infrastructure-apps-dev.yaml"
echo ""
echo "2️⃣  ${YELLOW}Deploy Business Applications:${NC}"
echo "   kubectl apply -f argocd/bootstrap/flowise-dev.yaml"
echo ""
echo "3️⃣  ${YELLOW}Verify applications:${NC}"
echo "   kubectl get applications -n argocd"
echo "   argocd app list"
echo ""
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN}✅ Setup complete!${NC}"
echo ""
