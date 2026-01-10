#!/bin/bash
set -e

# =========================================
# Update WAF ARN in Ingress after Terraform deployment
# =========================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TERRAFORM_DIR="$REPO_ROOT/terraform-eks/environments/dev"
INGRESS_FILE="$REPO_ROOT/argocd/apps/flowise/overlays/dev/ingress.yaml"

echo "========================================="
echo "Update WAF ARN in Flowise Ingress"
echo "========================================="

# Step 1: Get WAF ARN from Terraform output
echo "[1/4] Getting WAF ARN from Terraform..."
cd "$TERRAFORM_DIR"

if [ ! -d ".terraform" ]; then
    echo "❌ Error: Terraform not initialized. Run 'terraform init' first."
    exit 1
fi

# Get WAF ARN and suppress warnings
WAF_ARN=$(terraform output -raw waf_web_acl_arn 2>&1 | grep -E '^arn:aws:wafv2:' || echo "")

if [ -z "$WAF_ARN" ]; then
    echo "⚠️  WAF not enabled or not deployed. Skipping update."
    exit 0
fi

# Validate ARN format
if [[ ! "$WAF_ARN" =~ ^arn:aws:wafv2: ]]; then
    echo "❌ Error: Invalid WAF ARN format: $WAF_ARN"
    exit 1
fi

echo "✓ WAF ARN: $WAF_ARN"

# Step 2: Check if ingress file exists
echo -e "\n[2/4] Checking ingress file..."
if [ ! -f "$INGRESS_FILE" ]; then
    echo "❌ Error: Ingress file not found: $INGRESS_FILE"
    exit 1
fi
echo "✓ Ingress file found"

# Step 3: Update WAF ARN in ingress
echo -e "\n[3/4] Updating WAF ARN in ingress..."

# Check if WAF annotation exists
if grep -q "alb.ingress.kubernetes.io/wafv2-acl-arn:" "$INGRESS_FILE"; then
    # Update existing annotation
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s|alb.ingress.kubernetes.io/wafv2-acl-arn:.*|alb.ingress.kubernetes.io/wafv2-acl-arn: $WAF_ARN|" "$INGRESS_FILE"
    else
        # Linux/Windows Git Bash
        sed -i "s|alb.ingress.kubernetes.io/wafv2-acl-arn:.*|alb.ingress.kubernetes.io/wafv2-acl-arn: $WAF_ARN|" "$INGRESS_FILE"
    fi
    echo "✓ Updated existing WAF annotation"
else
    echo "⚠️  WAF annotation not found in ingress. Please add it manually."
    exit 1
fi

# Step 4: Commit changes
echo -e "\n[4/4] Committing changes..."
cd "$REPO_ROOT"

if git diff --quiet "$INGRESS_FILE"; then
    echo "✓ No changes detected (WAF ARN already up-to-date)"
else
    git add "$INGRESS_FILE"
    git commit -m "chore: update WAF ARN in flowise-dev ingress [automated]"
    echo "✓ Changes committed"

    read -p "Push changes to remote? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git push origin main
        echo "✓ Changes pushed to remote"
    else
        echo "⚠️  Changes committed locally but not pushed"
    fi
fi

echo -e "\n========================================="
echo "✓ WAF ARN update complete!"
echo "========================================="
