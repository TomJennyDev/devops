#!/bin/bash
# ========================================
# DEPLOY AWS LOAD BALANCER CONTROLLER
# ========================================
# This script deploys AWS Load Balancer Controller using Kustomize
# Prerequisites: ArgoCD must be installed first
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
CLUSTER_INFO_DIR="$PROJECT_ROOT/environments/dev/cluster-info"
ALB_CONTROLLER_BASE="$PROJECT_ROOT/argocd/infrastructure/aws-load-balancer-controller"
ALB_CONTROLLER_DEV="$ALB_CONTROLLER_BASE/overlays/dev"

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
echo -e "${BLUE}🚀 AWS LOAD BALANCER CONTROLLER DEPLOYMENT${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}Cluster:${NC} $CLUSTER_NAME"
echo -e "${YELLOW}Region:${NC} $AWS_REGION"
echo -e "${YELLOW}VPC:${NC} $VPC_ID"
echo -e "${YELLOW}IAM Role:${NC} $ALB_CONTROLLER_ROLE_ARN"
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

# Check cluster access
if ! kubectl get nodes &> /dev/null; then
    echo -e "${RED}❌ Cannot access cluster.${NC}"
    echo -e "${YELLOW}Run: aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME${NC}"
    exit 1
fi

NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
echo -e "${GREEN}✅ Cluster access verified ($NODE_COUNT nodes ready)${NC}"

# Check ArgoCD is running
if ! kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server --no-headers 2>/dev/null | grep -q "Running"; then
    echo -e "${RED}❌ ArgoCD is not running in the cluster.${NC}"
    echo -e "${YELLOW}Please deploy ArgoCD first: ./deploy-argocd.sh${NC}"
    exit 1
fi
echo -e "${GREEN}✅ ArgoCD is running${NC}"

# Check values file exists
if [ ! -f "$ALB_CONTROLLER_DEV/values.yaml" ]; then
    echo -e "${RED}❌ Values file not found: $ALB_CONTROLLER_DEV/values.yaml${NC}"
    exit 1
fi
echo -e "${GREEN}✅ ALB Controller configuration found${NC}"

echo ""

# ========================================
# STEP 2: UPDATE CONFIGURATION
# ========================================
echo -e "${YELLOW}📋 Step 2: Updating ALB Controller configuration...${NC}"

# Run update script to ensure values are current
if [ -f "$SCRIPT_DIR/update-alb-controller-config.sh" ]; then
    echo "Running configuration update script..."
    bash "$SCRIPT_DIR/update-alb-controller-config.sh" dev
    echo -e "${GREEN}✅ Configuration updated${NC}"
else
    echo -e "${YELLOW}⚠️  Update script not found, using existing configuration${NC}"
fi

echo ""

# ========================================
# STEP 3: VERIFY CONFIGURATION
# ========================================
echo -e "${YELLOW}📋 Step 3: Verifying configuration values...${NC}"

# Read and display current values
CLUSTER_NAME_VALUE=$(grep "^clusterName:" "$ALB_CONTROLLER_DEV/values.yaml" | awk '{print $2}')
VPC_ID_VALUE=$(grep "^vpcId:" "$ALB_CONTROLLER_DEV/values.yaml" | awk '{print $2}')
IAM_ROLE_VALUE=$(grep "^iamRoleArn:" "$ALB_CONTROLLER_DEV/values.yaml" | awk '{print $2}')

echo "Cluster Name: $CLUSTER_NAME_VALUE"
echo "VPC ID: $VPC_ID_VALUE"
echo "IAM Role: $IAM_ROLE_VALUE"

# Verify values match cluster info
if [ "$CLUSTER_NAME_VALUE" != "$CLUSTER_NAME" ]; then
    echo -e "${RED}❌ Cluster name mismatch!${NC}"
    echo "  Expected: $CLUSTER_NAME"
    echo "  Found: $CLUSTER_NAME_VALUE"
    exit 1
fi

if [ "$VPC_ID_VALUE" != "$VPC_ID" ]; then
    echo -e "${RED}❌ VPC ID mismatch!${NC}"
    echo "  Expected: $VPC_ID"
    echo "  Found: $VPC_ID_VALUE"
    exit 1
fi

echo -e "${GREEN}✅ Configuration verified${NC}"

echo ""

# ========================================
# STEP 4: BUILD KUSTOMIZE MANIFESTS
# ========================================
echo -e "${YELLOW}📋 Step 4: Building Kustomize manifests...${NC}"

# Test kustomize build with Helm support
if ! kubectl kustomize "$ALB_CONTROLLER_DEV" --enable-helm > /dev/null 2>&1; then
    echo -e "${RED}❌ Kustomize build failed!${NC}"
    echo "Running with verbose output:"
    kubectl kustomize "$ALB_CONTROLLER_DEV" --enable-helm
    exit 1
fi

RESOURCE_COUNT=$(kubectl kustomize "$ALB_CONTROLLER_DEV" --enable-helm | grep -c "^kind:")
echo -e "${GREEN}✅ Kustomize build successful ($RESOURCE_COUNT resources)${NC}"

echo ""

# ========================================
# STEP 5: DEPLOY ALB CONTROLLER
# ========================================
echo -e "${YELLOW}📋 Step 5: Deploying AWS Load Balancer Controller...${NC}"

# Check if already deployed
if kubectl get application -n argocd aws-load-balancer-controller &> /dev/null; then
    echo -e "${YELLOW}⚠️  ALB Controller Application already exists. Updating...${NC}"
    ACTION="updated"
else
    echo "Creating ALB Controller Application..."
    ACTION="created"
fi

# Apply kustomize configuration
kubectl apply -k "$ALB_CONTROLLER_DEV"

echo -e "${GREEN}✅ ALB Controller Application $ACTION${NC}"

echo ""

# ========================================
# STEP 6: WAIT FOR ARGOCD TO SYNC
# ========================================
echo -e "${YELLOW}📋 Step 6: Waiting for ArgoCD to sync application...${NC}"

echo "Waiting for Application to be created (max 60s)..."
for i in {1..12}; do
    if kubectl get application -n argocd aws-load-balancer-controller &> /dev/null; then
        echo -e "${GREEN}✅ Application created${NC}"
        break
    fi
    if [ $i -eq 12 ]; then
        echo -e "${RED}❌ Timeout waiting for Application${NC}"
        exit 1
    fi
    sleep 5
    echo -n "."
done

echo ""
echo "Waiting for initial sync to start..."
sleep 10

# Check sync status
SYNC_STATUS=$(kubectl get application -n argocd aws-load-balancer-controller -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
HEALTH_STATUS=$(kubectl get application -n argocd aws-load-balancer-controller -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")

echo "Sync Status: $SYNC_STATUS"
echo "Health Status: $HEALTH_STATUS"

echo ""

# ========================================
# STEP 7: WAIT FOR DEPLOYMENT
# ========================================
echo -e "${YELLOW}📋 Step 7: Waiting for ALB Controller pods to be ready...${NC}"

echo "Waiting for deployment to be created..."
for i in {1..24}; do
    if kubectl get deployment -n kube-system aws-load-balancer-controller &> /dev/null; then
        echo -e "${GREEN}✅ Deployment created${NC}"
        break
    fi
    if [ $i -eq 24 ]; then
        echo -e "${YELLOW}⚠️  Deployment not created yet. Check ArgoCD sync status.${NC}"
        break
    fi
    sleep 5
    echo -n "."
done

echo ""

# Wait for pods to be ready
if kubectl get deployment -n kube-system aws-load-balancer-controller &> /dev/null; then
    echo "Waiting for pods to be ready (max 5 minutes)..."
    if kubectl wait --for=condition=available deployment/aws-load-balancer-controller \
        -n kube-system --timeout=300s 2>/dev/null; then
        echo -e "${GREEN}✅ ALB Controller is ready${NC}"
    else
        echo -e "${YELLOW}⚠️  Timeout waiting for pods. Checking status...${NC}"
        kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
    fi
fi

echo ""

# ========================================
# FINAL STATUS
# ========================================
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✅ DEPLOYMENT COMPLETE!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Get pod status
POD_COUNT=$(kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --no-headers 2>/dev/null | wc -l)
READY_COUNT=$(kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --no-headers 2>/dev/null | grep "Running" | wc -l)

echo -e "${YELLOW}📊 Status Summary:${NC}"
echo ""
echo "ArgoCD Application:"
echo "  Name: aws-load-balancer-controller"
echo "  Namespace: argocd"
echo "  Sync Status: $SYNC_STATUS"
echo "  Health Status: $HEALTH_STATUS"
echo ""
echo "Controller Pods:"
echo "  Total: $POD_COUNT"
echo "  Running: $READY_COUNT"
echo ""
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}📝 Next Steps:${NC}"
echo ""
echo "1️⃣  ${YELLOW}Check ArgoCD Application:${NC}"
echo "   kubectl get application -n argocd aws-load-balancer-controller"
echo "   kubectl describe application -n argocd aws-load-balancer-controller"
echo ""
echo "2️⃣  ${YELLOW}Check Controller Pods:${NC}"
echo "   kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller"
echo ""
echo "3️⃣  ${YELLOW}Check Controller Logs:${NC}"
echo "   kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=50 -f"
echo ""
echo "4️⃣  ${YELLOW}Verify Controller is working:${NC}"
echo "   # Deploy an Ingress resource and check if ALB is created"
echo "   kubectl apply -f argocd/apps/flowise/overlays/dev/ingress.yaml"
echo "   kubectl get ingress -A"
echo ""
echo "5️⃣  ${YELLOW}Access ArgoCD UI to monitor:${NC}"
echo "   https://argocd.do2506.click"
echo ""
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}💡 Useful Commands:${NC}"
echo ""
echo "# Watch Application sync status"
echo "kubectl get application -n argocd aws-load-balancer-controller -w"
echo ""
echo "# Force sync from ArgoCD UI or CLI"
echo "kubectl patch application -n argocd aws-load-balancer-controller \\"
echo "  -p '{\"operation\":{\"initiatedBy\":{\"username\":\"admin\"},\"sync\":{\"syncStrategy\":{\"hook\":{}}}}}' \\"
echo "  --type merge"
echo ""
echo "# Check webhook configuration"
echo "kubectl get validatingwebhookconfigurations | grep alb"
echo "kubectl get mutatingwebhookconfigurations | grep alb"
echo ""
echo "# Test ALB creation with sample Ingress"
echo "kubectl create ingress test-alb --class=alb --rule=\"test.example.com/*=test-service:80\" -n default"
echo ""
echo -e "${GREEN}✅ Deployment script complete!${NC}"
echo ""
