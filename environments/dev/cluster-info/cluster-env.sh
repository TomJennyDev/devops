#!/bin/bash
# ==================================================
# EKS Cluster Environment Variables
# Usage: source cluster-env.sh
# Generated: Sat, Dec 13, 2025  1:27:18 PM
# ==================================================

export EKS_CLUSTER_NAME="my-eks-dev"
export EKS_CLUSTER_ENDPOINT="https://BF4C18058F438CD9909534B541FD16A8.gr7.ap-southeast-1.eks.amazonaws.com"
export EKS_REGION="ap-southeast-1"
export AWS_ACCOUNT_ID="372836560690"
export VPC_ID="vpc-0e6ca42c7851c46c4"
export NODE_GROUP_ID="my-eks-dev:dev-workers"
export ALB_CONTROLLER_ROLE_ARN="arn:aws:iam::372836560690:role/my-eks-dev-aws-load-balancer-controller"
export EXTERNAL_DNS_ROLE_ARN=""
export ECR_FLOWISE_SERVER="372836560690.dkr.ecr.ap-southeast-1.amazonaws.com/flowise-server"
export ECR_FLOWISE_UI="372836560690.dkr.ecr.ap-southeast-1.amazonaws.com/flowise-ui"

echo "✓ Cluster environment variables loaded:"
echo "  EKS_CLUSTER_NAME: $EKS_CLUSTER_NAME"
echo "  EKS_REGION: $EKS_REGION"
echo "  AWS_ACCOUNT_ID: $AWS_ACCOUNT_ID"
