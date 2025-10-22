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

echo -e "${GREEN}=== Installing AWS Load Balancer Controller ===${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"
command -v helm >/dev/null 2>&1 || { echo -e "${RED}Helm is required but not installed. Install from https://helm.sh/docs/intro/install/${NC}" >&2; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}kubectl is required but not installed.${NC}" >&2; exit 1; }
command -v eksctl >/dev/null 2>&1 || { echo -e "${RED}eksctl is required but not installed.${NC}" >&2; exit 1; }

echo -e "${GREEN}✓ Prerequisites met${NC}"
echo ""

# Get IAM Policy ARN from CloudFormation
echo -e "${YELLOW}Step 1: Getting IAM Policy ARN from CloudFormation...${NC}"
ALB_POLICY_ARN=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME_INFRA \
    --query "Stacks[0].Outputs[?OutputKey=='AWSLoadBalancerControllerPolicyArn'].OutputValue" \
    --output text \
    --region $AWS_REGION 2>&1)

if [ -z "$ALB_POLICY_ARN" ] || [ "$ALB_POLICY_ARN" == "None" ] || [[ "$ALB_POLICY_ARN" == *"error"* ]]; then
    echo -e "${RED}✗ Failed to get ALB Controller Policy ARN from stack: $STACK_NAME_INFRA${NC}"
    echo -e "${YELLOW}The CloudFormation stack may not have the AWSLoadBalancerControllerPolicy resource.${NC}"
    echo ""
    echo -e "${YELLOW}Checking if stack exists and has the required output...${NC}"
    
    # Check if stack exists
    STACK_STATUS=$(aws cloudformation describe-stacks \
        --stack-name $STACK_NAME_INFRA \
        --query "Stacks[0].StackStatus" \
        --output text \
        --region $AWS_REGION 2>&1)
    
    if [[ "$STACK_STATUS" == *"does not exist"* ]]; then
        echo -e "${RED}✗ Stack $STACK_NAME_INFRA does not exist${NC}"
        echo -e "${YELLOW}Run: ./deploy.sh to create the infrastructure${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}Stack exists with status: $STACK_STATUS${NC}"
    echo -e "${YELLOW}Available outputs:${NC}"
    aws cloudformation describe-stacks \
        --stack-name $STACK_NAME_INFRA \
        --query "Stacks[0].Outputs[].OutputKey" \
        --output table \
        --region $AWS_REGION
    
    echo ""
    echo -e "${RED}The AWSLoadBalancerControllerPolicyArn output is missing.${NC}"
    echo -e "${YELLOW}You need to update the stack with the latest template.${NC}"
    echo -e "${YELLOW}Run: ./update-stack-addons.sh${NC}"
    exit 1
fi

echo -e "${GREEN}✓ ALB Controller Policy ARN: ${ALB_POLICY_ARN}${NC}"
echo ""

# Delete existing ServiceAccount if it exists (to ensure clean state)
echo -e "${YELLOW}Step 2: Cleaning up existing ServiceAccount...${NC}"
kubectl delete sa aws-load-balancer-controller -n kube-system 2>/dev/null || echo "No existing ServiceAccount to delete"
echo ""

# Create IAM Role via eksctl (IRSA)
echo -e "${YELLOW}Step 3: Creating IAM Role for ALB Controller via eksctl...${NC}"
eksctl create iamserviceaccount \
    --cluster=$CLUSTER_NAME \
    --namespace=kube-system \
    --name=aws-load-balancer-controller \
    --attach-policy-arn=$ALB_POLICY_ARN \
    --override-existing-serviceaccounts \
    --region=$AWS_REGION \
    --approve

# Check if ServiceAccount was created by eksctl
if kubectl get sa aws-load-balancer-controller -n kube-system &>/dev/null; then
    echo -e "${GREEN}✓ ServiceAccount created by eksctl${NC}"
else
    echo -e "${YELLOW}ServiceAccount not created by eksctl, creating manually...${NC}"
    
    # Get the IAM role ARN created by eksctl
    ROLE_ARN=$(aws iam list-roles --query "Roles[?contains(RoleName, 'eksctl-${CLUSTER_NAME}') && contains(RoleName, 'aws-load-balancer-controller')].Arn" --output text --region $AWS_REGION | head -1)
    
    if [ -z "$ROLE_ARN" ]; then
        echo -e "${RED}✗ Could not find IAM role created by eksctl${NC}"
        echo -e "${YELLOW}Listing roles for debugging:${NC}"
        aws iam list-roles --query "Roles[?contains(RoleName, 'eksctl')].{Name:RoleName,Arn:Arn}" --output table --region $AWS_REGION | grep -i load-balancer || echo "No matching roles found"
        exit 1
    fi
    
    echo -e "${GREEN}Found IAM Role: $ROLE_ARN${NC}"
    
    # Create ServiceAccount manually with the correct annotation
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    app.kubernetes.io/component: controller
    app.kubernetes.io/name: aws-load-balancer-controller
  name: aws-load-balancer-controller
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: ${ROLE_ARN}
EOF
    
    echo -e "${GREEN}✓ ServiceAccount created manually with IAM role annotation${NC}"
fi
echo ""

# Add EKS Helm repository
echo -e "${YELLOW}Step 4: Adding EKS Helm repository...${NC}"
helm repo add eks https://aws.github.io/eks-charts
helm repo update
echo -e "${GREEN}✓ Helm repository added${NC}"
echo ""

# Install AWS Load Balancer Controller
echo -e "${YELLOW}Step 5: Installing AWS Load Balancer Controller via Helm...${NC}"
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n kube-system \
    --set clusterName=$CLUSTER_NAME \
    --set serviceAccount.create=false \
    --set serviceAccount.name=aws-load-balancer-controller \
    --set region=$AWS_REGION \
    --set vpcId=$(aws cloudformation describe-stacks \
        --stack-name $STACK_NAME_INFRA \
        --query "Stacks[0].Outputs[?OutputKey=='VpcId'].OutputValue" \
        --output text \
        --region $AWS_REGION)

echo -e "${GREEN}✓ AWS Load Balancer Controller installed${NC}"
echo ""

# Wait for deployment
echo -e "${YELLOW}Step 6: Waiting for AWS Load Balancer Controller to be ready...${NC}"
kubectl wait --for=condition=available --timeout=300s \
    deployment/aws-load-balancer-controller \
    -n kube-system

echo -e "${GREEN}✓ AWS Load Balancer Controller is ready${NC}"
echo ""

# Verify installation
echo -e "${YELLOW}Step 7: Verifying installation...${NC}"
kubectl get deployment -n kube-system aws-load-balancer-controller
echo ""
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
echo ""

# Restart deployment to ensure it picks up the correct ServiceAccount
echo -e "${YELLOW}Step 8: Restarting AWS Load Balancer Controller to apply IRSA...${NC}"
kubectl rollout restart deployment/aws-load-balancer-controller -n kube-system
echo "Waiting for pods to restart..."
sleep 10
kubectl rollout status deployment/aws-load-balancer-controller -n kube-system --timeout=300s
echo -e "${GREEN}✓ AWS Load Balancer Controller restarted${NC}"
echo ""

# Verify IRSA is working
echo -e "${YELLOW}Step 9: Verifying IRSA configuration...${NC}"
SA_ROLE=$(kubectl get sa aws-load-balancer-controller -n kube-system -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}')
if [ -n "$SA_ROLE" ]; then
    echo -e "${GREEN}✓ ServiceAccount has IAM role annotation: $SA_ROLE${NC}"
else
    echo -e "${RED}✗ ServiceAccount missing IAM role annotation${NC}"
    echo -e "${YELLOW}This may cause permission issues. Check eksctl logs.${NC}"
fi
echo ""

echo -e "${GREEN}=== AWS Load Balancer Controller Installation Complete ===${NC}"
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "1. Create an Ingress resource to use ALB"
echo "2. Example Ingress annotation: alb.ingress.kubernetes.io/scheme: internet-facing"
echo "3. View controller logs: kubectl logs -n kube-system deployment/aws-load-balancer-controller"
echo ""
