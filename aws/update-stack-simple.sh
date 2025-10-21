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

echo -e "${GREEN}=== Updating EKS Stack (Simple Method) ===${NC}"
echo ""
echo -e "${YELLOW}Stack: ${STACK_NAME_INFRA}${NC}"
echo -e "${YELLOW}Region: ${AWS_REGION}${NC}"
echo ""

read -p "Do you want to continue? (yes/no) " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Update cancelled."
    exit 0
fi

echo ""
echo -e "${YELLOW}Updating CloudFormation stack...${NC}"

# Use AWS CLI deploy command which handles parameters automatically
aws cloudformation deploy \
    --template-file cloudformation/eks-infrastructure.yaml \
    --stack-name $STACK_NAME_INFRA \
    --capabilities CAPABILITY_NAMED_IAM \
    --region $AWS_REGION \
    --no-fail-on-empty-changeset

echo -e "${GREEN}✓ Stack update completed${NC}"
echo ""

echo -e "${GREEN}=== Verifying Addons ===${NC}"
echo -e "${YELLOW}Checking installed addons...${NC}"
aws eks list-addons \
    --cluster-name $CLUSTER_NAME \
    --region $AWS_REGION \
    --output table || echo -e "${YELLOW}Addons may still be installing...${NC}"

echo ""
echo -e "${GREEN}=== Update Complete ===${NC}"
