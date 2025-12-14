#!/bin/bash
# ========================================
# DEPLOY FLOWISE APPLICATION
# ========================================
# Deploy Flowise to specific environment
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

# Environment (default to dev)
ENV="${1:-dev}"
FLOWISE_APP="$PROJECT_ROOT/argocd/bootstrap/flowise-$ENV.yaml"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}🚀 DEPLOY FLOWISE APPLICATION${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}Environment:${NC} $ENV"
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

# Check ArgoCD namespace
if ! kubectl get namespace argocd &> /dev/null; then
    echo -e "${RED}❌ ArgoCD namespace not found${NC}"
    echo -e "${YELLOW}Run: bash scripts/deploy-argocd.sh first${NC}"
    exit 1
fi
echo -e "${GREEN}✅ ArgoCD namespace exists${NC}"

# Check if applications project exists
if ! kubectl get appproject applications -n argocd &> /dev/null; then
    echo -e "${RED}❌ Applications project not found${NC}"
    echo -e "${YELLOW}Run: bash scripts/deploy-projects.sh first${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Applications project exists${NC}"

# Check if app file exists
if [ ! -f "$FLOWISE_APP" ]; then
    echo -e "${RED}❌ Flowise app file not found: $FLOWISE_APP${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Flowise app file found${NC}"

# Check if ALB Controller is running (required for Ingress)
if ! kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --no-headers 2>/dev/null | grep -q "Running"; then
    echo -e "${YELLOW}⚠️  ALB Controller not found or not running${NC}"
    echo -e "${YELLOW}Flowise Ingress may not work without ALB Controller${NC}"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Deployment cancelled"
        exit 1
    fi
else
    echo -e "${GREEN}✅ ALB Controller is running${NC}"
fi

echo ""

# ========================================
# STEP 2: SHOW CONFIGURATION
# ========================================
echo -e "${YELLOW}📋 Step 2: Configuration Review${NC}"
echo ""
echo -e "${BLUE}Namespace:${NC} flowise-$ENV"
echo -e "${BLUE}Source:${NC} argocd/apps/flowise/overlays/$ENV"
echo -e "${BLUE}Project:${NC} applications"
echo ""

# ========================================
# STEP 3: DEPLOY FLOWISE APPLICATION
# ========================================
echo -e "${YELLOW}📋 Step 3: Deploying Flowise Application...${NC}"

echo ""
echo "Deploying from: $FLOWISE_APP"
echo ""

if kubectl apply -f "$FLOWISE_APP"; then
    echo -e "${GREEN}✅ Flowise application deployed${NC}"
else
    echo -e "${RED}❌ Failed to deploy Flowise application${NC}"
    exit 1
fi

echo ""

# ========================================
# STEP 4: WAIT FOR APPLICATION
# ========================================
echo -e "${YELLOW}📋 Step 4: Waiting for application to be created...${NC}"

echo ""
echo "Waiting for application..."
sleep 5

echo ""
echo -e "${BLUE}Application status:${NC}"
kubectl get application flowise-$ENV -n argocd || true

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✅ FLOWISE DEPLOYMENT INITIATED!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

echo -e "${YELLOW}📝 Deployed Resources:${NC}"
echo ""
echo "• Flowise Server (Backend API)"
echo "• Flowise UI (Frontend)"
echo "• PostgreSQL Database (PVC)"
echo "• Services (Server + UI)"
echo "• Ingress (ALB with HTTPS)"
echo ""

echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}📝 Monitor Deployment:${NC}"
echo ""
echo "# Watch application sync"
echo "kubectl get application flowise-$ENV -n argocd -w"
echo ""
echo "# Check application details"
echo "argocd app get flowise-$ENV"
echo ""
echo "# Check pods"
echo "kubectl get pods -n flowise-$ENV"
echo ""
echo "# Check services"
echo "kubectl get svc -n flowise-$ENV"
echo ""
echo "# Check ingress and ALB"
echo "kubectl get ingress -n flowise-$ENV"
echo ""
echo "# Check logs"
echo "kubectl logs -n flowise-$ENV -l app=flowise-server --tail=50 -f"
echo ""
echo "# Sync if needed"
echo "argocd app sync flowise-$ENV"
echo ""
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}📝 Access Flowise:${NC}"
echo ""

# Get ingress info
if kubectl get ingress -n flowise-$ENV &> /dev/null; then
    INGRESS_HOST=$(kubectl get ingress -n flowise-$ENV -o jsonpath='{.items[0].spec.rules[0].host}' 2>/dev/null || echo "flowise-$ENV.do2506.click")
    ALB_DNS=$(kubectl get ingress -n flowise-$ENV -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "<ALB provisioning...>")
    
    echo "🌐 Flowise URL:   https://$INGRESS_HOST"
    echo "🔗 ALB DNS:       $ALB_DNS"
else
    echo "🌐 Flowise URL:   https://flowise-$ENV.do2506.click (after ingress is created)"
fi

echo ""
echo -e "${YELLOW}⚠️  Important:${NC}"
echo "• Wait 5-10 minutes for all components to be ready"
echo "• ALB provisioning takes ~3 minutes"
echo "• Database initialization takes ~2 minutes"
echo "• Check ArgoCD UI for detailed deployment status"
echo ""
echo -e "${YELLOW}📚 Documentation:${NC}"
echo "• Configuration: argocd/apps/flowise/CONFIGURATION-CHECKLIST.md"
echo "• Architecture: argocd/docs/ARCHITECTURE.md"
echo ""
