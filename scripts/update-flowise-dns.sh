#!/bin/bash
# ========================================
# UPDATE DNS RECORDS FOR FLOWISE
# ========================================
# This script creates/updates Route53 DNS records
# for Flowise environments (dev, staging, production)
# ========================================
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory and paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CLUSTER_INFO_DIR="$PROJECT_ROOT/environments/dev/cluster-info"

# Default values
ENVIRONMENT="${1:-dev}"
VALID_ENVS=("dev" "staging" "production")

# Validate environment
if [[ ! " ${VALID_ENVS[@]} " =~ " ${ENVIRONMENT} " ]]; then
    echo -e "${RED}❌ Invalid environment: $ENVIRONMENT${NC}"
    echo -e "${YELLOW}Usage: $0 [dev|staging|production]${NC}"
    exit 1
fi

# Load cluster info
if [ ! -f "$CLUSTER_INFO_DIR/cluster-env.sh" ]; then
  echo -e "${RED}❌ Cluster info not found!${NC}"
  echo -e "${YELLOW}Run: cd $SCRIPT_DIR && ./export-cluster-info.sh first${NC}"
  exit 1
fi

source "$CLUSTER_INFO_DIR/cluster-env.sh"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}🌐 UPDATE DNS RECORDS FOR FLOWISE${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Environment: ${ENVIRONMENT}${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Set namespace based on environment
NAMESPACE="flowise-${ENVIRONMENT}"
INGRESS_NAME="flowise-ingress"

# Set domain based on environment
BASE_DOMAIN="do2506.click"
if [ "$ENVIRONMENT" = "production" ]; then
    FLOWISE_DOMAIN="flowise.${BASE_DOMAIN}"
else
    FLOWISE_DOMAIN="flowise-${ENVIRONMENT}.${BASE_DOMAIN}"
fi

# ========================================
# STEP 1: CHECK NAMESPACE AND INGRESS
# ========================================
echo -e "${YELLOW}📋 Step 1: Checking Flowise deployment...${NC}"

# Check if namespace exists
if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
    echo -e "${RED}❌ Namespace '$NAMESPACE' not found!${NC}"
    echo -e "${YELLOW}Please deploy Flowise first: ./deploy-flowise.sh${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Namespace exists: $NAMESPACE${NC}"

# Check if Ingress exists
if ! kubectl get ingress "$INGRESS_NAME" -n "$NAMESPACE" &> /dev/null; then
    echo -e "${RED}❌ Ingress '$INGRESS_NAME' not found in namespace '$NAMESPACE'!${NC}"
    echo -e "${YELLOW}Flowise may not be fully deployed yet${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Ingress exists: $INGRESS_NAME${NC}"
echo ""

# ========================================
# STEP 2: GET ALB HOSTNAME FROM INGRESS
# ========================================
echo -e "${YELLOW}📋 Step 2: Getting ALB hostname from Ingress...${NC}"

# Wait for ALB to be provisioned (max 3 minutes)
echo "Waiting for ALB to be provisioned..."
for i in {1..36}; do
    ALB_HOSTNAME=$(kubectl get ingress "$INGRESS_NAME" -n "$NAMESPACE" \
        -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    
    if [ ! -z "$ALB_HOSTNAME" ]; then
        break
    fi
    
    echo -n "."
    sleep 5
done
echo ""

if [ -z "$ALB_HOSTNAME" ]; then
    echo -e "${RED}❌ ALB hostname not found in Ingress after 3 minutes!${NC}"
    echo -e "${YELLOW}Check Ingress status:${NC}"
    kubectl describe ingress "$INGRESS_NAME" -n "$NAMESPACE"
    exit 1
fi

echo -e "${GREEN}✅ ALB Hostname: $ALB_HOSTNAME${NC}"

# Get ALB Hosted Zone ID based on region
case "$EKS_REGION" in
    us-east-1)
        ALB_HOSTED_ZONE_ID="Z35SXDOTRQ7X7K"
        ;;
    us-east-2)
        ALB_HOSTED_ZONE_ID="Z3AADJGX6KTTL2"
        ;;
    us-west-1)
        ALB_HOSTED_ZONE_ID="Z368ELLRRE2KJ0"
        ;;
    us-west-2)
        ALB_HOSTED_ZONE_ID="Z1H1FL5HABSF5"
        ;;
    ap-southeast-1)
        ALB_HOSTED_ZONE_ID="Z1LMS91P8CMLE5"
        ;;
    ap-southeast-2)
        ALB_HOSTED_ZONE_ID="Z1GM3OXH4ZPM65"
        ;;
    ap-northeast-1)
        ALB_HOSTED_ZONE_ID="Z14GRHDCWA56QT"
        ;;
    eu-central-1)
        ALB_HOSTED_ZONE_ID="Z215JYRZR1TBD5"
        ;;
    eu-west-1)
        ALB_HOSTED_ZONE_ID="Z32O12XQLNTSW2"
        ;;
    *)
        echo -e "${RED}❌ Unknown region: $EKS_REGION${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}✅ ALB Hosted Zone ID: $ALB_HOSTED_ZONE_ID${NC}"
echo ""

# ========================================
# STEP 3: GET ROUTE53 HOSTED ZONE
# ========================================
echo -e "${YELLOW}📋 Step 3: Finding Route53 Hosted Zone...${NC}"

# Get Hosted Zone ID
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones \
    --query "HostedZones[?Name=='${BASE_DOMAIN}.'].Id" \
    --output text 2>/dev/null | sed 's/\/hostedzone\///' || echo "")

if [ -z "$HOSTED_ZONE_ID" ]; then
    echo -e "${RED}❌ Hosted Zone not found for domain: $BASE_DOMAIN${NC}"
    echo -e "${YELLOW}Available hosted zones:${NC}"
    aws route53 list-hosted-zones --query "HostedZones[].Name" --output table
    exit 1
fi

echo -e "${GREEN}✅ Hosted Zone ID: $HOSTED_ZONE_ID${NC}"
echo -e "${GREEN}✅ Base Domain: $BASE_DOMAIN${NC}"
echo -e "${GREEN}✅ Flowise Domain: $FLOWISE_DOMAIN${NC}"
echo ""

# ========================================
# STEP 4: CHECK EXISTING DNS RECORD
# ========================================
echo -e "${YELLOW}📋 Step 4: Checking existing DNS records...${NC}"

EXISTING_RECORD=$(aws route53 list-resource-record-sets \
    --hosted-zone-id "$HOSTED_ZONE_ID" \
    --query "ResourceRecordSets[?Name=='${FLOWISE_DOMAIN}.']" \
    --output json)

if [ "$EXISTING_RECORD" != "[]" ]; then
    echo -e "${YELLOW}⚠️  Existing record found - will be updated${NC}"
else
    echo -e "${YELLOW}⚠️  No existing record found for $FLOWISE_DOMAIN (will create new)${NC}"
fi
echo ""

# ========================================
# STEP 5: UPDATE DNS RECORD
# ========================================
echo -e "${YELLOW}📋 Step 5: Creating/Updating DNS record...${NC}"

# Create change batch JSON
CHANGE_BATCH=$(cat <<EOF
{
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "$FLOWISE_DOMAIN",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "$ALB_HOSTED_ZONE_ID",
          "DNSName": "$ALB_HOSTNAME",
          "EvaluateTargetHealth": true
        }
      }
    }
  ]
}
EOF
)

echo "Change batch:"
cat <<EOF
{
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "$FLOWISE_DOMAIN",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "$ALB_HOSTED_ZONE_ID",
          "DNSName": "$ALB_HOSTNAME",
          "EvaluateTargetHealth": true
        }
      }
    }
  ]
}
EOF
echo ""

# Apply the change
echo "Applying DNS change..."
CHANGE_INFO=$(aws route53 change-resource-record-sets \
    --hosted-zone-id "$HOSTED_ZONE_ID" \
    --change-batch "$CHANGE_BATCH" \
    --output json)

CHANGE_ID=$(echo "$CHANGE_INFO" | grep -o '"Id": *"[^"]*"' | head -1 | sed 's/.*"Id": *"\([^"]*\)".*/\1/' | sed 's/\/change\///')

echo -e "${GREEN}✅ DNS change submitted!${NC}"
echo -e "${GREEN}   Change ID: $CHANGE_ID${NC}"
echo ""

# ========================================
# STEP 6: WAIT FOR DNS PROPAGATION
# ========================================
echo -e "${YELLOW}📋 Step 6: Waiting for DNS propagation...${NC}"
echo "This may take 30-60 seconds..."

aws route53 wait resource-record-sets-changed --id "$CHANGE_ID"

echo -e "${GREEN}✅ DNS record propagated!${NC}"
echo ""

# ========================================
# STEP 7: VERIFY DNS RECORD
# ========================================
echo -e "${YELLOW}📋 Step 7: Verifying DNS record...${NC}"

UPDATED_RECORD=$(aws route53 list-resource-record-sets \
    --hosted-zone-id "$HOSTED_ZONE_ID" \
    --query "ResourceRecordSets[?Name=='${FLOWISE_DOMAIN}.']" \
    --output json)

echo "DNS Record:"
echo "  Name: ${FLOWISE_DOMAIN}"
echo "  Type: A (Alias)"
echo "  Target: ${ALB_HOSTNAME}"
echo ""

# ========================================
# OUTPUT SUMMARY
# ========================================
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✅ DNS CONFIGURATION COMPLETE!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}📝 Summary:${NC}"
echo ""
echo "Environment:     $ENVIRONMENT"
echo "Namespace:       $NAMESPACE"
echo "Flowise URL:     https://$FLOWISE_DOMAIN"
echo "ALB Hostname:    $ALB_HOSTNAME"
echo "DNS Record:      $FLOWISE_DOMAIN → $ALB_HOSTNAME"
echo ""
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}🧪 Testing:${NC}"
echo ""
echo "1️⃣  ${YELLOW}Test DNS resolution:${NC}"
echo "   nslookup $FLOWISE_DOMAIN"
echo "   dig $FLOWISE_DOMAIN"
echo ""
echo "2️⃣  ${YELLOW}Wait for SSL certificate (may take 1-2 minutes):${NC}"
echo "   kubectl get certificate -n $NAMESPACE"
echo ""
echo "3️⃣  ${YELLOW}Check ingress status:${NC}"
echo "   kubectl describe ingress $INGRESS_NAME -n $NAMESPACE"
echo ""
echo "4️⃣  ${YELLOW}Access Flowise UI:${NC}"
echo "   https://$FLOWISE_DOMAIN"
echo ""
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}⚠️  Notes:${NC}"
echo "- DNS propagation may take a few minutes globally"
echo "- SSL certificate is automatically provisioned by cert-manager"
echo "- First request may take 30-60 seconds while certificate is issued"
echo "- Check ALB target groups health in AWS Console if issues persist"
echo ""
echo -e "${GREEN}✅ Script complete!${NC}"
echo ""
