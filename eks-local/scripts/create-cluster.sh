#!/bin/bash
# ============================================
# Create Kind Kubernetes Cluster
# ============================================
# This script creates a local Kubernetes cluster using Kind
# Similar to EKS but runs on Docker

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
CLUSTER_NAME="${CLUSTER_NAME:-dev-cluster}"
CONFIG_FILE="${CONFIG_FILE:-../kind-config.yaml}"

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}🚀 Creating Kind Kubernetes Cluster${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Check if Docker is running
echo -e "${YELLOW}1. Checking Docker...${NC}"
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not running. Please start Docker Desktop.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Docker is running${NC}"
echo ""

# Check if Kind is installed
echo -e "${YELLOW}2. Checking Kind installation...${NC}"
if ! command -v kind &> /dev/null; then
    # Try Windows path
    if [ -f "/c/Windows/kind.exe" ]; then
        KIND_CMD="/c/Windows/kind.exe"
        KIND_VERSION=$($KIND_CMD version | head -n 1)
        echo -e "${GREEN}✅ Found Kind at: /c/Windows/kind.exe - ${KIND_VERSION}${NC}"
    else
        echo -e "${RED}❌ Kind is not installed.${NC}"
        echo "Install with: choco install kind"
        exit 1
    fi
else
    KIND_CMD="kind"
    KIND_VERSION=$(kind version | head -n 1)
    echo -e "${GREEN}✅ Kind is installed: ${KIND_VERSION}${NC}"
fi
echo ""

# Check if cluster already exists
echo -e "${YELLOW}3. Checking existing cluster...${NC}"
if $KIND_CMD get clusters | grep -q "^${CLUSTER_NAME}$"; then
    echo -e "${YELLOW}⚠️  Cluster '${CLUSTER_NAME}' already exists${NC}"
    read -p "Do you want to delete and recreate it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Deleting existing cluster...${NC}"
        $KIND_CMD delete cluster --name "${CLUSTER_NAME}"
        echo -e "${GREEN}✅ Cluster deleted${NC}"
    else
        echo -e "${BLUE}Using existing cluster${NC}"
        exit 0
    fi
fi
echo ""

# Create cluster
echo -e "${YELLOW}4. Creating cluster '${CLUSTER_NAME}'...${NC}"
echo "   This may take a few minutes..."
echo ""

if [ -f "$CONFIG_FILE" ]; then
    echo "   Using config file: ${CONFIG_FILE}"
    $KIND_CMD create cluster --name "${CLUSTER_NAME}" --config "${CONFIG_FILE}"
else
    echo "   Using default configuration"
    $KIND_CMD create cluster --name "${CLUSTER_NAME}" \
        --config - <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
      - containerPort: 443
        hostPort: 443
  - role: worker
  - role: worker
EOF
fi

echo ""
echo -e "${GREEN}✅ Cluster created successfully${NC}"
echo ""

# Set kubectl context
echo -e "${YELLOW}5. Setting kubectl context...${NC}"
kubectl config use-context "kind-${CLUSTER_NAME}"
echo -e "${GREEN}✅ Context set to: kind-${CLUSTER_NAME}${NC}"
echo ""

# Verify cluster
echo -e "${YELLOW}6. Verifying cluster...${NC}"
echo ""
echo "Nodes:"
kubectl get nodes -o wide
echo ""
echo "Pods:"
kubectl get pods -A
echo ""

# Cluster info
echo -e "${BLUE}============================================${NC}"
echo -e "${GREEN}🎉 Cluster Ready!${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo "Cluster Name: ${CLUSTER_NAME}"
echo "Context: kind-${CLUSTER_NAME}"
echo "API Server: $(kubectl cluster-info | grep 'Kubernetes control plane' | awk '{print $NF}')"
echo ""
echo "Next steps:"
echo "  1. Install Ingress Controller:"
echo "     ./setup-ingress.sh"
echo ""
echo "  2. Deploy ArgoCD:"
echo "     ./deploy-argocd.sh"
echo ""
echo "  3. Deploy sample app:"
echo "     ./deploy-sample-app.sh"
echo ""
echo "To delete cluster:"
echo "  kind delete cluster --name ${CLUSTER_NAME}"
echo ""
