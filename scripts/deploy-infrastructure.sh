#!/bin/bash
# ========================================
# DEPLOY INFRASTRUCTURE COMPONENTS
# ========================================
# Deploy Infrastructure App-of-Apps (ALB Controller + Prometheus)
# 
# NOTE: This deploys ALB Controller via ArgoCD GitOps.
# If you need ALB Controller BEFORE ArgoCD (for ArgoCD Ingress),
# deploy it via Helm or Terraform first.
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
INFRA_APP="$PROJECT_ROOT/argocd/bootstrap/infrastructure-apps-$ENV.yaml"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}🏗️  DEPLOY INFRASTRUCTURE COMPONENTS${NC}"
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

# Check if infrastructure project exists
if ! kubectl get appproject infrastructure -n argocd &> /dev/null; then
    echo -e "${RED}❌ Infrastructure project not found${NC}"
    echo -e "${YELLOW}Run: bash scripts/deploy-projects.sh first${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Infrastructure project exists${NC}"

# Check if app file exists
if [ ! -f "$INFRA_APP" ]; then
    echo -e "${RED}❌ Infrastructure app file not found: $INFRA_APP${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Infrastructure app file found${NC}"

echo ""

# ========================================
# STEP 2: DEPLOY INFRASTRUCTURE APP-OF-APPS
# ========================================
echo -e "${YELLOW}📋 Step 2: Deploying Infrastructure App-of-Apps...${NC}"

echo ""
echo "Deploying from: $INFRA_APP"
echo ""

if kubectl apply -f "$INFRA_APP"; then
    echo -e "${GREEN}✅ Infrastructure app-of-apps deployed${NC}"
else
    echo -e "${RED}❌ Failed to deploy infrastructure app-of-apps${NC}"
    exit 1
fi

echo ""

# ========================================
# STEP 3: WAIT FOR APPLICATIONS
# ========================================
echo -e "${YELLOW}📋 Step 3: Waiting for applications to be created...${NC}"

echo ""
echo "Waiting for applications..."
sleep 5

echo ""
echo -e "${BLUE}Applications created:${NC}"
kubectl get applications -n argocd | grep -E "infrastructure-apps-$ENV|aws-load-balancer|prometheus" || true

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✅ INFRASTRUCTURE DEPLOYMENT INITIATED!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

echo -e "${YELLOW}📝 Deployed Components:${NC}"
echo ""
echo "• AWS Load Balancer Controller (kube-system namespace)"
echo "• Prometheus + Grafana Stack (monitoring namespace)"
echo ""

echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}📝 Monitor Deployment:${NC}"
echo ""
echo "# Watch all applications"
echo "kubectl get applications -n argocd -w"
echo ""
echo "# Check infrastructure app-of-apps"
echo "argocd app get infrastructure-apps-$ENV"
echo ""
echo "# Check individual components"
echo "argocd app get aws-load-balancer-controller"
echo "argocd app get prometheus"
echo ""
echo "# Check ALB Controller pods"
echo "kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller"
echo ""
echo "# Check Prometheus pods"
echo "kubectl get pods -n monitoring"
echo ""
echo "# Sync if needed"
echo "argocd app sync infrastructure-apps-$ENV"
echo ""
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}⚠️  Notes:${NC}"
echo "• ALB Controller deployment may take 2-3 minutes"
echo "• Prometheus stack may take 5-10 minutes"
echo "• Check ArgoCD UI for detailed status"
echo "• Wait for all components to be healthy before deploying apps"
echo ""
echo -e "${YELLOW}📝 Next Step:${NC}"
echo ""
echo "After infrastructure is healthy, deploy applications:"
echo "bash scripts/deploy-flowise.sh $ENV"
echo ""
