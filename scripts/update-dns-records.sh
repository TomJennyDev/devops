#!/bin/bash
# ========================================
# UPDATE DNS RECORDS FOR ARGOCD
# ========================================
# This script automatically updates Route53 DNS records
# to point to the current ArgoCD ALB
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

# Load cluster info
if [ ! -f "$CLUSTER_INFO_DIR/cluster-env.sh" ]; then
  echo -e "${RED}❌ Cluster info not found!${NC}"
  echo -e "${YELLOW}Run: cd $SCRIPT_DIR && ./export-cluster-info.sh first${NC}"
  exit 1
fi

source "$CLUSTER_INFO_DIR/cluster-env.sh"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}🌐 UPDATE DNS RECORDS FOR ARGOCD${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# ========================================
# STEP 1: GET ALB HOSTNAME FROM INGRESS
# ========================================
echo -e "${YELLOW}📋 Step 1: Getting ALB hostname from Ingress...${NC}"

# Check if Ingress exists
if ! kubectl get ingress argocd-server -n argocd &> /dev/null; then
    echo -e "${RED}❌ ArgoCD Ingress not found!${NC}"
    echo -e "${YELLOW}Please deploy ArgoCD first: ./deploy-argocd.sh${NC}"
    exit 1
fi

# Get ALB hostname
ALB_HOSTNAME=$(kubectl get ingress argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

if [ -z "$ALB_HOSTNAME" ]; then
    echo -e "${RED}❌ ALB hostname not found in Ingress!${NC}"
    echo -e "${YELLOW}Wait for ALB to be provisioned (may take 2-3 minutes)${NC}"
    exit 1
fi

echo -e "${GREEN}✅ ALB Hostname: $ALB_HOSTNAME${NC}"

# Get ALB Hosted Zone ID (always Z1LMS91P8CMLE5 for ap-southeast-1)
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
# STEP 2: GET ROUTE53 HOSTED ZONE
# ========================================
echo -e "${YELLOW}📋 Step 2: Finding Route53 Hosted Zone...${NC}"

# Domain from ArgoCD values
DOMAIN="do2506.click"
ARGOCD_DOMAIN="argocd.$DOMAIN"

# Get Hosted Zone ID
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones \
    --query "HostedZones[?Name=='${DOMAIN}.'].Id" \
    --output text | sed 's/\/hostedzone\///')

if [ -z "$HOSTED_ZONE_ID" ]; then
    echo -e "${RED}❌ Hosted Zone not found for domain: $DOMAIN${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Hosted Zone ID: $HOSTED_ZONE_ID${NC}"
echo -e "${GREEN}✅ Domain: $DOMAIN${NC}"
echo ""

# ========================================
# STEP 3: CHECK EXISTING DNS RECORD
# ========================================
echo -e "${YELLOW}📋 Step 3: Checking existing DNS records...${NC}"

EXISTING_RECORD=$(aws route53 list-resource-record-sets \
    --hosted-zone-id "$HOSTED_ZONE_ID" \
    --query "ResourceRecordSets[?Name=='${ARGOCD_DOMAIN}.']" \
    --output json)

if [ "$EXISTING_RECORD" != "[]" ]; then
    echo -e "${YELLOW}⚠️  Existing record found:${NC}"
    echo "$EXISTING_RECORD"
else
    echo -e "${YELLOW}⚠️  No existing record found for $ARGOCD_DOMAIN${NC}"
fi
echo ""

# ========================================
# STEP 4: UPDATE DNS RECORD
# ========================================
echo -e "${YELLOW}📋 Step 4: Updating DNS record...${NC}"

# Create change batch JSON
CHANGE_BATCH=$(cat <<EOF
{
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "$ARGOCD_DOMAIN",
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

echo "Change Batch:"
echo "$CHANGE_BATCH"
echo ""

# Execute Route53 change
CHANGE_INFO=$(aws route53 change-resource-record-sets \
    --hosted-zone-id "$HOSTED_ZONE_ID" \
    --change-batch "$CHANGE_BATCH" \
    --output json)

CHANGE_ID=$(echo "$CHANGE_INFO" | grep -o '"Id": *"[^"]*"' | head -1 | sed 's/"Id": *"\([^"]*\)"/\1/' | sed 's/\/change\///')
CHANGE_STATUS=$(echo "$CHANGE_INFO" | grep -o '"Status": *"[^"]*"' | head -1 | sed 's/"Status": *"\([^"]*\)"/\1/')

echo -e "${GREEN}✅ DNS change submitted!${NC}"
echo "Change ID: $CHANGE_ID"
echo "Status: $CHANGE_STATUS"
echo ""

# ========================================
# STEP 5: WAIT FOR DNS PROPAGATION
# ========================================
echo -e "${YELLOW}📋 Step 5: Waiting for DNS propagation...${NC}"

echo "Checking Route53 change status..."
for i in {1..12}; do
    CURRENT_STATUS=$(aws route53 get-change --id "$CHANGE_ID" --query 'ChangeInfo.Status' --output text)

    if [ "$CURRENT_STATUS" == "INSYNC" ]; then
        echo -e "${GREEN}✅ Route53 change completed!${NC}"
        break
    fi

    echo "Status: $CURRENT_STATUS (attempt $i/12)"
    sleep 5
done

echo ""
echo -e "${YELLOW}⏳ Waiting for DNS cache to update (30 seconds)...${NC}"
sleep 30

echo ""

# ========================================
# STEP 6: VERIFY DNS RESOLUTION
# ========================================
echo -e "${YELLOW}📋 Step 6: Verifying DNS resolution...${NC}"

echo "Testing DNS lookup..."
DNS_RESULT=$(nslookup "$ARGOCD_DOMAIN" 8.8.8.8 2>&1 || true)

if echo "$DNS_RESULT" | grep -q "NXDOMAIN\|can't find"; then
    echo -e "${YELLOW}⚠️  DNS not resolved yet. May take up to 5 minutes.${NC}"
    echo "$DNS_RESULT"
else
    echo -e "${GREEN}✅ DNS resolved successfully!${NC}"
    echo "$DNS_RESULT" | grep -A 2 "Name:"
fi

echo ""

# ========================================
# STEP 7: TEST HTTPS ACCESS
# ========================================
echo -e "${YELLOW}📋 Step 7: Testing HTTPS access...${NC}"

echo "Testing HTTPS connection..."
HTTP_STATUS=$(curl -k -s -o /dev/null -w "%{http_code}" "https://$ARGOCD_DOMAIN" --max-time 10 || echo "timeout")

if [ "$HTTP_STATUS" == "200" ] || [ "$HTTP_STATUS" == "307" ] || [ "$HTTP_STATUS" == "301" ]; then
    echo -e "${GREEN}✅ HTTPS access successful! (Status: $HTTP_STATUS)${NC}"
elif [ "$HTTP_STATUS" == "timeout" ]; then
    echo -e "${YELLOW}⚠️  Connection timeout. ALB may still be warming up.${NC}"
else
    echo -e "${YELLOW}⚠️  HTTP Status: $HTTP_STATUS${NC}"
fi

echo ""

# ========================================
# FINAL SUMMARY
# ========================================
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✅ DNS UPDATE COMPLETE!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}📊 Configuration Summary:${NC}"
echo ""
echo "Domain: $ARGOCD_DOMAIN"
echo "ALB Hostname: $ALB_HOSTNAME"
echo "ALB Hosted Zone: $ALB_HOSTED_ZONE_ID"
echo "Route53 Zone: $HOSTED_ZONE_ID"
echo "Change ID: $CHANGE_ID"
echo ""
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}📝 Next Steps:${NC}"
echo ""
echo "1️⃣  ${YELLOW}Access ArgoCD UI:${NC}"
echo "   https://$ARGOCD_DOMAIN"
echo ""
echo "2️⃣  ${YELLOW}Get admin password:${NC}"
echo "   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d && echo"
echo ""
echo "3️⃣  ${YELLOW}Login credentials:${NC}"
echo "   Username: admin"
echo "   Password: (from command above)"
echo ""
echo "4️⃣  ${YELLOW}If DNS not working yet:${NC}"
echo "   - Wait 2-5 minutes for DNS propagation"
echo "   - Clear your browser cache"
echo "   - Try incognito/private window"
echo "   - Test with: curl -Lk https://$ARGOCD_DOMAIN"
echo ""
echo "5️⃣  ${YELLOW}Direct ALB access (bypass DNS):${NC}"
echo "   https://$ALB_HOSTNAME"
echo ""
echo -e "${GREEN}✅ Script complete!${NC}"
echo ""
