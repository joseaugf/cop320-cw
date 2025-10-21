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

echo -e "${GREEN}=== Updating EKS Stack with Addons ===${NC}"
echo ""
echo -e "${YELLOW}This will add the following EKS Addons:${NC}"
echo "  1. VPC CNI (v1.15.1)"
echo "  2. EBS CSI Driver (v1.25.0)"
echo "  3. ADOT - AWS Distro for OpenTelemetry (v0.88.0)"
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

# Use aws cloudformation deploy which handles parameters automatically
aws cloudformation deploy \
    --template-file cloudformation/eks-infrastructure.yaml \
    --stack-name $STACK_NAME_INFRA \
    --capabilities CAPABILITY_NAMED_IAM \
    --region $AWS_REGION \
    --no-fail-on-empty-changeset

echo -e "${GREEN}✓ Stack update initiated${NC}"
echo ""
echo -e "${YELLOW}Waiting for stack update to complete (this may take 10-15 minutes)...${NC}"
echo -e "${YELLOW}You can press Ctrl+C to stop waiting (update will continue in background)${NC}"
echo ""

# Wait for stack update
aws cloudformation wait stack-update-complete \
    --stack-name $STACK_NAME_INFRA \
    --region $AWS_REGION && \
    echo -e "${GREEN}✓ Stack update completed successfully${NC}" || \
    echo -e "${YELLOW}Stack update may still be in progress. Check AWS Console for status.${NC}"

echo ""
echo -e "${GREEN}=== Verifying Addons ===${NC}"

# Verify addons
echo -e "${YELLOW}Checking installed addons...${NC}"
aws eks list-addons \
    --cluster-name $CLUSTER_NAME \
    --region $AWS_REGION \
    --output table

echo ""
echo -e "${GREEN}=== Update Complete ===${NC}"
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "1. Verify addons: aws eks list-addons --cluster-name $CLUSTER_NAME --region $AWS_REGION"
echo "2. Check addon status: aws eks describe-addon --cluster-name $CLUSTER_NAME --addon-name vpc-cni --region $AWS_REGION"
echo "3. View addon versions: aws eks describe-addon-versions --addon-name vpc-cni --region $AWS_REGION"
echo ""
