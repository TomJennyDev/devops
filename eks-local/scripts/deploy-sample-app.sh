#!/bin/bash
# ============================================
# Deploy Sample Application
# ============================================
# Deploys a simple web application with Ingress

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
APP_NAME="${APP_NAME:-demo-app}"
APP_DOMAIN="${APP_DOMAIN:-demo.local}"
NAMESPACE="${NAMESPACE:-demo}"

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}🚀 Deploying Sample Application${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Check kubectl
echo -e "${YELLOW}1. Checking kubectl context...${NC}"
if ! kubectl cluster-info > /dev/null 2>&1; then
    echo -e "${RED}❌ kubectl is not configured${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Kubectl configured${NC}"
echo ""

# Create namespace
echo -e "${YELLOW}2. Creating namespace: ${NAMESPACE}${NC}"
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
echo -e "${GREEN}✅ Namespace created${NC}"
echo ""

# Deploy application
echo -e "${YELLOW}3. Deploying application...${NC}"

cat <<EOF | kubectl apply -f -
---
# Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${APP_NAME}
  namespace: ${NAMESPACE}
  labels:
    app: ${APP_NAME}
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ${APP_NAME}
  template:
    metadata:
      labels:
        app: ${APP_NAME}
    spec:
      containers:
      - name: app
        image: nginxdemos/hello:latest
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 100m
            memory: 128Mi
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 5
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 3

---
# Service
apiVersion: v1
kind: Service
metadata:
  name: ${APP_NAME}
  namespace: ${NAMESPACE}
  labels:
    app: ${APP_NAME}
spec:
  type: ClusterIP
  selector:
    app: ${APP_NAME}
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
    name: http

---
# Ingress
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${APP_NAME}
  namespace: ${NAMESPACE}
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: ${APP_DOMAIN}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ${APP_NAME}
            port:
              number: 80
EOF

echo -e "${GREEN}✅ Application deployed${NC}"
echo ""

# Wait for deployment
echo -e "${YELLOW}4. Waiting for deployment to be ready...${NC}"
kubectl wait --namespace ${NAMESPACE} \
  --for=condition=ready pod \
  --selector=app=${APP_NAME} \
  --timeout=120s

echo ""
echo -e "${GREEN}✅ Application is ready${NC}"
echo ""

# Verify
echo -e "${YELLOW}5. Verifying deployment...${NC}"
echo ""
echo "Pods:"
kubectl get pods -n ${NAMESPACE} -l app=${APP_NAME}
echo ""
echo "Service:"
kubectl get svc -n ${NAMESPACE} -l app=${APP_NAME}
echo ""
echo "Ingress:"
kubectl get ingress -n ${NAMESPACE}
echo ""

# Summary
echo -e "${BLUE}============================================${NC}"
echo -e "${GREEN}🎉 Application Deployed Successfully!${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo "Application: ${APP_NAME}"
echo "Namespace: ${NAMESPACE}"
echo "Domain: ${APP_DOMAIN}"
echo ""
echo "Access methods:"
echo ""
echo "1. Via Ingress:"
echo "   Add to hosts file (C:\Windows\System32\drivers\etc\hosts):"
echo "   127.0.0.1 ${APP_DOMAIN}"
echo ""
echo "   Then access: http://${APP_DOMAIN}"
echo ""
echo "2. Via curl:"
echo "   curl -H 'Host: ${APP_DOMAIN}' http://localhost"
echo ""
echo "3. Via port-forward:"
echo "   kubectl port-forward -n ${NAMESPACE} svc/${APP_NAME} 8081:80"
echo "   Then access: http://localhost:8081"
echo ""
echo "Check logs:"
echo "  kubectl logs -n ${NAMESPACE} -l app=${APP_NAME} -f"
echo ""
echo "Scale deployment:"
echo "  kubectl scale deployment ${APP_NAME} -n ${NAMESPACE} --replicas=5"
echo ""
echo "Delete application:"
echo "  kubectl delete namespace ${NAMESPACE}"
echo ""
