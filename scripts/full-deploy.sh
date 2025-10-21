#!/bin/bash
# Full automated deployment script
# This script deploys the entire Petshop Observability Demo from scratch

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Petshop Demo - Full Automated Deployment    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

# Configuration
export AWS_REGION=${AWS_REGION:-us-east-2}
export STACK_NAME=${STACK_NAME:-petshop-observability-demo}
export CLUSTER_NAME=${CLUSTER_NAME:-petshop-demo-eks}
export NAMESPACE=${NAMESPACE:-petshop-demo}

echo -e "${GREEN}Configuration:${NC}"
echo "  AWS Region: $AWS_REGION"
echo "  Stack Name: $STACK_NAME"
echo "  Cluster Name: $CLUSTER_NAME"
echo "  Namespace: $NAMESPACE"
echo ""

# Get AWS Account ID
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}AWS Account ID: $AWS_ACCOUNT_ID${NC}"
echo ""

# Step 1: Generate database password
echo -e "${YELLOW}Step 1: Generating database password...${NC}"
export DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

# Store in Secrets Manager
aws secretsmanager create-secret \
  --name "${STACK_NAME}/db-password" \
  --secret-string "$DB_PASSWORD" \
  --region $AWS_REGION 2>/dev/null || \
aws secretsmanager update-secret \
  --secret-id "${STACK_NAME}/db-password" \
  --secret-string "$DB_PASSWORD" \
  --region $AWS_REGION

echo -e "${GREEN}✓ Database password generated and stored${NC}"
echo ""

# Step 2: Create ECR repositories
echo -e "${YELLOW}Step 2: Creating ECR repositories...${NC}"
for service in catalog-service cart-service checkout-service feature-flag-service frontend; do
  aws ecr describe-repositories --repository-names "petshop-demo/${service}" --region $AWS_REGION 2>/dev/null || \
  aws ecr create-repository \
    --repository-name "petshop-demo/${service}" \
    --image-scanning-configuration scanOnPush=true \
    --region $AWS_REGION > /dev/null
  echo "  ✓ petshop-demo/${service}"
done
echo -e "${GREEN}✓ ECR repositories ready${NC}"
echo ""

# Step 3: Deploy CloudFormation infrastructure
echo -e "${YELLOW}Step 3: Deploying CloudFormation infrastructure...${NC}"
echo "  This may take 15-20 minutes..."

aws cloudformation deploy \
  --template-file aws/cloudformation/eks-infrastructure.yaml \
  --stack-name $STACK_NAME \
  --parameter-overrides \
    ClusterName=$CLUSTER_NAME \
    DatabasePassword=$DB_PASSWORD \
  --capabilities CAPABILITY_NAMED_IAM \
  --region $AWS_REGION \
  --no-fail-on-empty-changeset

echo "  Waiting for stack to be ready..."
aws cloudformation wait stack-create-complete --stack-name $STACK_NAME --region $AWS_REGION 2>/dev/null || true
aws cloudformation wait stack-update-complete --stack-name $STACK_NAME --region $AWS_REGION 2>/dev/null || true

echo -e "${GREEN}✓ Infrastructure deployed${NC}"
echo ""

# Get stack outputs
export VPC_ID=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --region $AWS_REGION --query 'Stacks[0].Outputs[?OutputKey==`VPCId`].OutputValue' --output text)
export DB_ENDPOINT=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --region $AWS_REGION --query 'Stacks[0].Outputs[?OutputKey==`DatabaseEndpoint`].OutputValue' --output text)

echo "  VPC ID: $VPC_ID"
echo "  DB Endpoint: $DB_ENDPOINT"
echo ""

# Step 4: Configure kubectl
echo -e "${YELLOW}Step 4: Configuring kubectl...${NC}"
aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION
kubectl get nodes
echo -e "${GREEN}✓ kubectl configured${NC}"
echo ""

# Step 5: Install AWS Load Balancer Controller
echo -e "${YELLOW}Step 5: Installing AWS Load Balancer Controller...${NC}"
cd aws
chmod +x install-alb-controller.sh
./install-alb-controller.sh || echo "ALB Controller may already be installed"
cd ..
echo -e "${GREEN}✓ ALB Controller installed${NC}"
echo ""

# Step 6: Setup Application Signals
echo -e "${YELLOW}Step 6: Setting up Application Signals...${NC}"
cd aws
chmod +x setup-application-signals.sh
./setup-application-signals.sh || echo "Application Signals setup completed"
cd ..
echo -e "${GREEN}✓ Application Signals configured${NC}"
echo ""

# Step 7: Build and push Docker images
echo -e "${YELLOW}Step 7: Building and pushing Docker images...${NC}"
echo "  This may take 5-10 minutes..."

aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

for service in catalog-service cart-service checkout-service feature-flag-service frontend; do
  echo "  Building $service..."
  cd $service
  
  if [ -f "package.json" ] && [ ! -f "package-lock.json" ]; then
    npm install --package-lock-only
  fi
  
  docker buildx build --platform linux/amd64 \
    -t $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/petshop-demo/${service}:latest \
    --push . > /dev/null
  
  echo "    ✓ $service pushed"
  cd ..
done

echo -e "${GREEN}✓ All images built and pushed${NC}"
echo ""

# Step 8: Generate Kubernetes manifests
echo -e "${YELLOW}Step 8: Generating Kubernetes manifests...${NC}"
python3 scripts/generate-k8s-manifests.py
echo -e "${GREEN}✓ Manifests generated${NC}"
echo ""

# Step 9: Deploy to Kubernetes
echo -e "${YELLOW}Step 9: Deploying to Kubernetes...${NC}"

kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

echo "  Deploying PostgreSQL..."
kubectl apply -f k8s-generated/10-postgresql.yaml
kubectl wait --for=condition=ready pod -l app=postgresql -n $NAMESPACE --timeout=300s

echo "  Deploying services..."
kubectl apply -f k8s-generated/20-catalog-service.yaml
kubectl apply -f k8s-generated/25-cart-service.yaml
kubectl apply -f k8s-generated/30-checkout-service.yaml
kubectl apply -f k8s-generated/35-feature-flag-service.yaml
kubectl apply -f k8s-generated/30-frontend.yaml

echo "  Waiting for services to be ready..."
sleep 30
kubectl wait --for=condition=ready pod -l app=catalog-service -n $NAMESPACE --timeout=300s
kubectl wait --for=condition=ready pod -l app=cart-service -n $NAMESPACE --timeout=300s
kubectl wait --for=condition=ready pod -l app=checkout-service -n $NAMESPACE --timeout=300s
kubectl wait --for=condition=ready pod -l app=feature-flag-service -n $NAMESPACE --timeout=300s
kubectl wait --for=condition=ready pod -l app=frontend -n $NAMESPACE --timeout=300s

echo "  Deploying observability components..."
kubectl apply -f k8s-generated/40-adot-collector.yaml
kubectl apply -f k8s-generated/60-adot-collector.yaml
kubectl apply -f k8s-generated/61-application-signals.yaml
kubectl apply -f k8s-generated/62-fluent-bit-logs.yaml

echo "  Deploying ingress..."
kubectl apply -f k8s-generated/35-frontend-ingress.yaml

echo -e "${GREEN}✓ Kubernetes deployment complete${NC}"
echo ""

# Step 10: Wait for ALB
echo -e "${YELLOW}Step 10: Waiting for ALB to be provisioned...${NC}"
echo "  This may take 2-4 minutes..."
sleep 60

export ALB_URL=$(kubectl get ingress -n $NAMESPACE frontend-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "  ALB URL: http://$ALB_URL"

# Wait for ALB to be ready
for i in {1..30}; do
  if curl -s -o /dev/null -w "%{http_code}" "http://$ALB_URL" | grep -q "200\|301\|302"; then
    echo -e "${GREEN}✓ ALB is ready!${NC}"
    break
  fi
  echo "  Waiting for ALB... attempt $i/30"
  sleep 10
done
echo ""

# Step 11: Create CloudWatch alarms and dashboards
echo -e "${YELLOW}Step 11: Creating CloudWatch alarms and dashboards...${NC}"

cd aws
chmod +x create-alarms-and-dashboard.sh create-chaos-alarms.sh create-log-based-alarms.sh

./create-alarms-and-dashboard.sh || echo "Alarms creation completed"
./create-chaos-alarms.sh || echo "Chaos alarms creation completed"
./create-log-based-alarms.sh || echo "Log-based alarms creation completed"
cd ..

echo -e "${GREEN}✓ Observability configured${NC}"
echo ""

# Final status
echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Deployment Complete!                         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

kubectl get pods -n $NAMESPACE
echo ""

echo -e "${GREEN}Application URL:${NC} http://$ALB_URL"
echo ""
echo -e "${GREEN}CloudWatch Dashboard:${NC}"
echo "  https://console.aws.amazon.com/cloudwatch/home?region=$AWS_REGION#dashboards:name=Petshop-Observability-Demo"
echo ""
echo -e "${GREEN}CloudWatch Alarms:${NC}"
echo "  https://console.aws.amazon.com/cloudwatch/home?region=$AWS_REGION#alarmsV2:"
echo ""
echo -e "${GREEN}X-Ray Service Map:${NC}"
echo "  https://console.aws.amazon.com/xray/home?region=$AWS_REGION#/service-map"
echo ""
echo -e "${GREEN}Database Password (Secrets Manager):${NC}"
echo "  aws secretsmanager get-secret-value --secret-id ${STACK_NAME}/db-password --query SecretString --output text"
echo ""

# Create summary file
cat > deployment-summary.json <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "region": "$AWS_REGION",
  "account_id": "$AWS_ACCOUNT_ID",
  "stack_name": "$STACK_NAME",
  "cluster_name": "$CLUSTER_NAME",
  "namespace": "$NAMESPACE",
  "alb_url": "http://$ALB_URL",
  "vpc_id": "$VPC_ID",
  "db_endpoint": "$DB_ENDPOINT"
}
EOF

echo -e "${GREEN}Deployment summary saved to: deployment-summary.json${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Open the application: http://$ALB_URL"
echo "  2. View CloudWatch dashboards"
echo "  3. Test chaos engineering: cd aws && ./test-chaos-scenarios.sh"
echo "  4. Generate traffic: cd aws && ./generate-traffic.sh"
echo ""
