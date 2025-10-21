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

echo -e "${GREEN}=== Petshop Observability Demo - AWS Deployment ===${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"
command -v aws >/dev/null 2>&1 || { echo -e "${RED}AWS CLI is required but not installed. Aborting.${NC}" >&2; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}kubectl is required but not installed. Aborting.${NC}" >&2; exit 1; }
command -v eksctl >/dev/null 2>&1 || { echo -e "${RED}eksctl is required but not installed. Aborting.${NC}" >&2; exit 1; }

# Check AWS credentials
aws sts get-caller-identity >/dev/null 2>&1 || { echo -e "${RED}AWS credentials not configured. Aborting.${NC}" >&2; exit 1; }

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}✓ AWS Account ID: ${AWS_ACCOUNT_ID}${NC}"
echo -e "${GREEN}✓ Region: ${AWS_REGION}${NC}"
echo ""

# Function to wait for stack completion
wait_for_stack() {
    local stack_name=$1
    echo -e "${YELLOW}Waiting for stack ${stack_name} to complete...${NC}"
    aws cloudformation wait stack-create-complete --stack-name $stack_name --region $AWS_REGION 2>/dev/null || \
    aws cloudformation wait stack-update-complete --stack-name $stack_name --region $AWS_REGION 2>/dev/null
    echo -e "${GREEN}✓ Stack ${stack_name} completed${NC}"
}

# Deploy infrastructure stack
echo -e "${YELLOW}Step 1: Deploying EKS Infrastructure...${NC}"
if [ -f "parameters.json" ]; then
    aws cloudformation deploy \
        --template-file cloudformation/eks-infrastructure.yaml \
        --stack-name $STACK_NAME_INFRA \
        --parameter-overrides file://parameters.json \
        --capabilities CAPABILITY_NAMED_IAM \
        --region $AWS_REGION
else
    echo -e "${YELLOW}No parameters.json found. Using default parameters.${NC}"
    aws cloudformation deploy \
        --template-file cloudformation/eks-infrastructure.yaml \
        --stack-name $STACK_NAME_INFRA \
        --capabilities CAPABILITY_NAMED_IAM \
        --region $AWS_REGION
fi

wait_for_stack $STACK_NAME_INFRA
echo ""

# Get stack outputs
echo -e "${YELLOW}Step 2: Retrieving infrastructure details...${NC}"
RDS_ENDPOINT=$(aws cloudformation describe-stacks --stack-name $STACK_NAME_INFRA --query "Stacks[0].Outputs[?OutputKey=='RDSEndpoint'].OutputValue" --output text --region $AWS_REGION)
REDIS_ENDPOINT=$(aws cloudformation describe-stacks --stack-name $STACK_NAME_INFRA --query "Stacks[0].Outputs[?OutputKey=='RedisEndpoint'].OutputValue" --output text --region $AWS_REGION)
ADOT_POLICY_ARN=$(aws cloudformation describe-stacks --stack-name $STACK_NAME_INFRA --query "Stacks[0].Outputs[?OutputKey=='ADOTCollectorPolicyArn'].OutputValue" --output text --region $AWS_REGION)

echo -e "${GREEN}✓ RDS Endpoint: ${RDS_ENDPOINT}${NC}"
echo -e "${GREEN}✓ Redis Endpoint: ${REDIS_ENDPOINT}${NC}"
echo ""

# Configure kubectl
echo -e "${YELLOW}Step 3: Configuring kubectl...${NC}"
aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION
echo -e "${GREEN}✓ kubectl configured${NC}"
echo ""

# Create IRSA for ADOT Collector
echo -e "${YELLOW}Step 4: Creating IAM Role for Service Account (IRSA)...${NC}"
eksctl create iamserviceaccount \
    --name adot-collector \
    --namespace petshop-demo \
    --cluster $CLUSTER_NAME \
    --region $AWS_REGION \
    --attach-policy-arn $ADOT_POLICY_ARN \
    --approve \
    --override-existing-serviceaccounts || echo -e "${YELLOW}IRSA may already exist${NC}"
echo -e "${GREEN}✓ IRSA created${NC}"
echo ""

# Update ConfigMap with RDS and Redis endpoints
echo -e "${YELLOW}Step 5: Updating Kubernetes ConfigMap...${NC}"
sed -i.bak "s/REPLACE_WITH_RDS_ENDPOINT/${RDS_ENDPOINT}/g" k8s/02-configmap.yaml
sed -i.bak "s/REPLACE_WITH_REDIS_ENDPOINT/${REDIS_ENDPOINT}/g" k8s/02-configmap.yaml
echo -e "${GREEN}✓ ConfigMap updated${NC}"
echo ""

# Update image references in deployments
echo -e "${YELLOW}Step 6: Updating Kubernetes manifests with ECR URIs...${NC}"
for file in k8s/*.yaml; do
    sed -i.bak "s/ACCOUNT_ID/${AWS_ACCOUNT_ID}/g" $file
    sed -i.bak "s/REGION/${AWS_REGION}/g" $file
done
echo -e "${GREEN}✓ Manifests updated${NC}"
echo ""

# Deploy Kubernetes resources
echo -e "${YELLOW}Step 7: Deploying Kubernetes resources...${NC}"
kubectl apply -f k8s/
echo -e "${GREEN}✓ Kubernetes resources deployed${NC}"
echo ""

# Wait for pods to be ready
echo -e "${YELLOW}Step 8: Waiting for pods to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app=catalog-service -n petshop-demo --timeout=300s || echo -e "${YELLOW}Catalog service may still be starting${NC}"
kubectl wait --for=condition=ready pod -l app=cart-service -n petshop-demo --timeout=300s || echo -e "${YELLOW}Cart service may still be starting${NC}"
kubectl wait --for=condition=ready pod -l app=checkout-service -n petshop-demo --timeout=300s || echo -e "${YELLOW}Checkout service may still be starting${NC}"
kubectl wait --for=condition=ready pod -l app=feature-flag-service -n petshop-demo --timeout=300s || echo -e "${YELLOW}Feature flag service may still be starting${NC}"
kubectl wait --for=condition=ready pod -l app=frontend -n petshop-demo --timeout=300s || echo -e "${YELLOW}Frontend may still be starting${NC}"
echo ""

# Get frontend URL
echo -e "${YELLOW}Step 9: Getting application URL...${NC}"
FRONTEND_URL=$(kubectl get svc frontend -n petshop-demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
if [ -z "$FRONTEND_URL" ]; then
    echo -e "${YELLOW}LoadBalancer is still provisioning. Run the following command later to get the URL:${NC}"
    echo "kubectl get svc frontend -n petshop-demo"
else
    echo -e "${GREEN}✓ Application URL: http://${FRONTEND_URL}${NC}"
fi
echo ""

# Optional: Deploy CI/CD pipeline
read -p "Do you want to deploy the CI/CD pipeline? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Step 10: Deploying CI/CD Pipeline...${NC}"
    
    read -p "Use GitHub (g) or CodeCommit (c)? " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Gg]$ ]]; then
        read -p "Enter GitHub repository (username/repo): " GITHUB_REPO
        read -p "Enter GitHub branch (default: main): " GITHUB_BRANCH
        GITHUB_BRANCH=${GITHUB_BRANCH:-main}
        read -sp "Enter GitHub personal access token: " GITHUB_TOKEN
        echo
        
        aws cloudformation deploy \
            --template-file cloudformation/cicd-pipeline.yaml \
            --stack-name $STACK_NAME_CICD \
            --parameter-overrides \
                ClusterName=$CLUSTER_NAME \
                GitHubRepo=$GITHUB_REPO \
                GitHubBranch=$GITHUB_BRANCH \
                GitHubToken=$GITHUB_TOKEN \
                UseCodeCommit=false \
            --capabilities CAPABILITY_NAMED_IAM \
            --region $AWS_REGION
    else
        aws cloudformation deploy \
            --template-file cloudformation/cicd-pipeline.yaml \
            --stack-name $STACK_NAME_CICD \
            --parameter-overrides \
                ClusterName=$CLUSTER_NAME \
                UseCodeCommit=true \
            --capabilities CAPABILITY_NAMED_IAM \
            --region $AWS_REGION
    fi
    
    wait_for_stack $STACK_NAME_CICD
    echo -e "${GREEN}✓ CI/CD Pipeline deployed${NC}"
fi

echo ""
echo -e "${GREEN}=== Deployment Complete ===${NC}"
echo -e "${GREEN}Next steps:${NC}"
echo "1. Check pod status: kubectl get pods -n petshop-demo"
echo "2. View logs: kubectl logs -f <pod-name> -n petshop-demo"
echo "3. Access application: kubectl get svc frontend -n petshop-demo"
echo "4. View CloudWatch dashboards in AWS Console"
echo ""
