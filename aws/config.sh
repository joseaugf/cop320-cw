#!/bin/bash

# AWS Configuration
# You can override these by setting environment variables before running the scripts
# Example: export AWS_REGION=sa-east-1 && ./deploy.sh

# AWS Region - Change this to your preferred region
export AWS_REGION="${AWS_REGION:-us-east-2}"

# EKS Cluster Name
export CLUSTER_NAME="${CLUSTER_NAME:-petshop-demo-eks}"

# CloudFormation Stack Names
export STACK_NAME_INFRA="${STACK_NAME_INFRA:-petshop-observability-demo-v2}"
export STACK_NAME_CICD="${STACK_NAME_CICD:-petshop-observability-demo-cicd-v2}"

# Old stack name (for cleanup)
export OLD_STACK_NAME="${OLD_STACK_NAME:-petshop-demo-eks-infrastructure}"

echo "Configuration loaded:"
echo "  AWS Region: $AWS_REGION"
echo "  Cluster Name: $CLUSTER_NAME"
echo "  Infrastructure Stack: $STACK_NAME_INFRA"
echo "  CI/CD Stack: $STACK_NAME_CICD"
