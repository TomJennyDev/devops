#!/bin/bash

# ========================================
# UPDATE KUBECONFIG
# ========================================
# Updates kubectl config to connect to EKS cluster
# Run this after:
# - Creating new EKS cluster
# - Recreating EKS cluster (new OIDC endpoint)
# - Switching between environments
# ========================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER_INFO_DIR="$SCRIPT_DIR/../environments/dev/cluster-info"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================"
echo "🔧 UPDATE KUBECONFIG"
echo "========================================"
echo ""

# Load cluster info
if [ -f "$CLUSTER_INFO_DIR/cluster-env.sh" ]; then
    source "$CLUSTER_INFO_DIR/cluster-env.sh"
    echo -e "${GREEN}✓${NC} Cluster environment variables loaded:"
    echo "  EKS_CLUSTER_NAME: $EKS_CLUSTER_NAME"
    echo "  EKS_REGION: $EKS_REGION"
    echo ""
else
    echo -e "${YELLOW}⚠${NC}  cluster-env.sh not found, using defaults"
    EKS_CLUSTER_NAME="my-eks-dev"
    EKS_REGION="ap-southeast-1"
    echo "  EKS_CLUSTER_NAME: $EKS_CLUSTER_NAME"
    echo "  EKS_REGION: $EKS_REGION"
    echo ""
fi

# Update kubeconfig
echo -e "${BLUE}📋 Updating kubeconfig...${NC}"
echo ""

aws eks update-kubeconfig --region "$EKS_REGION" --name "$EKS_CLUSTER_NAME"

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓${NC} Kubeconfig updated successfully!"
    echo ""

    # Test connection
    echo -e "${BLUE}🔍 Testing cluster connection...${NC}"
    echo ""

    kubectl get nodes -o wide

    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${GREEN}✓${NC} Successfully connected to cluster!"
        echo ""
        echo -e "${BLUE}Cluster info:${NC}"
        kubectl cluster-info
    else
        echo ""
        echo -e "${YELLOW}⚠${NC}  Could not connect to cluster nodes"
        echo "    This might be normal if nodes are still initializing"
    fi
else
    echo ""
    echo -e "${YELLOW}⚠${NC}  Failed to update kubeconfig"
    exit 1
fi

echo ""
echo "========================================"
echo -e "${GREEN}✓ KUBECONFIG UPDATE COMPLETE${NC}"
echo "========================================"
