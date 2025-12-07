#!/bin/bash
# ============================================
# Create k3d Cluster
# ============================================
# Lightweight alternative to Kind

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Creating k3d cluster...${NC}"

# Create cluster with built-in load balancer
k3d cluster create dev-cluster \
  --agents 2 \
  --port 8080:80@loadbalancer \
  --port 8443:443@loadbalancer \
  --port 30000-30010:30000-30010@server:0 \
  --k3s-arg "--disable=traefik@server:0" \
  --wait

# Install NGINX Ingress
echo -e "${YELLOW}Installing NGINX Ingress...${NC}"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml

# Wait for ingress
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

echo ""
echo -e "${GREEN}Cluster ready!${NC}"
kubectl get nodes

echo ""
echo "Access applications:"
echo "  HTTP:  http://localhost:8080"
echo "  HTTPS: https://localhost:8443"
echo ""
