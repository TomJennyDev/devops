#!/bin/bash
# ========================================
# TEST PLAN FOR SPECIFIC ENVIRONMENT
# ========================================
# Test terraform plan cho 1 environment cụ thể

set -e

ENV=$1

if [ -z "$ENV" ]; then
    echo "Usage: $0 <environment>"
    echo "Example: $0 dev"
    echo ""
    echo "Available environments: dev, staging, prod"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_DIR="$PROJECT_ROOT/environments/$ENV"

if [ ! -d "$ENV_DIR" ]; then
    echo "❌ Environment '$ENV' not found!"
    exit 1
fi

echo "=================================================="
echo "🧪 Testing Environment: $ENV"
echo "=================================================="
echo ""

cd "$ENV_DIR"

echo "Step 1: Initialize Terraform..."
echo "--------------------------------------------------"
terraform init -backend=false

echo ""
echo "Step 2: Validate Configuration..."
echo "--------------------------------------------------"
terraform validate

echo ""
echo "Step 3: Check Formatting..."
echo "--------------------------------------------------"
terraform fmt -check -recursive

echo ""
echo "Step 4: Generate Plan (dry-run)..."
echo "--------------------------------------------------"
echo "⚠️  This will show what would be created (without backend state)"
echo ""
terraform plan

echo ""
echo "=================================================="
echo "✅ Test completed for: $ENV"
echo "=================================================="
