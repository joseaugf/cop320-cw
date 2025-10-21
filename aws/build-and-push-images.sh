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

echo -e "${GREEN}=== Building and Pushing Docker Images to ECR ===${NC}"
echo ""

# Get AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}✓ AWS Account ID: ${AWS_ACCOUNT_ID}${NC}"
echo -e "${GREEN}✓ Region: ${AWS_REGION}${NC}"
echo ""

# ECR Login
echo -e "${YELLOW}Step 1: Logging into ECR...${NC}"
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
echo -e "${GREEN}✓ Logged into ECR${NC}"
echo ""

# Array of services
SERVICES=("catalog-service" "cart-service" "checkout-service" "feature-flag-service" "frontend")

# Build and push each service
for SERVICE in "${SERVICES[@]}"; do
    echo -e "${YELLOW}Step: Building and pushing ${SERVICE}...${NC}"
    
    ECR_REPO="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/petshop-demo/${SERVICE}"
    
    # Navigate to service directory
    cd "${SCRIPT_DIR}/../${SERVICE}"
    
    # Generate package-lock.json if it doesn't exist (for Node.js services)
    if [ -f "package.json" ] && [ ! -f "package-lock.json" ]; then
        echo "  Generating package-lock.json..."
        npm install --package-lock-only
    fi
    
    # Build and push image using buildx (more efficient)
    echo "  Building and pushing Docker image for linux/amd64..."
    docker buildx build --platform linux/amd64 -t ${ECR_REPO}:latest --push .
    
    echo -e "${GREEN}✓ ${SERVICE} pushed successfully${NC}"
    echo ""
done

cd "${SCRIPT_DIR}"

echo -e "${GREEN}=== All Images Built and Pushed ===${NC}"
echo ""
echo -e "${GREEN}Images available in ECR:${NC}"
for SERVICE in "${SERVICES[@]}"; do
    echo "  ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/petshop-demo/${SERVICE}:latest"
done
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "1. Deploy Kubernetes resources: kubectl apply -f k8s/"
echo "2. Check pod status: kubectl get pods -n petshop-demo"
echo "3. View logs: kubectl logs -f <pod-name> -n petshop-demo"
echo ""
