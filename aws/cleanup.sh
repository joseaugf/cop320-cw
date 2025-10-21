#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

echo -e "${RED}=== Petshop Observability Demo - AWS Cleanup ===${NC}"
echo -e "${YELLOW}WARNING: This will delete all resources created by the deployment!${NC}"
echo ""

read -p "Are you sure you want to continue? (yes/no) " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
echo -e "${YELLOW}Starting cleanup...${NC}"

# Delete Kubernetes resources
echo -e "${YELLOW}Step 1: Deleting Kubernetes resources...${NC}"
kubectl delete namespace petshop-demo --ignore-not-found=true || echo -e "${YELLOW}Namespace may not exist${NC}"
echo -e "${GREEN}✓ Kubernetes resources deleted${NC}"
echo ""

# Delete IRSA
echo -e "${YELLOW}Step 2: Deleting IAM Service Account...${NC}"
eksctl delete iamserviceaccount \
    --name adot-collector \
    --namespace petshop-demo \
    --cluster $CLUSTER_NAME \
    --region $AWS_REGION || echo -e "${YELLOW}IRSA may not exist${NC}"
echo -e "${GREEN}✓ IRSA deleted${NC}"
echo ""

# Delete CI/CD stack
echo -e "${YELLOW}Step 3: Deleting CI/CD Pipeline stack...${NC}"
aws cloudformation delete-stack \
    --stack-name $STACK_NAME_CICD \
    --region $AWS_REGION 2>/dev/null || echo -e "${YELLOW}CI/CD stack may not exist${NC}"

# Wait for CI/CD stack deletion
aws cloudformation wait stack-delete-complete \
    --stack-name $STACK_NAME_CICD \
    --region $AWS_REGION 2>/dev/null || echo -e "${YELLOW}CI/CD stack deletion completed or didn't exist${NC}"
echo -e "${GREEN}✓ CI/CD stack deleted${NC}"
echo ""

# Delete infrastructure stack
echo -e "${YELLOW}Step 4: Deleting Infrastructure stack...${NC}"
echo -e "${YELLOW}This may take 15-20 minutes...${NC}"
aws cloudformation delete-stack \
    --stack-name $STACK_NAME_INFRA \
    --region $AWS_REGION

# Wait for infrastructure stack deletion
aws cloudformation wait stack-delete-complete \
    --stack-name $STACK_NAME_INFRA \
    --region $AWS_REGION
echo -e "${GREEN}✓ Infrastructure stack deleted${NC}"
echo ""

echo -e "${GREEN}=== Cleanup Complete ===${NC}"
echo -e "${GREEN}All resources have been deleted.${NC}"
echo ""
