#!/bin/bash
# ============================================
# Cleanup Local Kubernetes Environment
# ============================================
# Removes cluster and all resources

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
CLUSTER_NAME="${CLUSTER_NAME:-dev-cluster}"

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}🧹 Cleanup Local Kubernetes Environment${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

echo -e "${YELLOW}This will delete:${NC}"
echo "  - Kind cluster: ${CLUSTER_NAME}"
echo "  - All deployed applications"
echo "  - All persistent data"
echo ""

read -p "Are you sure? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cleanup cancelled"
    exit 0
fi

echo ""

# Delete Kind cluster
echo -e "${YELLOW}1. Deleting Kind cluster...${NC}"
if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    kind delete cluster --name "${CLUSTER_NAME}"
    echo -e "${GREEN}✅ Cluster deleted${NC}"
else
    echo -e "${YELLOW}⚠️  Cluster '${CLUSTER_NAME}' not found${NC}"
fi
echo ""

# Clean up Docker containers
echo -e "${YELLOW}2. Cleaning up Docker containers...${NC}"
docker ps -a | grep 'kindest/node' | awk '{print $1}' | xargs -r docker rm -f 2>/dev/null || true
echo -e "${GREEN}✅ Docker cleanup completed${NC}"
echo ""

# Clean up temp data
echo -e "${YELLOW}3. Cleaning up temporary data...${NC}"
rm -rf /tmp/kind-data-* 2>/dev/null || true
echo -e "${GREEN}✅ Temporary data cleaned${NC}"
echo ""

# Remove kubectl context
echo -e "${YELLOW}4. Cleaning kubectl context...${NC}"
kubectl config delete-context "kind-${CLUSTER_NAME}" 2>/dev/null || true
kubectl config delete-cluster "kind-${CLUSTER_NAME}" 2>/dev/null || true
kubectl config unset "users.kind-${CLUSTER_NAME}" 2>/dev/null || true
echo -e "${GREEN}✅ Kubectl context cleaned${NC}"
echo ""

# Summary
echo -e "${BLUE}============================================${NC}"
echo -e "${GREEN}🎉 Cleanup Complete!${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo "All resources have been removed"
echo ""
echo "To create a new cluster:"
echo "  ./create-cluster.sh"
echo ""
