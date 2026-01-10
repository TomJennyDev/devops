#!/bin/bash
# ========================================
# MASTER BOOTSTRAP SCRIPT - ONE COMMAND DEPLOYMENT
# ========================================
# This script is the ONLY script you need to run!
# It will:
# 1. Deploy ArgoCD
# 2. Deploy ArgoCD Projects (applications, infrastructure)
# 3. Deploy App-of-Apps (which then auto-deploys everything else)
#
# After this runs, ArgoCD will manage everything automatically via GitOps!
# ========================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Script directory and paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CLUSTER_INFO_DIR="$PROJECT_ROOT/environments/dev/cluster-info"

# ========================================
# BANNER
# ========================================
clear
echo -e "${MAGENTA}"
cat << "EOF"
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║     ██████╗  ██████╗  ██████╗ ████████╗███████╗████████╗       ║
║     ██╔══██╗██╔═══██╗██╔═══██╗╚══██╔══╝██╔════╝╚══██╔══╝       ║
║     ██████╔╝██║   ██║██║   ██║   ██║   ███████╗   ██║          ║
║     ██╔══██╗██║   ██║██║   ██║   ██║   ╚════██║   ██║          ║
║     ██████╔╝╚██████╔╝╚██████╔╝   ██║   ███████║   ██║          ║
║     ╚═════╝  ╚═════╝  ╚═════╝    ╚═╝   ╚══════╝   ╚═╝          ║
║                                                                ║
║              GitOps Bootstrap - One Command Deploy             ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${CYAN}🎯 This script will bootstrap your entire infrastructure!${NC}"
echo -e "${CYAN}   After completion, ArgoCD manages everything automatically.${NC}"
echo ""

# ========================================
# PREREQUISITE CHECK
# ========================================
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}📋 Step 0: Checking Prerequisites${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"

# Check if cluster info exists
if [ ! -f "$CLUSTER_INFO_DIR/cluster-env.sh" ]; then
  echo -e "${RED}❌ Cluster info not found!${NC}"
  echo -e "${YELLOW}Running export-cluster-info.sh first...${NC}"
  bash "$SCRIPT_DIR/export-cluster-info.sh"
fi

source "$CLUSTER_INFO_DIR/cluster-env.sh"

# Check kubectl connection
if ! kubectl cluster-info &> /dev/null; then
  echo -e "${RED}❌ Cannot connect to Kubernetes cluster!${NC}"
  echo -e "${YELLOW}Run: aws eks update-kubeconfig --name $EKS_CLUSTER_NAME --region $EKS_REGION${NC}"
  exit 1
fi

echo -e "${GREEN}✅ Prerequisites checked${NC}"
echo ""

# Display cluster info
echo -e "${CYAN}🎯 Target Cluster:${NC}"
echo -e "   Cluster: ${GREEN}$EKS_CLUSTER_NAME${NC}"
echo -e "   Region:  ${GREEN}$EKS_REGION${NC}"
echo -e "   VPC:     ${GREEN}$VPC_ID${NC}"
echo ""

# Confirmation prompt
echo -e "${YELLOW}⚠️  This will deploy ArgoCD and bootstrap all applications.${NC}"
echo -e "${YELLOW}   Continue? (yes/no)${NC}"
read -r CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo -e "${RED}❌ Deployment cancelled${NC}"
  exit 0
fi

echo ""

# ========================================
# STEP 1: DEPLOY ARGOCD
# ========================================
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}🚀 Step 1: Deploying ArgoCD${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"

# Check if ArgoCD is already installed
if kubectl get namespace argocd &> /dev/null; then
  echo -e "${YELLOW}⚠️  ArgoCD namespace already exists${NC}"
  echo -e "${YELLOW}   Skip ArgoCD installation? (yes/no)${NC}"
  read -r SKIP_ARGOCD

  if [ "$SKIP_ARGOCD" = "yes" ]; then
    echo -e "${GREEN}✅ Skipping ArgoCD installation${NC}"
  else
    echo -e "${YELLOW}Re-installing ArgoCD...${NC}"
    bash "$SCRIPT_DIR/deploy-argocd.sh"
  fi
else
  bash "$SCRIPT_DIR/deploy-argocd.sh"
fi

echo -e "${GREEN}✅ ArgoCD deployed successfully${NC}"
echo ""

# Wait for ArgoCD to be ready
echo -e "${YELLOW}⏳ Waiting for ArgoCD to be ready (max 2 minutes)...${NC}"
kubectl wait --for=condition=available --timeout=120s \
  deployment/argocd-server -n argocd || true

echo ""

# ========================================
# STEP 2: DEPLOY ARGOCD PROJECTS
# ========================================
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}📦 Step 2: Creating ArgoCD Projects${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"

echo -e "${YELLOW}Creating projects (applications, infrastructure)...${NC}"

# Deploy projects
kubectl apply -f "$PROJECT_ROOT/argocd/projects/applications.yaml"
kubectl apply -f "$PROJECT_ROOT/argocd/projects/infrastructure.yaml"

echo -e "${GREEN}✅ ArgoCD Projects created${NC}"
echo ""

# ========================================
# STEP 3: DEPLOY BOOTSTRAP APPLICATIONS (App-of-Apps Pattern)
# ========================================
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}🌟 Step 3: Deploying Bootstrap Applications${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"

echo -e "${CYAN}📌 Deploying App-of-Apps (2 kubectl applies only):${NC}"
echo -e "${CYAN}   1. infrastructure-apps-dev (ALB, Prometheus, etc)${NC}"
echo -e "${CYAN}   2. flowise-dev (Application)${NC}"
echo -e "${CYAN}   After this, ArgoCD manages everything from Git!${NC}"
echo ""

# Deploy infrastructure app-of-apps
echo -e "${YELLOW}[1/2] Deploying infrastructure app-of-apps...${NC}"
kubectl apply -f "$PROJECT_ROOT/argocd/bootstrap/infrastructure-apps-dev.yaml"
echo -e "${GREEN}✅ Infrastructure app-of-apps created${NC}"

# Deploy application app-of-apps
echo -e "${YELLOW}[2/2] Deploying flowise application...${NC}"
kubectl apply -f "$PROJECT_ROOT/argocd/bootstrap/flowise-dev.yaml"
echo -e "${GREEN}✅ Flowise application created${NC}"

echo ""
echo -e "${GREEN}✅ Bootstrap complete!${NC}"
echo -e "${CYAN}   From now on: git push → ArgoCD auto-syncs!${NC}"
echo ""

# ========================================
# STEP 4: VERIFY DEPLOYMENT
# ========================================
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}🔍 Step 4: Verifying Deployment${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"

echo -e "${YELLOW}ArgoCD Applications:${NC}"
kubectl get applications -n argocd

echo ""
echo -e "${YELLOW}ArgoCD Projects:${NC}"
kubectl get appprojects -n argocd

echo ""

# ========================================
# COMPLETION
# ========================================
echo ""
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ BOOTSTRAP COMPLETED SUCCESSFULLY!${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo ""

# Get ArgoCD admin password
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo "not-found")

# Get ArgoCD URL (from ingress if available)
ARGOCD_URL=$(kubectl get ingress -n argocd argocd-server \
  -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || echo "localhost")

echo -e "${CYAN}🎉 GitOps is now active!${NC}"
echo ""
echo -e "${YELLOW}📋 Next Steps:${NC}"
echo ""
echo -e "1️⃣  ${CYAN}Access ArgoCD UI:${NC}"
if [ "$ARGOCD_URL" = "localhost" ]; then
  echo -e "   ${GREEN}kubectl port-forward svc/argocd-server -n argocd 8080:443${NC}"
  echo -e "   Then open: ${GREEN}https://localhost:8080${NC}"
else
  echo -e "   Open: ${GREEN}https://$ARGOCD_URL${NC}"
fi
echo ""
echo -e "   Username: ${GREEN}admin${NC}"
if [ "$ARGOCD_PASSWORD" != "not-found" ]; then
  echo -e "   Password: ${GREEN}$ARGOCD_PASSWORD${NC}"
else
  echo -e "   Password: ${YELLOW}Run: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d${NC}"
fi
echo ""

echo -e "2️⃣  ${CYAN}Monitor ArgoCD Applications:${NC}"
echo -e "   ${GREEN}kubectl get applications -n argocd -w${NC}"
echo ""

echo -e "3️⃣  ${CYAN}Watch ArgoCD sync all resources:${NC}"
echo -e "   ${GREEN}argocd app list${NC}"
echo -e "   ${GREEN}argocd app get infrastructure-apps-dev${NC}"
echo -e "   ${GREEN}argocd app get flowise-dev${NC}"
echo ""

echo -e "4️⃣  ${CYAN}From now on, just push to Git!${NC}"
echo -e "   ${GREEN}git push${NC} → ArgoCD automatically syncs! 🚀"
echo ""

echo -e "${MAGENTA}════════════════════════════════════════${NC}"
echo -e "${MAGENTA}🎯 ArgoCD is managing your cluster!${NC}"
echo -e "${MAGENTA}   No more manual kubectl apply needed!${NC}"
echo -e "${MAGENTA}════════════════════════════════════════${NC}"
echo ""

# Optional: Show sync status
echo -e "${YELLOW}📊 Current Sync Status:${NC}"
echo ""
kubectl get applications -n argocd -o custom-columns=\
NAME:.metadata.name,\
SYNC:.status.sync.status,\
HEALTH:.status.health.status,\
MESSAGE:.status.conditions[0].message 2>/dev/null || true

echo ""
echo -e "${GREEN}✅ Bootstrap script completed!${NC}"
echo -e "${CYAN}💡 Tip: Bookmark this output for future reference${NC}"
