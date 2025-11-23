#!/bin/bash
# ========================================
# VALIDATE ALL ENVIRONMENTS
# ========================================
# Script để test tất cả environments

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=================================================="
echo "🔍 TERRAFORM CONFIGURATION VALIDATION"
echo "=================================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track results
PASSED=0
FAILED=0
ENVIRONMENTS=("dev" "staging" "prod")

echo "📦 Step 1: Validating Root Module..."
echo "--------------------------------------------------"
cd "$PROJECT_ROOT"

# Check if all required files exist
echo "✓ Checking required files..."
REQUIRED_FILES=(
    "main.tf"
    "variables.tf"
    "outputs.tf"
    "versions.tf"
)

REQUIRED_MODULES=(
    "modules/vpc"
    "modules/iam"
    "modules/eks"
    "modules/security-groups"
    "modules/node-groups"
    "modules/alb-controller"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo -e "  ${GREEN}✓${NC} $file"
    else
        echo -e "  ${RED}✗${NC} $file (missing)"
        ((FAILED++))
    fi
done

echo ""
echo "✓ Checking required modules..."
for module in "${REQUIRED_MODULES[@]}"; do
    if [ -d "$module" ]; then
        echo -e "  ${GREEN}✓${NC} $module"
    else
        echo -e "  ${RED}✗${NC} $module (missing)"
        ((FAILED++))
    fi
done

echo ""
echo "🌍 Step 2: Validating Environments..."
echo "--------------------------------------------------"

for env in "${ENVIRONMENTS[@]}"; do
    echo ""
    echo "📂 Testing: $env"
    echo "  ────────────────────────────"
    
    ENV_DIR="$PROJECT_ROOT/environments/$env"
    
    if [ ! -d "$ENV_DIR" ]; then
        echo -e "  ${RED}✗ Directory not found${NC}"
        ((FAILED++))
        continue
    fi
    
    cd "$ENV_DIR"
    
    # Check required files
    echo "  ✓ Checking files..."
    ENV_FILES=("main.tf" "variables.tf" "outputs.tf" "versions.tf" "backend.tf" "terraform.tfvars")
    FILE_OK=true
    
    for file in "${ENV_FILES[@]}"; do
        if [ -f "$file" ]; then
            echo -e "    ${GREEN}✓${NC} $file"
        else
            echo -e "    ${RED}✗${NC} $file (missing)"
            FILE_OK=false
        fi
    done
    
    if [ "$FILE_OK" = false ]; then
        ((FAILED++))
        continue
    fi
    
    # Initialize terraform (without backend)
    echo "  ✓ Initializing Terraform..."
    if terraform init -backend=false > /dev/null 2>&1; then
        echo -e "    ${GREEN}✓${NC} Init successful"
    else
        echo -e "    ${RED}✗${NC} Init failed"
        ((FAILED++))
        continue
    fi
    
    # Validate configuration
    echo "  ✓ Validating configuration..."
    if terraform validate > /dev/null 2>&1; then
        echo -e "    ${GREEN}✓${NC} Validation passed"
        ((PASSED++))
    else
        echo -e "    ${RED}✗${NC} Validation failed"
        terraform validate
        ((FAILED++))
    fi
    
    # Check for format issues
    echo "  ✓ Checking formatting..."
    if terraform fmt -check > /dev/null 2>&1; then
        echo -e "    ${GREEN}✓${NC} Formatting correct"
    else
        echo -e "    ${YELLOW}⚠${NC} Formatting issues (run 'terraform fmt')"
    fi
done

echo ""
echo "=================================================="
echo "📊 VALIDATION SUMMARY"
echo "=================================================="
echo -e "${GREEN}✓ Passed:${NC} $PASSED environments"
echo -e "${RED}✗ Failed:${NC} $FAILED environments"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All validations passed!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Create S3 buckets for state storage"
    echo "  2. Update backend.tf with your bucket names"
    echo "  3. Run 'terraform init' in each environment"
    echo "  4. Run 'terraform plan' to review changes"
    exit 0
else
    echo -e "${RED}❌ Some validations failed!${NC}"
    echo "Please fix the errors above before proceeding."
    exit 1
fi
