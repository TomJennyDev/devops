#!/bin/bash
# ============================================
# Setup Ingress Controller for Kind
# ============================================
# Installs NGINX Ingress Controller
# Similar to AWS Load Balancer Controller

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}📦 Installing NGINX Ingress Controller${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Check if kubectl is configured
echo -e "${YELLOW}1. Checking kubectl context...${NC}"
if ! kubectl cluster-info > /dev/null 2>&1; then
    echo -e "${RED}❌ kubectl is not configured${NC}"
    echo "Run: ./create-cluster.sh first"
    exit 1
fi
CONTEXT=$(kubectl config current-context)
echo -e "${GREEN}✅ Using context: ${CONTEXT}${NC}"
echo ""

# Install NGINX Ingress Controller
echo -e "${YELLOW}2. Installing NGINX Ingress Controller...${NC}"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

echo ""
echo -e "${YELLOW}3. Waiting for Ingress Controller to be ready...${NC}"
echo "   This may take 1-2 minutes..."

# Wait for deployment
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s

echo ""
echo -e "${GREEN}✅ Ingress Controller is ready${NC}"
echo ""

# Verify installation
echo -e "${YELLOW}4. Verifying installation...${NC}"
echo ""
echo "Ingress Controller pods:"
kubectl get pods -n ingress-nginx
echo ""
echo "Ingress Controller service:"
kubectl get svc -n ingress-nginx
echo ""

# Test ingress
echo -e "${YELLOW}5. Testing Ingress...${NC}"

# Create test namespace
kubectl create namespace test-ingress --dry-run=client -o yaml | kubectl apply -f -

# Deploy test app
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-app
  namespace: test-ingress
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-app
  template:
    metadata:
      labels:
        app: test-app
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: test-app
  namespace: test-ingress
spec:
  selector:
    app: test-app
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-app
  namespace: test-ingress
spec:
  ingressClassName: nginx
  rules:
  - host: test.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: test-app
            port:
              number: 80
EOF

echo ""
echo "Waiting for test app..."
kubectl wait --namespace test-ingress \
  --for=condition=ready pod \
  --selector=app=test-app \
  --timeout=60s

echo ""
echo -e "${GREEN}✅ Test app deployed${NC}"
echo ""

# Summary
echo -e "${BLUE}============================================${NC}"
echo -e "${GREEN}🎉 Ingress Controller Ready!${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo "NGINX Ingress Controller installed in namespace: ingress-nginx"
echo ""
echo "Test your ingress:"
echo "  1. Add to /etc/hosts (or C:\Windows\System32\drivers\etc\hosts):"
echo "     127.0.0.1 test.local"
echo ""
echo "  2. Access:"
echo "     http://test.local"
echo ""
echo "  3. Or use curl:"
echo "     curl -H 'Host: test.local' http://localhost"
echo ""
echo "Clean up test app:"
echo "  kubectl delete namespace test-ingress"
echo ""
echo "Next step:"
echo "  ./deploy-argocd.sh"
echo ""
