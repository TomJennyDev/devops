#!/bin/bash
# ============================================
# Deploy ArgoCD to Local Cluster
# ============================================
# Installs ArgoCD with Ingress configuration

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
ARGOCD_VERSION="${ARGOCD_VERSION:-v2.9.3}"
ARGOCD_DOMAIN="${ARGOCD_DOMAIN:-argocd.local}"

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}🚀 Deploying ArgoCD${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Check kubectl
echo -e "${YELLOW}1. Checking kubectl context...${NC}"
if ! kubectl cluster-info > /dev/null 2>&1; then
    echo -e "${RED}❌ kubectl is not configured${NC}"
    exit 1
fi
CONTEXT=$(kubectl config current-context)
echo -e "${GREEN}✅ Using context: ${CONTEXT}${NC}"
echo ""

# Create namespace
echo -e "${YELLOW}2. Creating ArgoCD namespace...${NC}"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
echo -e "${GREEN}✅ Namespace created${NC}"
echo ""

# Install ArgoCD
echo -e "${YELLOW}3. Installing ArgoCD ${ARGOCD_VERSION}...${NC}"
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml

echo ""
echo -e "${YELLOW}4. Waiting for ArgoCD to be ready...${NC}"
echo "   This may take 2-3 minutes..."

# Wait for pods
kubectl wait --for=condition=ready pod \
  --selector=app.kubernetes.io/name=argocd-server \
  --namespace=argocd \
  --timeout=300s

echo ""
echo -e "${GREEN}✅ ArgoCD is ready${NC}"
echo ""

# Get admin password
echo -e "${YELLOW}5. Getting admin password...${NC}"
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)

echo -e "${GREEN}✅ Password retrieved${NC}"
echo ""

# Create Ingress
echo -e "${YELLOW}6. Creating Ingress for ArgoCD...${NC}"

cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server
  namespace: argocd
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    nginx.ingress.kubernetes.io/ssl-passthrough: "true"
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
spec:
  ingressClassName: nginx
  rules:
  - host: ${ARGOCD_DOMAIN}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 443
EOF

echo -e "${GREEN}✅ Ingress created${NC}"
echo ""

# Verify
echo -e "${YELLOW}7. Verifying installation...${NC}"
echo ""
echo "ArgoCD pods:"
kubectl get pods -n argocd
echo ""
echo "ArgoCD services:"
kubectl get svc -n argocd
echo ""
echo "ArgoCD ingress:"
kubectl get ingress -n argocd
echo ""

# Summary
echo -e "${BLUE}============================================${NC}"
echo -e "${GREEN}🎉 ArgoCD Deployed Successfully!${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo "Credentials:"
echo "  Username: admin"
echo "  Password: ${ARGOCD_PASSWORD}"
echo ""
echo "Access methods:"
echo ""
echo "1. Via Ingress (add to hosts file):"
echo "   Add to /etc/hosts or C:\Windows\System32\drivers\etc\hosts:"
echo "   127.0.0.1 ${ARGOCD_DOMAIN}"
echo ""
echo "   Then access: https://${ARGOCD_DOMAIN}"
echo "   (Accept self-signed certificate)"
echo ""
echo "2. Via Port Forward:"
echo "   kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "   Then access: https://localhost:8080"
echo ""
echo "3. Via kubectl:"
echo "   # Login"
echo "   argocd login localhost:8080 --username admin --password ${ARGOCD_PASSWORD} --insecure"
echo ""
echo "   # Add repository"
echo "   argocd repo add https://github.com/TomJennyDev/flowise-gitops.git"
echo ""
echo "   # Create application"
echo "   argocd app create flowise-dev \\"
echo "     --repo https://github.com/TomJennyDev/flowise-gitops.git \\"
echo "     --path overlays/dev \\"
echo "     --dest-server https://kubernetes.default.svc \\"
echo "     --dest-namespace flowise-dev"
echo ""
echo "Change password:"
echo "  argocd account update-password"
echo ""
