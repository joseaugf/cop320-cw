#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

echo -e "${GREEN}=== Deploying Frontend Ingress (ALB) ===${NC}"
echo ""

# Check if ALB Controller is installed
echo -e "${YELLOW}Checking if AWS Load Balancer Controller is installed...${NC}"
if ! kubectl get deployment -n kube-system aws-load-balancer-controller &> /dev/null; then
    echo -e "${RED}AWS Load Balancer Controller is not installed!${NC}"
    echo -e "${YELLOW}Run: ./install-alb-controller.sh${NC}"
    exit 1
fi

echo -e "${GREEN}✓ AWS Load Balancer Controller is installed${NC}"
echo ""

# Apply the Ingress resource
echo -e "${YELLOW}Applying Ingress resource...${NC}"
kubectl apply -f "${SCRIPT_DIR}/k8s/35-frontend-ingress.yaml"

echo -e "${GREEN}✓ Ingress resource applied${NC}"
echo ""

# Wait for ALB to be provisioned
echo -e "${YELLOW}Waiting for ALB to be provisioned (this may take 2-3 minutes)...${NC}"
echo -e "${BLUE}Checking ALB status...${NC}"

for i in {1..60}; do
    ALB_ADDRESS=$(kubectl get ingress frontend-ingress -n petshop-demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    
    if [ -n "$ALB_ADDRESS" ]; then
        echo -e "${GREEN}✓ ALB provisioned successfully!${NC}"
        break
    fi
    
    if [ $i -eq 60 ]; then
        echo -e "${RED}Timeout waiting for ALB. Check the controller logs:${NC}"
        echo -e "${YELLOW}kubectl logs -n kube-system deployment/aws-load-balancer-controller${NC}"
        exit 1
    fi
    
    echo -n "."
    sleep 3
done

echo ""
echo ""

# Get Ingress details
echo -e "${GREEN}=== Ingress Details ===${NC}"
kubectl get ingress frontend-ingress -n petshop-demo
echo ""

# Get ALB URL
ALB_URL=$(kubectl get ingress frontend-ingress -n petshop-demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo -e "${GREEN}=== Frontend Application URL ===${NC}"
echo -e "${BLUE}http://${ALB_URL}${NC}"
echo ""

# Wait for ALB to be healthy
echo -e "${YELLOW}Waiting for ALB health checks to pass...${NC}"
sleep 10

# Test the endpoint
echo -e "${YELLOW}Testing the endpoint...${NC}"
if curl -s -o /dev/null -w "%{http_code}" "http://${ALB_URL}/health" | grep -q "200"; then
    echo -e "${GREEN}✓ Frontend is healthy and accessible!${NC}"
else
    echo -e "${YELLOW}⚠ Health check returned non-200. The ALB might still be initializing.${NC}"
    echo -e "${YELLOW}Wait a few more seconds and try accessing: http://${ALB_URL}${NC}"
fi

echo ""
echo -e "${GREEN}=== Deployment Complete ===${NC}"
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "1. Access the frontend: http://${ALB_URL}"
echo "2. View Ingress details: kubectl describe ingress frontend-ingress -n petshop-demo"
echo "3. View ALB Controller logs: kubectl logs -n kube-system deployment/aws-load-balancer-controller"
echo "4. Check ALB in AWS Console: https://console.aws.amazon.com/ec2/v2/home?region=${AWS_REGION}#LoadBalancers:"
echo ""

# Optional: Save URL to file
echo "http://${ALB_URL}" > "${SCRIPT_DIR}/frontend-url.txt"
echo -e "${BLUE}Frontend URL saved to: ${SCRIPT_DIR}/frontend-url.txt${NC}"
echo ""
