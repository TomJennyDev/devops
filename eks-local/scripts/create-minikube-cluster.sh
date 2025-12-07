#!/bin/bash
# ============================================
# Create Minikube Kubernetes Cluster
# ============================================
# More stable alternative to Kind on Windows

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
CLUSTER_NAME="${CLUSTER_NAME:-dev-cluster}"
NODES="${NODES:-1}"
CPUS="${CPUS:-4}"
MEMORY="${MEMORY:-4096}"

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}Creating Minikube Kubernetes Cluster${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Check if Docker is running
echo -e "${YELLOW}1. Checking Docker...${NC}"
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}Docker is not running. Please start Docker Desktop.${NC}"
    exit 1
fi
echo -e "${GREEN}Docker is running${NC}"
echo ""

# Check if Minikube is installed
echo -e "${YELLOW}2. Checking Minikube installation...${NC}"
if ! command -v minikube &> /dev/null; then
    echo -e "${RED}Minikube is not installed.${NC}"
    echo "Install with: choco install minikube"
    exit 1
fi
MINIKUBE_VERSION=$(minikube version --short)
echo -e "${GREEN}Minikube is installed: ${MINIKUBE_VERSION}${NC}"
echo ""

# Check if cluster already exists
echo -e "${YELLOW}3. Checking existing cluster...${NC}"
if minikube profile list 2>/dev/null | grep -q "^${CLUSTER_NAME}"; then
    echo -e "${YELLOW}Cluster '${CLUSTER_NAME}' already exists${NC}"
    read -p "Do you want to delete and recreate it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Deleting existing cluster...${NC}"
        minikube delete --profile="${CLUSTER_NAME}"
        echo -e "${GREEN}Cluster deleted${NC}"
    else
        echo -e "${BLUE}Using existing cluster${NC}"
        minikube status --profile="${CLUSTER_NAME}"
        exit 0
    fi
fi
echo ""

# Create cluster
echo -e "${YELLOW}4. Creating cluster '${CLUSTER_NAME}'...${NC}"
echo "   This may take a few minutes..."
echo "   Configuration:"
echo "     - Nodes: ${NODES}"
echo "     - CPUs: ${CPUS}"
echo "     - Memory: ${MEMORY}MB"
echo "     - Driver: Docker"
echo ""

minikube start \
  --profile="${CLUSTER_NAME}" \
  --driver=docker \
  --nodes=${NODES} \
  --cpus=${CPUS} \
  --memory=${MEMORY} \
  --disk-size=20g \
  --kubernetes-version=stable

echo ""
echo -e "${GREEN}Cluster created successfully${NC}"
echo ""

# Enable essential addons
echo -e "${YELLOW}5. Enabling addons...${NC}"
minikube addons enable ingress --profile="${CLUSTER_NAME}"
minikube addons enable metrics-server --profile="${CLUSTER_NAME}"
echo -e "${GREEN}Addons enabled${NC}"
echo ""

# Get cluster info
echo -e "${YELLOW}6. Cluster information:${NC}"
echo ""
minikube status --profile="${CLUSTER_NAME}"
echo ""
echo "Cluster IP: $(minikube ip --profile="${CLUSTER_NAME}")"
echo "Kubernetes Version: $(kubectl version --short --client)"
echo ""

# Get nodes
echo -e "${YELLOW}7. Nodes:${NC}"
kubectl get nodes
echo ""

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}Cluster is ready!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "Useful commands:"
echo "  kubectl get nodes                          # List nodes"
echo "  kubectl get pods -A                        # List all pods"
echo "  minikube dashboard --profile=${CLUSTER_NAME} # Open dashboard"
echo "  minikube ssh --profile=${CLUSTER_NAME}      # SSH into node"
echo "  minikube delete --profile=${CLUSTER_NAME}   # Delete cluster"
echo ""
echo "Next steps:"
echo "  bash setup-ingress.sh                      # Setup NGINX Ingress (optional, already enabled)"
echo "  bash deploy-argocd.sh                      # Deploy ArgoCD"
echo "  bash deploy-sample-app.sh                  # Deploy sample app"
echo ""
