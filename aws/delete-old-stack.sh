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

echo -e "${YELLOW}=== Deleting Old CloudFormation Stack ===${NC}"
echo -e "${YELLOW}Stack Name: ${OLD_STACK_NAME}${NC}"
echo ""

# Check if stack exists
STACK_STATUS=$(aws cloudformation describe-stacks \
    --stack-name $OLD_STACK_NAME \
    --region $AWS_REGION \
    --query 'Stacks[0].StackStatus' \
    --output text 2>/dev/null || echo "DOES_NOT_EXIST")

if [ "$STACK_STATUS" = "DOES_NOT_EXIST" ]; then
    echo -e "${GREEN}✓ Old stack does not exist. Nothing to delete.${NC}"
    exit 0
fi

echo -e "${YELLOW}Current stack status: ${STACK_STATUS}${NC}"
echo ""

if [[ "$STACK_STATUS" == *"IN_PROGRESS"* ]]; then
    echo -e "${RED}WARNING: Stack is currently in progress state.${NC}"
    echo -e "${YELLOW}You may need to wait for it to complete or fail before deleting.${NC}"
    echo ""
    read -p "Do you want to try deleting anyway? (yes/no) " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo "Deletion cancelled."
        exit 0
    fi
fi

echo -e "${YELLOW}Deleting stack...${NC}"
aws cloudformation delete-stack \
    --stack-name $OLD_STACK_NAME \
    --region $AWS_REGION

echo -e "${GREEN}✓ Delete initiated${NC}"
echo ""
echo -e "${YELLOW}Waiting for stack deletion (this may take 15-20 minutes)...${NC}"
echo -e "${YELLOW}You can press Ctrl+C to stop waiting (deletion will continue in background)${NC}"
echo ""

# Wait for deletion with timeout
aws cloudformation wait stack-delete-complete \
    --stack-name $OLD_STACK_NAME \
    --region $AWS_REGION 2>/dev/null && \
    echo -e "${GREEN}✓ Stack deleted successfully${NC}" || \
    echo -e "${YELLOW}Stack deletion may still be in progress. Check AWS Console for status.${NC}"

echo ""
echo -e "${GREEN}You can now run ./deploy.sh to create the new stack${NC}"
