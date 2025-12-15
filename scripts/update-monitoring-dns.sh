#!/bin/bash
# ========================================
# UPDATE MONITORING DNS RECORDS
# ========================================
# Creates Route53 DNS records for Grafana, Prometheus, AlertManager
# ========================================
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
ROUTE53_ZONE_ID="Z08819302E9BMC6AAR2OJ"
DOMAIN="do2506.click"
ENV="dev"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}🌐 UPDATE MONITORING DNS RECORDS${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# ========================================
# STEP 1: GET ALB HOSTNAME
# ========================================
echo -e "${YELLOW}📋 Step 1: Getting ALB hostname from Ingress...${NC}"

MAX_RETRIES=30
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    ALB_HOSTNAME=$(kubectl get ingress grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    
    if [ -n "$ALB_HOSTNAME" ]; then
        echo -e "${GREEN}✅ ALB hostname found: $ALB_HOSTNAME${NC}"
        break
    fi
    
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "Waiting for ALB to be provisioned... (attempt $RETRY_COUNT/$MAX_RETRIES)"
    sleep 10
done

if [ -z "$ALB_HOSTNAME" ]; then
    echo -e "${RED}❌ Failed to get ALB hostname after $MAX_RETRIES attempts${NC}"
    echo ""
    echo -e "${YELLOW}Check ingress status:${NC}"
    echo "kubectl describe ingress grafana -n monitoring"
    exit 1
fi

# Get ALB Zone ID
ALB_ZONE_ID=$(aws elbv2 describe-load-balancers --region ap-southeast-1 --query "LoadBalancers[?DNSName=='$ALB_HOSTNAME'].CanonicalHostedZoneId" --output text)

if [ -z "$ALB_ZONE_ID" ]; then
    echo -e "${RED}❌ Failed to get ALB zone ID${NC}"
    exit 1
fi

echo -e "${GREEN}✅ ALB Zone ID: $ALB_ZONE_ID${NC}"
echo ""

# ========================================
# STEP 2: CREATE/UPDATE DNS RECORDS
# ========================================
echo -e "${YELLOW}📋 Step 2: Creating/Updating DNS records...${NC}"
echo ""

# Function to create DNS record
create_dns_record() {
    local SUBDOMAIN=$1
    local FULL_DOMAIN="${SUBDOMAIN}.${DOMAIN}"
    
    echo -e "${YELLOW}Creating DNS record: ${FULL_DOMAIN}${NC}"
    
    # Check if record exists
    EXISTING_RECORD=$(aws route53 list-resource-record-sets \
        --hosted-zone-id "$ROUTE53_ZONE_ID" \
        --query "ResourceRecordSets[?Name=='${FULL_DOMAIN}.']" \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$EXISTING_RECORD" ]; then
        echo "Record exists, updating..."
        ACTION="UPSERT"
    else
        echo "Creating new record..."
        ACTION="CREATE"
    fi
    
    # Create change batch
    CHANGE_BATCH=$(cat <<EOF
{
  "Changes": [{
    "Action": "$ACTION",
    "ResourceRecordSet": {
      "Name": "${FULL_DOMAIN}",
      "Type": "A",
      "AliasTarget": {
        "HostedZoneId": "${ALB_ZONE_ID}",
        "DNSName": "${ALB_HOSTNAME}",
        "EvaluateTargetHealth": false
      }
    }
  }]
}
EOF
)
    
    # Apply change
    CHANGE_ID=$(aws route53 change-resource-record-sets \
        --hosted-zone-id "$ROUTE53_ZONE_ID" \
        --change-batch "$CHANGE_BATCH" \
        --query 'ChangeInfo.Id' \
        --output text)
    
    if [ -n "$CHANGE_ID" ]; then
        echo -e "${GREEN}✅ DNS record created/updated: ${FULL_DOMAIN}${NC}"
        echo "   Change ID: $CHANGE_ID"
    else
        echo -e "${RED}❌ Failed to create DNS record${NC}"
        return 1
    fi
    
    echo ""
}

# Create DNS records for all services
create_dns_record "grafana-${ENV}"
create_dns_record "prometheus-${ENV}"
create_dns_record "alertmanager-${ENV}"

# ========================================
# STEP 3: WAIT FOR DNS PROPAGATION
# ========================================
echo -e "${YELLOW}📋 Step 3: Waiting for DNS propagation...${NC}"
echo ""

sleep 10

# ========================================
# STEP 4: VERIFY DNS RECORDS
# ========================================
echo -e "${YELLOW}📋 Step 4: Verifying DNS records...${NC}"
echo ""

for SUBDOMAIN in "grafana-${ENV}" "prometheus-${ENV}" "alertmanager-${ENV}"; do
    FULL_DOMAIN="${SUBDOMAIN}.${DOMAIN}"
    
    DNS_RESULT=$(nslookup "$FULL_DOMAIN" 2>/dev/null | grep -A 1 "Name:" | tail -1 || echo "")
    
    if [ -n "$DNS_RESULT" ]; then
        echo -e "${GREEN}✅ ${FULL_DOMAIN}${NC}"
        echo "   $DNS_RESULT"
    else
        echo -e "${YELLOW}⚠️  ${FULL_DOMAIN} - DNS not yet propagated${NC}"
    fi
    echo ""
done

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✅ DNS RECORDS UPDATED!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

echo -e "${YELLOW}📝 Access URLs:${NC}"
echo ""
echo -e "${GREEN}🔍 Grafana:${NC}"
echo "   https://grafana-${ENV}.${DOMAIN}"
echo "   Username: admin"
echo "   Password: admin123"
echo ""
echo -e "${GREEN}📊 Prometheus:${NC}"
echo "   https://prometheus-${ENV}.${DOMAIN}"
echo ""
echo -e "${GREEN}🚨 AlertManager:${NC}"
echo "   https://alertmanager-${ENV}.${DOMAIN}"
echo ""

echo -e "${YELLOW}⚠️  Note:${NC}"
echo "• DNS propagation may take 1-5 minutes"
echo "• First ALB provision may take 2-3 minutes"
echo "• SSL certificate is wildcard *.${DOMAIN}"
echo ""
