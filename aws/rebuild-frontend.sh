#!/bin/bash
set -e

# Load configuration
source "$(dirname "$0")/config.sh"

echo "=== Rebuilding and Pushing Frontend Image ==="

# Login to ECR
echo "Logging in to ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY

# Build frontend image
echo "Building frontend image..."
cd ../frontend
docker build --platform linux/amd64 -t petshop-frontend:latest .

# Tag and push
echo "Tagging and pushing frontend image..."
docker tag petshop-frontend:latest $ECR_REGISTRY/petshop-frontend:latest
docker push $ECR_REGISTRY/petshop-frontend:latest

echo "✓ Frontend image rebuilt and pushed successfully"

# Update EKS deployment
echo "Updating EKS deployment..."
cd ../aws
kubectl rollout restart deployment/frontend -n petshop

echo "✓ Frontend deployment restarted"
echo ""
echo "Monitor the rollout with:"
echo "  kubectl rollout status deployment/frontend -n petshop"
echo "  kubectl get pods -n petshop -l app=frontend"
