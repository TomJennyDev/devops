#!/bin/bash
# ==================================================
# Export Terraform Outputs to ArgoCD Config Files
# ==================================================
# This script exports Terraform outputs to various formats
# for easy consumption by ArgoCD and other tools

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DEV_DIR="$SCRIPT_DIR/../terraform-eks/environments/dev"
OUTPUT_DIR="$SCRIPT_DIR/../environments/dev/cluster-info"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Exporting Terraform Outputs${NC}"
echo -e "${BLUE}========================================${NC}"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# ==================================================
# 1. Export as JSON
# ==================================================
echo -e "\n${GREEN}1. Exporting to JSON...${NC}"

# Change to terraform dev environment directory
cd "$TERRAFORM_DEV_DIR"

terraform output -json > "$OUTPUT_DIR/terraform-outputs.json"
echo -e "   ✓ Saved to: $OUTPUT_DIR/terraform-outputs.json"

# ==================================================
# 2. Export as YAML for ArgoCD
# ==================================================
echo -e "\n${GREEN}2. Exporting to YAML...${NC}"

# Extract values
CLUSTER_NAME=$(terraform output -raw cluster_id 2>/dev/null || echo "")
CLUSTER_ENDPOINT=$(terraform output -raw cluster_endpoint 2>/dev/null || echo "")
VPC_ID=$(terraform output -raw vpc_id 2>/dev/null || echo "")
NODE_GROUP_ID=$(terraform output -raw node_group_id 2>/dev/null || echo "")
ALB_ROLE_ARN=$(terraform output -raw aws_load_balancer_controller_role_arn 2>/dev/null || echo "")
EXTERNAL_DNS_ROLE_ARN=$(terraform output -raw external_dns_role_arn 2>/dev/null || echo "")
ECR_FLOWISE_SERVER=$(terraform output -raw ecr_flowise_server_url 2>/dev/null || echo "")
ECR_FLOWISE_UI=$(terraform output -raw ecr_flowise_ui_url 2>/dev/null || echo "")
AWS_REGION="ap-southeast-1"
AWS_ACCOUNT_ID=$(echo "$ECR_FLOWISE_SERVER" | cut -d'.' -f1)

cat > "$OUTPUT_DIR/cluster-info.yaml" <<EOF
# ==================================================
# EKS Cluster Information
# Generated: $(date)
# ==================================================
cluster:
  name: ${CLUSTER_NAME}
  endpoint: ${CLUSTER_ENDPOINT}
  region: ${AWS_REGION}
  accountId: ${AWS_ACCOUNT_ID}

network:
  vpcId: ${VPC_ID}

compute:
  nodeGroupId: ${NODE_GROUP_ID}

iam:
  awsLoadBalancerControllerRoleArn: ${ALB_ROLE_ARN}
  externalDnsRoleArn: ${EXTERNAL_DNS_ROLE_ARN}

ecr:
  flowiseServer: ${ECR_FLOWISE_SERVER}
  flowiseUi: ${ECR_FLOWISE_UI}

kubectl:
  configCommand: aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}
EOF

echo -e "   ✓ Saved to: $OUTPUT_DIR/cluster-info.yaml"

# ==================================================
# 3. Export as Shell Environment Variables
# ==================================================
echo -e "\n${GREEN}3. Exporting as environment variables...${NC}"

cat > "$OUTPUT_DIR/cluster-env.sh" <<EOF
#!/bin/bash
# ==================================================
# EKS Cluster Environment Variables
# Usage: source cluster-env.sh
# Generated: $(date)
# ==================================================

export EKS_CLUSTER_NAME="${CLUSTER_NAME}"
export EKS_CLUSTER_ENDPOINT="${CLUSTER_ENDPOINT}"
export EKS_REGION="${AWS_REGION}"
export AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID}"
export VPC_ID="${VPC_ID}"
export NODE_GROUP_ID="${NODE_GROUP_ID}"
export ALB_CONTROLLER_ROLE_ARN="${ALB_ROLE_ARN}"
export EXTERNAL_DNS_ROLE_ARN="${EXTERNAL_DNS_ROLE_ARN}"
export ECR_FLOWISE_SERVER="${ECR_FLOWISE_SERVER}"
export ECR_FLOWISE_UI="${ECR_FLOWISE_UI}"

echo "✓ Cluster environment variables loaded:"
echo "  EKS_CLUSTER_NAME: \$EKS_CLUSTER_NAME"
echo "  EKS_REGION: \$EKS_REGION"
echo "  AWS_ACCOUNT_ID: \$AWS_ACCOUNT_ID"
EOF

chmod +x "$OUTPUT_DIR/cluster-env.sh"
echo -e "   ✓ Saved to: $OUTPUT_DIR/cluster-env.sh"
echo -e "   ${YELLOW}Usage: source $OUTPUT_DIR/cluster-env.sh${NC}"

# ==================================================
# 4. Export ArgoCD Values File
# ==================================================
echo -e "\n${GREEN}4. Creating ArgoCD values file...${NC}"

cat > "$OUTPUT_DIR/argocd-cluster-values.yaml" <<EOF
# ==================================================
# ArgoCD Values - Cluster Specific
# Generated: $(date)
# ==================================================

# AWS Load Balancer Controller
aws-load-balancer-controller:
  clusterName: ${CLUSTER_NAME}
  region: ${AWS_REGION}
  vpcId: ${VPC_ID}
  serviceAccount:
    annotations:
      eks.amazonaws.com/role-arn: ${ALB_ROLE_ARN}

# External DNS (if needed)
external-dns:
  serviceAccount:
    annotations:
      eks.amazonaws.com/role-arn: ${EXTERNAL_DNS_ROLE_ARN}

# Image Repository URLs
imageRepository:
  flowiseServer: ${ECR_FLOWISE_SERVER}
  flowiseUi: ${ECR_FLOWISE_UI}
EOF

echo -e "   ✓ Saved to: $OUTPUT_DIR/argocd-cluster-values.yaml"

# ==================================================
# 5. Export Kubernetes ConfigMap
# ==================================================
echo -e "\n${GREEN}5. Creating Kubernetes ConfigMap...${NC}"

cat > "$OUTPUT_DIR/cluster-info-configmap.yaml" <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-info
  namespace: argocd
  labels:
    app: argocd
    managed-by: terraform
data:
  cluster.name: "${CLUSTER_NAME}"
  cluster.endpoint: "${CLUSTER_ENDPOINT}"
  cluster.region: "${AWS_REGION}"
  aws.accountId: "${AWS_ACCOUNT_ID}"
  vpc.id: "${VPC_ID}"
  nodeGroup.id: "${NODE_GROUP_ID}"
  ecr.flowiseServer: "${ECR_FLOWISE_SERVER}"
  ecr.flowiseUi: "${ECR_FLOWISE_UI}"
EOF

echo -e "   ✓ Saved to: $OUTPUT_DIR/cluster-info-configmap.yaml"
echo -e "   ${YELLOW}To apply: kubectl apply -f $OUTPUT_DIR/cluster-info-configmap.yaml${NC}"

# ==================================================
# 6. Create Quick Reference Card
# ==================================================
echo -e "\n${GREEN}6. Creating quick reference card...${NC}"

cat > "$OUTPUT_DIR/README.md" <<EOF
# EKS Cluster Information

**Generated:** $(date)

## Cluster Details

| Property | Value |
|----------|-------|
| Cluster Name | \`${CLUSTER_NAME}\` |
| Region | \`${AWS_REGION}\` |
| Account ID | \`${AWS_ACCOUNT_ID}\` |
| VPC ID | \`${VPC_ID}\` |
| Node Group | \`${NODE_GROUP_ID}\` |

## Endpoints

**EKS API Server:**
\`\`\`
${CLUSTER_ENDPOINT}
\`\`\`

## IAM Roles

**AWS Load Balancer Controller:**
\`\`\`
${ALB_ROLE_ARN}
\`\`\`

**External DNS:**
\`\`\`
${EXTERNAL_DNS_ROLE_ARN}
\`\`\`

## ECR Repositories

**Flowise Server:**
\`\`\`
${ECR_FLOWISE_SERVER}
\`\`\`

**Flowise UI:**
\`\`\`
${ECR_FLOWISE_UI}
\`\`\`

## Quick Commands

### Configure kubectl
\`\`\`bash
aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}
\`\`\`

### Load environment variables
\`\`\`bash
source cluster-env.sh
\`\`\`

### Apply ConfigMap
\`\`\`bash
kubectl apply -f cluster-info-configmap.yaml
\`\`\`

### Login to ECR
\`\`\`bash
aws ecr get-login-password --region ${AWS_REGION} | \\
  docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
\`\`\`

### Push image to ECR
\`\`\`bash
# Tag image
docker tag flowise-server:latest ${ECR_FLOWISE_SERVER}:latest

# Push image
docker push ${ECR_FLOWISE_SERVER}:latest
\`\`\`

## Files in this directory

- \`terraform-outputs.json\` - Raw Terraform outputs in JSON
- \`cluster-info.yaml\` - Structured cluster information
- \`cluster-env.sh\` - Shell environment variables
- \`argocd-cluster-values.yaml\` - ArgoCD-ready values file
- \`cluster-info-configmap.yaml\` - Kubernetes ConfigMap
- \`README.md\` - This file

## Usage in ArgoCD Applications

### Reference ECR images
\`\`\`yaml
spec:
  source:
    helm:
      values: |
        image:
          repository: ${ECR_FLOWISE_SERVER}
          tag: latest
\`\`\`

### Use ConfigMap values
\`\`\`yaml
env:
  - name: CLUSTER_NAME
    valueFrom:
      configMapKeyRef:
        name: cluster-info
        key: cluster.name
\`\`\`

### Use as Helm values
\`\`\`bash
helm install my-app ./chart \\
  -f argocd-cluster-values.yaml
\`\`\`
EOF

echo -e "   ✓ Saved to: $OUTPUT_DIR/README.md"

# ==================================================
# Summary
# ==================================================
echo -e "\n${BLUE}========================================${NC}"
echo -e "${GREEN}✓ Export Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "\n${YELLOW}Files created in: $OUTPUT_DIR${NC}"
echo -e "
  1. terraform-outputs.json       - Raw JSON output
  2. cluster-info.yaml            - Structured YAML
  3. cluster-env.sh               - Environment variables
  4. argocd-cluster-values.yaml   - ArgoCD values
  5. cluster-info-configmap.yaml  - Kubernetes ConfigMap
  6. README.md                    - Quick reference
"

echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Review: cat $OUTPUT_DIR/README.md"
echo -e "  2. Load vars: source $OUTPUT_DIR/cluster-env.sh"
echo -e "  3. Apply ConfigMap: kubectl apply -f $OUTPUT_DIR/cluster-info-configmap.yaml"
echo -e "  4. Deploy ArgoCD with values: helm install argocd ... -f $OUTPUT_DIR/argocd-cluster-values.yaml"
echo ""
