#!/bin/bash
# ========================================
# DEPLOY ARGOCD ON EKS - STEP BY STEP
# ========================================
# This script deploys ArgoCD using Helm with custom values
# Prerequisites: cert-manager must be installed first
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
TERRAFORM_DIR="$PROJECT_ROOT/terraform-eks/environments/dev"
CLUSTER_INFO_DIR="$PROJECT_ROOT/environments/dev/cluster-info"
ARGOCD_VALUES="$PROJECT_ROOT/argocd/config/argocd/values.yaml"

# Load cluster info from exported environment variables
if [ ! -f "$CLUSTER_INFO_DIR/cluster-env.sh" ]; then
  echo -e "${RED}❌ Cluster info not found!${NC}"
  echo -e "${YELLOW}Run: cd $SCRIPT_DIR && ./export-cluster-info.sh first${NC}"
  exit 1
fi

source "$CLUSTER_INFO_DIR/cluster-env.sh"

# Map environment variables to script variables
CLUSTER_NAME="$EKS_CLUSTER_NAME"
AWS_REGION="$EKS_REGION"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}🚀 ARGOCD DEPLOYMENT SCRIPT${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}Cluster:${NC} $CLUSTER_NAME"
echo -e "${YELLOW}Region:${NC} $AWS_REGION"
echo -e "${YELLOW}VPC:${NC} $VPC_ID"
echo ""

# ========================================
# STEP 1: VERIFY PREREQUISITES
# ========================================
echo -e "${YELLOW}📋 Step 1: Verifying prerequisites...${NC}"

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl not found. Please install kubectl first.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ kubectl installed${NC}"

# Check helm
if ! command -v helm &> /dev/null; then
    echo -e "${RED}❌ helm not found. Please install helm first.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ helm installed${NC}"

# Check cluster access
if ! kubectl get nodes &> /dev/null; then
    echo -e "${RED}❌ Cannot access cluster.${NC}"
    echo -e "${YELLOW}Run: aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME${NC}"
    exit 1
fi

NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
echo -e "${GREEN}✅ Cluster access verified ($NODE_COUNT nodes ready)${NC}"

# Check ArgoCD values file
if [ ! -f "$ARGOCD_VALUES" ]; then
    echo -e "${RED}❌ ArgoCD values file not found: $ARGOCD_VALUES${NC}"
    exit 1
fi 
echo -e "${GREEN}✅ ArgoCD values file found${NC}"

echo ""

# ========================================
# STEP 2: CHECK CERT-MANAGER
# ========================================
echo -e "${YELLOW}📋 Step 2: Checking cert-manager (required for ArgoCD webhooks)...${NC}"

if kubectl get namespace cert-manager &> /dev/null; then
    echo -e "${GREEN}✅ cert-manager namespace exists${NC}"
    
    # Check if cert-manager pods are running
    if kubectl get pods -n cert-manager -l app=cert-manager --no-headers 2>/dev/null | grep -q "Running"; then
        echo -e "${GREEN}✅ cert-manager is running${NC}"
    else
        echo -e "${YELLOW}⚠️  cert-manager pods not ready${NC}"
        echo "Waiting for cert-manager pods..."
        kubectl wait --for=condition=ready pod -l app=cert-manager -n cert-manager --timeout=300s || true
    fi
else
    echo -e "${YELLOW}⚠️  cert-manager not found. Installing...${NC}"
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
    
    echo "Waiting for cert-manager to be ready..."
    sleep 10
    kubectl wait --for=condition=ready pod -l app=cert-manager -n cert-manager --timeout=300s
    
    echo -e "${GREEN}✅ cert-manager installed${NC}"
fi

echo ""

# ========================================
# STEP 3: CREATE ARGOCD NAMESPACE
# ========================================
echo -e "${YELLOW}📋 Step 3: Creating ArgoCD namespace...${NC}"

if kubectl get namespace argocd &> /dev/null; then
    echo -e "${GREEN}✅ Namespace argocd already exists${NC}"
else
    kubectl create namespace argocd
    echo -e "${GREEN}✅ Namespace argocd created${NC}"
fi

echo ""

# ========================================
# STEP 4: DEPLOY ARGOCD WITH HELM
# ========================================
echo -e "${YELLOW}📋 Step 4: Deploying ArgoCD with Helm...${NC}"

# Add ArgoCD Helm repo
echo "Adding ArgoCD Helm repository..."
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

echo ""

# Check if already installed
if helm list -n argocd | grep -q "^argocd"; then
    echo -e "${YELLOW}⚠️  ArgoCD already installed. Upgrading...${NC}"
    HELM_COMMAND="upgrade"
else
    echo "Installing ArgoCD for the first time..."
    HELM_COMMAND="install"
fi

echo ""
echo -e "${BLUE}Using values file: $ARGOCD_VALUES${NC}"
echo ""

# Install/Upgrade ArgoCD
helm $HELM_COMMAND argocd argo/argo-cd \
  -n argocd \
  -f "$ARGOCD_VALUES" \
  --timeout 10m \
  --wait

echo ""
echo -e "${GREEN}✅ ArgoCD deployed successfully${NC}"

echo ""

# ========================================
# STEP 5: WAIT FOR ARGOCD TO BE READY
# ========================================
echo -e "${YELLOW}📋 Step 5: Waiting for ArgoCD components to be ready...${NC}"

echo "Waiting for ArgoCD Server..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

echo "Waiting for Repo Server..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-repo-server -n argocd --timeout=300s

echo "Waiting for Application Controller..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-application-controller -n argocd --timeout=300s

echo -e "${GREEN}✅ All ArgoCD components are ready${NC}"

echo ""

# ========================================
# STEP 6: GET ARGOCD CREDENTIALS
# ========================================
echo -e "${YELLOW}📋 Step 6: Retrieving ArgoCD credentials...${NC}"

# Check if password is set in values (commented out means using auto-generated)
if grep -q "^[[:space:]]*argocdServerAdminPassword:" "$ARGOCD_VALUES" && ! grep -q "^[[:space:]]*#[[:space:]]*argocdServerAdminPassword:" "$ARGOCD_VALUES"; then
    echo -e "${YELLOW}📝 Using password from values file${NC}"
    ARGOCD_PASSWORD="<set in values file>"
    PASSWORD_SOURCE="values file (argocd-values.yaml line 142)"
else
    echo "Retrieving auto-generated password..."
    if kubectl get secret argocd-initial-admin-secret -n argocd &> /dev/null; then
        ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d)
        PASSWORD_SOURCE="auto-generated (argocd-initial-admin-secret)"
    else
        echo -e "${YELLOW}⚠️  Initial admin secret not found${NC}"
        ARGOCD_PASSWORD="<not available yet>"
        PASSWORD_SOURCE="Secret not created yet"
    fi
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✅ ARGOCD DEPLOYED SUCCESSFULLY!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Get ingress info
echo -e "${YELLOW}📋 Getting Ingress information...${NC}"
INGRESS_HOST=$(kubectl get ingress -n argocd argocd-server -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || echo "argocd.do2506.click")
ALB_DNS=$(kubectl get ingress -n argocd argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "<ALB provisioning...>")

echo ""
echo -e "${YELLOW}📝 Access Information:${NC}"
echo ""
echo "🌐 ArgoCD URL:    https://$INGRESS_HOST"
echo "👤 Username:      admin"
echo "🔑 Password:      $ARGOCD_PASSWORD"
echo "📄 Source:        $PASSWORD_SOURCE"
echo ""
echo "🔗 ALB DNS:       $ALB_DNS"
echo ""
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}📝 Next Steps:${NC}"
echo ""
echo "1️⃣  ${YELLOW}Wait for ALB to be ready:${NC}"
echo "   kubectl get ingress -n argocd -w"
echo "   (Wait until ADDRESS column shows ALB DNS)"
echo ""
echo "2️⃣  ${YELLOW}Verify Route53 DNS:${NC}"
echo "   nslookup $INGRESS_HOST"
echo "   (Should point to ALB DNS)"
echo ""
echo "3️⃣  ${YELLOW}Access ArgoCD UI:${NC}"
echo "   https://$INGRESS_HOST"
echo "   Username: admin"
echo "   Password: $ARGOCD_PASSWORD"
echo ""
echo "4️⃣  ${YELLOW}Deploy AWS Load Balancer Controller (via ArgoCD):${NC}"
echo "   kubectl apply -k argocd/infrastructure/aws-load-balancer-controller/overlays/dev/"
echo ""
echo "5️⃣  ${YELLOW}Deploy Applications:${NC}"
echo "   kubectl apply -f argocd/bootstrap/flowise-dev.yaml"
echo ""
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}💡 Useful Commands:${NC}"
echo ""
echo "# Check all ArgoCD pods"
echo "kubectl get pods -n argocd"
echo ""
echo "# Check ArgoCD ingress and ALB"
echo "kubectl get ingress -n argocd"
echo ""
echo "# Check ALB Controller logs (after deployment)"
echo "kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=50 -f"
echo ""
echo "# Port-forward for local access (alternative)"
echo "kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "# Then access at: https://localhost:8080 (accept self-signed cert)"
echo ""
echo "# Check ArgoCD applications"
echo "kubectl get applications -n argocd"
echo ""
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN}✅ Deployment complete!${NC}"
echo ""
echo -e "${YELLOW}⚠️  Important Notes:${NC}"
echo "• ArgoCD is configured with server.insecure=true for GitHub Actions"
echo "• Password source: $PASSWORD_SOURCE"
echo "• Ingress uses ALB with HTTPS (certificate from ACM)"
echo "• cert-manager is required and should be running"
echo ""
