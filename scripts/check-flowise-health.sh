#!/bin/bash

# ========================================
# CHECK FLOWISE HEALTH SCRIPT
# ========================================
# Check health status of Flowise application in dev environment
# Usage: ./check-flowise-health.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="flowise-dev"
APP_NAME="flowise-dev"

echo "========================================="
echo "Flowise Dev Health Check"
echo "========================================="
echo ""

# 1. Check if namespace exists
echo -e "${BLUE}[1/8]${NC} Checking namespace..."
if kubectl get namespace $NAMESPACE &> /dev/null; then
    echo -e "${GREEN}✓${NC} Namespace '$NAMESPACE' exists"
else
    echo -e "${RED}✗${NC} Namespace '$NAMESPACE' does not exist"
    exit 1
fi
echo ""

# 2. Check ArgoCD Application status
echo -e "${BLUE}[2/8]${NC} Checking ArgoCD Application status..."
ARGOCD_STATUS=$(kubectl get application $APP_NAME -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "NotFound")
ARGOCD_HEALTH=$(kubectl get application $APP_NAME -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")

if [ "$ARGOCD_STATUS" = "Synced" ]; then
    echo -e "${GREEN}✓${NC} ArgoCD Sync Status: $ARGOCD_STATUS"
else
    echo -e "${RED}✗${NC} ArgoCD Sync Status: $ARGOCD_STATUS"
fi

if [ "$ARGOCD_HEALTH" = "Healthy" ]; then
    echo -e "${GREEN}✓${NC} ArgoCD Health Status: $ARGOCD_HEALTH"
else
    echo -e "${YELLOW}⚠${NC} ArgoCD Health Status: $ARGOCD_HEALTH"
fi
echo ""

# 3. Check Deployments
echo -e "${BLUE}[3/8]${NC} Checking Deployments..."
kubectl get deployments -n $NAMESPACE -o wide

DEPLOYMENTS=$(kubectl get deployments -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}')
for deployment in $DEPLOYMENTS; do
    READY=$(kubectl get deployment $deployment -n $NAMESPACE -o jsonpath='{.status.readyReplicas}')
    DESIRED=$(kubectl get deployment $deployment -n $NAMESPACE -o jsonpath='{.spec.replicas}')

    if [ "$READY" = "$DESIRED" ] && [ "$READY" != "" ]; then
        echo -e "${GREEN}✓${NC} $deployment: $READY/$DESIRED ready"
    else
        echo -e "${RED}✗${NC} $deployment: $READY/$DESIRED ready"
    fi
done
echo ""

# 4. Check Pods
echo -e "${BLUE}[4/8]${NC} Checking Pods..."
kubectl get pods -n $NAMESPACE -o wide

PODS=$(kubectl get pods -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}')
for pod in $PODS; do
    STATUS=$(kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.status.phase}')
    READY=$(kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.status.containerStatuses[0].ready}')

    if [ "$STATUS" = "Running" ] && [ "$READY" = "true" ]; then
        echo -e "${GREEN}✓${NC} $pod: $STATUS and Ready"
    else
        echo -e "${RED}✗${NC} $pod: $STATUS, Ready: $READY"
    fi
done
echo ""

# 5. Check Services
echo -e "${BLUE}[5/8]${NC} Checking Services..."
kubectl get services -n $NAMESPACE
echo ""

# 6. Check Ingress
echo -e "${BLUE}[6/8]${NC} Checking Ingress..."
if kubectl get ingress -n $NAMESPACE &> /dev/null; then
    kubectl get ingress -n $NAMESPACE

    INGRESS_HOST=$(kubectl get ingress -n $NAMESPACE -o jsonpath='{.items[0].spec.rules[0].host}' 2>/dev/null || echo "NotConfigured")
    echo -e "${BLUE}Ingress Host:${NC} $INGRESS_HOST"
else
    echo -e "${YELLOW}⚠${NC} No Ingress configured"
fi
echo ""

# 7. Check PVCs
echo -e "${BLUE}[7/8]${NC} Checking Persistent Volume Claims..."
if kubectl get pvc -n $NAMESPACE &> /dev/null; then
    kubectl get pvc -n $NAMESPACE

    PVCS=$(kubectl get pvc -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}')
    for pvc in $PVCS; do
        STATUS=$(kubectl get pvc $pvc -n $NAMESPACE -o jsonpath='{.status.phase}')
        if [ "$STATUS" = "Bound" ]; then
            echo -e "${GREEN}✓${NC} $pvc: $STATUS"
        else
            echo -e "${RED}✗${NC} $pvc: $STATUS"
        fi
    done
else
    echo -e "${YELLOW}⚠${NC} No PVCs found"
fi
echo ""

# 8. Recent Events
echo -e "${BLUE}[8/8]${NC} Recent Events (last 5 minutes)..."
kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | tail -20
echo ""

# Summary
echo "========================================="
echo "Health Check Summary"
echo "========================================="

# Calculate overall health
ISSUES=0

if [ "$ARGOCD_STATUS" != "Synced" ]; then
    ((ISSUES++))
fi

if [ "$ARGOCD_HEALTH" != "Healthy" ]; then
    ((ISSUES++))
fi

# Check if all deployments are ready
for deployment in $DEPLOYMENTS; do
    READY=$(kubectl get deployment $deployment -n $NAMESPACE -o jsonpath='{.status.readyReplicas}')
    DESIRED=$(kubectl get deployment $deployment -n $NAMESPACE -o jsonpath='{.spec.replicas}')
    if [ "$READY" != "$DESIRED" ] || [ "$READY" = "" ]; then
        ((ISSUES++))
    fi
done

# Check if all pods are running
for pod in $PODS; do
    STATUS=$(kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.status.phase}')
    if [ "$STATUS" != "Running" ]; then
        ((ISSUES++))
    fi
done

if [ $ISSUES -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed! Flowise is healthy.${NC}"
    echo ""
    echo "Access Flowise:"
    if [ "$INGRESS_HOST" != "NotConfigured" ]; then
        echo -e "  ${BLUE}https://$INGRESS_HOST${NC}"
    else
        echo "  Port-forward: kubectl port-forward -n $NAMESPACE svc/flowise-server 3000:3000"
    fi
else
    echo -e "${RED}✗ Found $ISSUES issue(s). Check details above.${NC}"
    echo ""
    echo "Troubleshooting commands:"
    echo "  kubectl describe pod <pod-name> -n $NAMESPACE"
    echo "  kubectl logs <pod-name> -n $NAMESPACE"
    echo "  kubectl get events -n $NAMESPACE"
fi

echo ""
