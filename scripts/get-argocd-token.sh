#!/bin/bash
# ========================================
# GET ARGOCD AUTH TOKEN
# ========================================
# This script retrieves ArgoCD server URL and generates auth token
# for CLI access or CI/CD integration
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
SECRETS_DIR="$PROJECT_ROOT/environments/dev/secrets"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}🔐 GET ARGOCD AUTH TOKEN${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# ========================================
# STEP 1: GET ARGOCD SERVER
# ========================================
echo -e "${YELLOW}📋 Step 1: Getting ArgoCD server URL...${NC}"

# Get server from Ingress
ARGOCD_SERVER=$(kubectl get ingress argocd-server -n argocd -o jsonpath='{.spec.rules[0].host}' 2>/dev/null)

if [ -z "$ARGOCD_SERVER" ]; then
    echo -e "${RED}❌ ArgoCD Ingress not found!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ ARGOCD_SERVER=$ARGOCD_SERVER${NC}"
echo ""

# ========================================
# STEP 2: GET ADMIN PASSWORD
# ========================================
echo -e "${YELLOW}📋 Step 2: Getting admin password...${NC}"

ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d)

if [ -z "$ARGOCD_PASSWORD" ]; then
    echo -e "${RED}❌ Admin password not found!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Password retrieved${NC}"
echo ""

# ========================================
# STEP 3: LOGIN AND GET TOKEN
# ========================================
echo -e "${YELLOW}📋 Step 3: Generating auth token...${NC}"

# Get auth token using direct API call (with insecure flag for self-signed cert)
echo "Requesting auth token from ArgoCD API..."
TOKEN_RESPONSE=$(curl -sk -X POST "https://$ARGOCD_SERVER/api/v1/session" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"admin\",\"password\":\"$ARGOCD_PASSWORD\"}" 2>/dev/null)

ARGOCD_AUTH_TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"token":"[^"]*"' | sed 's/"token":"\([^"]*\)"/\1/')

if [ -z "$ARGOCD_AUTH_TOKEN" ]; then
    echo -e "${RED}❌ Failed to get auth token!${NC}"
    echo "Response: $TOKEN_RESPONSE"
    
    # Try alternative method using kubectl exec
    echo -e "${YELLOW}Trying alternative method via kubectl...${NC}"
    POD=$(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].metadata.name}')
    
    if [ ! -z "$POD" ]; then
        ARGOCD_AUTH_TOKEN=$(kubectl exec -n argocd "$POD" -- argocd account generate-token --account admin 2>/dev/null)
    fi
    
    if [ -z "$ARGOCD_AUTH_TOKEN" ]; then
        echo -e "${RED}❌ All methods failed!${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✅ Auth token generated${NC}"
echo ""

# ========================================
# OUTPUT CREDENTIALS
# ========================================
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✅ CREDENTIALS READY!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}📝 Environment Variables:${NC}"
echo ""
echo "export ARGOCD_SERVER=$ARGOCD_SERVER"
echo "export ARGOCD_AUTH_TOKEN=$ARGOCD_AUTH_TOKEN"
echo ""
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}💡 Usage Examples:${NC}"
echo ""
echo "1️⃣  ${YELLOW}Add to your shell profile:${NC}"
echo "   echo 'export ARGOCD_SERVER=$ARGOCD_SERVER' >> ~/.bashrc"
echo "   echo 'export ARGOCD_AUTH_TOKEN=$ARGOCD_AUTH_TOKEN' >> ~/.bashrc"
echo "   source ~/.bashrc"
echo ""
echo "2️⃣  ${YELLOW}Use with curl:${NC}"
echo "   curl -H \"Authorization: Bearer \$ARGOCD_AUTH_TOKEN\" \\"
echo "     https://\$ARGOCD_SERVER/api/v1/applications"
echo ""
echo "3️⃣  ${YELLOW}Use with ArgoCD CLI:${NC}"
echo "   argocd app list --server \$ARGOCD_SERVER --auth-token \$ARGOCD_AUTH_TOKEN --insecure"
echo ""
echo "4️⃣  ${YELLOW}For GitHub Actions:${NC}"
echo "   Add these secrets to your repository:"
echo "   - ARGOCD_SERVER: $ARGOCD_SERVER"
echo "   - ARGOCD_AUTH_TOKEN: (the token above)"
echo ""
echo "5️⃣  ${YELLOW}Test token:${NC}"
echo "   curl -sk -H \"Authorization: Bearer \$ARGOCD_AUTH_TOKEN\" \\"
echo "     https://$ARGOCD_SERVER/api/v1/session/userinfo"
echo ""
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}⚠️  Security Notes:${NC}"
echo "- This token does not expire by default"
echo "- Store it securely (secrets manager, encrypted vault)"
echo "- Don't commit to version control"
echo "- Rotate regularly for security"
echo "- For production, use service account tokens with limited permissions"
echo ""
echo -e "${GREEN}✅ Script complete!${NC}"
echo ""

# ========================================
# SAVE TO FILE (OPTIONAL)
# ========================================
# Create secrets directory if not exists
mkdir -p "$SECRETS_DIR"

# Save credentials to environment-specific file
ENV_FILE="$SECRETS_DIR/argocd-credentials.env"
cat > "$ENV_FILE" << EOF
# ==================================================
# ArgoCD Credentials - Dev Environment
# ==================================================
# Generated: $(date)
# Server: $ARGOCD_SERVER
# 
# ⚠️  SECURITY WARNING:
# - Do not commit this file to version control
# - Keep credentials secure and rotate regularly
# - This file is git-ignored by default
# ==================================================

export ARGOCD_SERVER=$ARGOCD_SERVER
export ARGOCD_AUTH_TOKEN=$ARGOCD_AUTH_TOKEN

# Additional ArgoCD configuration
export ARGOCD_OPTS="--insecure --grpc-web"

# ==================================================
# Usage:
# ==================================================
# 1. Load credentials:
#    source $ENV_FILE
#
# 2. Use with ArgoCD CLI:
#    argocd app list
#
# 3. Use with curl:
#    curl -H "Authorization: Bearer \$ARGOCD_AUTH_TOKEN" \\
#      https://\$ARGOCD_SERVER/api/v1/applications
# ==================================================
EOF
chmod 600 "$ENV_FILE"

echo -e "${GREEN}✅ Credentials saved to: $ENV_FILE${NC}"
echo ""

# Save token only (for CI/CD)
TOKEN_FILE="$SECRETS_DIR/argocd-token.txt"
echo "$ARGOCD_AUTH_TOKEN" > "$TOKEN_FILE"
chmod 600 "$TOKEN_FILE"
echo -e "${GREEN}✅ Token saved to: $TOKEN_FILE${NC}"
echo ""

# Save server URL (for CI/CD)
SERVER_FILE="$SECRETS_DIR/argocd-server.txt"
echo "$ARGOCD_SERVER" > "$SERVER_FILE"
chmod 600 "$SERVER_FILE"
echo -e "${GREEN}✅ Server URL saved to: $SERVER_FILE${NC}"
echo ""

# Create .gitignore in secrets directory
GITIGNORE_FILE="$SECRETS_DIR/.gitignore"
cat > "$GITIGNORE_FILE" << 'EOF'
# Ignore all files in secrets directory
*

# Except this .gitignore
!.gitignore

# And README if exists
!README.md
EOF

echo -e "${GREEN}✅ Created .gitignore in secrets directory${NC}"
echo ""

echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}📁 Files Created:${NC}"
echo ""
echo "1. $ENV_FILE"
echo "   - Full credentials with export statements"
echo "   - Usage: source $ENV_FILE"
echo ""
echo "2. $TOKEN_FILE"
echo "   - Auth token only (for scripts/CI/CD)"
echo "   - Usage: TOKEN=\$(cat $TOKEN_FILE)"
echo ""
echo "3. $SERVER_FILE"
echo "   - Server URL only (for scripts/CI/CD)"
echo "   - Usage: SERVER=\$(cat $SERVER_FILE)"
echo ""
echo -e "${BLUE}========================================${NC}"
echo ""
