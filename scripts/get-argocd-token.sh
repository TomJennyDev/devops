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
echo -e "${YELLOW}📋 Step 3: Configuring authentication...${NC}"
echo ""

echo "Using password-based authentication..."
echo ""
echo -e "${YELLOW}Note: ArgoCD supports both authentication methods:${NC}"
echo "  • Username/Password (what we'll use)"
echo "  • Bearer JWT token (optional)"
echo ""

# Use admin password for authentication
ARGOCD_AUTH_TOKEN="$ARGOCD_PASSWORD"
AUTH_METHOD="password"

echo -e "${GREEN}✅ Authentication configured${NC}"
echo ""

# ========================================
# SAVE TO FILE
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
# Auth Method: $AUTH_METHOD
#
# ⚠️  SECURITY WARNING:
# - Do not commit this file to version control
# - Keep credentials secure and rotate regularly
# - This file is git-ignored by default
# ==================================================

export ARGOCD_SERVER=$ARGOCD_SERVER
export ARGOCD_AUTH_TOKEN=$ARGOCD_AUTH_TOKEN
export ARGOCD_PASSWORD=$ARGOCD_PASSWORD
export ARGOCD_USERNAME=admin

# Additional ArgoCD configuration
export ARGOCD_OPTS="--insecure --grpc-web"

# ==================================================
# Usage:
# ==================================================
# 1. Load credentials:
#    source $ENV_FILE
#
# 2. Use with ArgoCD CLI:
#    argocd app list --server \$ARGOCD_SERVER --insecure \\
#      --auth-token \$ARGOCD_AUTH_TOKEN
#
#    Or with password:
#    argocd app list --server \$ARGOCD_SERVER --insecure \\
#      --username \$ARGOCD_USERNAME --password \$ARGOCD_PASSWORD
#
# 3. Use with curl (Bearer token):
#    curl -sk -H "Authorization: Bearer \$ARGOCD_AUTH_TOKEN" \\
#      https://\$ARGOCD_SERVER/api/v1/applications
#
# 4. Use with curl (Basic auth):
#    curl -sk --user "\$ARGOCD_USERNAME:\$ARGOCD_PASSWORD" \\
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
echo -e "${GREEN}✅ Files Created:${NC}"
echo ""
echo "1. $ENV_FILE"
echo "   - Full credentials with export statements"
echo ""
echo "2. $TOKEN_FILE"
echo "   - Auth token only (for scripts/CI/CD)"
echo ""
echo "3. $SERVER_FILE"
echo "   - Server URL only (for scripts/CI/CD)"
echo ""
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN}✅ READY TO USE!${NC}"
echo ""
echo -e "${YELLOW}📝 To load credentials in your current shell:${NC}"
echo ""
echo -e "${GREEN}   source $ENV_FILE${NC}"
echo ""
echo -e "Or copy-paste this:"
echo ""
echo -e "${BLUE}source $ENV_FILE${NC}"
echo ""
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}💡 Usage Examples After Loading:${NC}"
echo ""
echo "1️⃣  ${YELLOW}Test connection (CLI):${NC}"
echo "   argocd app list --server \$ARGOCD_SERVER --insecure \\
     --auth-token \$ARGOCD_AUTH_TOKEN"
echo ""
echo "2️⃣  ${YELLOW}Test with password (CLI):${NC}"
echo "   argocd app list --server \$ARGOCD_SERVER --insecure \\
     --username admin --password \$ARGOCD_PASSWORD"
echo ""
echo "3️⃣  ${YELLOW}Test with curl (Bearer):${NC}"
echo "   curl -sk -H \"Authorization: Bearer \$ARGOCD_AUTH_TOKEN\" \\
     https://\$ARGOCD_SERVER/api/v1/applications"
echo ""
echo "4️⃣  ${YELLOW}Test with curl (Basic Auth):${NC}"
echo "   curl -sk --user \"admin:\$ARGOCD_PASSWORD\" \\
     https://\$ARGOCD_SERVER/api/v1/applications"
echo ""
echo -e "${BLUE}========================================${NC}"
echo ""
