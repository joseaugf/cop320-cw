#!/bin/bash

# Petshop Observability Demo - EKS Deployment Script
# This script deploys all Kubernetes resources in the correct order

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to wait for deployment to be ready
wait_for_deployment() {
    local namespace=$1
    local deployment=$2
    local timeout=${3:-300}
    
    print_info "Waiting for deployment $deployment to be ready..."
    kubectl wait --for=condition=available --timeout=${timeout}s \
        deployment/$deployment -n $namespace || {
        print_error "Deployment $deployment failed to become ready"
        return 1
    }
    print_info "Deployment $deployment is ready"
}

# Function to wait for statefulset to be ready
wait_for_statefulset() {
    local namespace=$1
    local statefulset=$2
    local timeout=${3:-300}
    
    print_info "Waiting for statefulset $statefulset to be ready..."
    kubectl wait --for=jsonpath='{.status.readyReplicas}'=1 --timeout=${timeout}s \
        statefulset/$statefulset -n $namespace || {
        print_error "StatefulSet $statefulset failed to become ready"
        return 1
    }
    print_info "StatefulSet $statefulset is ready"
}

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed. Please install kubectl first."
    exit 1
fi

# Check if connected to a cluster
if ! kubectl cluster-info &> /dev/null; then
    print_error "Not connected to a Kubernetes cluster. Please configure kubectl."
    exit 1
fi

print_info "Starting deployment of Petshop Observability Demo..."

# Step 1: Create namespace
print_info "Creating namespace..."
kubectl apply -f 00-namespace.yaml

# Step 2: Create ConfigMaps and Secrets
print_info "Creating ConfigMaps and Secrets..."
kubectl apply -f 01-configmap.yaml
kubectl apply -f 02-secrets.yaml

# Step 3: Create ServiceAccounts
print_info "Creating ServiceAccounts..."
kubectl apply -f 03-serviceaccount.yaml

print_warning "Remember to update ServiceAccount annotations with your IAM role ARNs!"

# Step 4: Skip PostgreSQL (using RDS from CloudFormation)
print_info "Skipping PostgreSQL deployment (using RDS from CloudFormation)..."

# Step 5: Deploy Redis
print_info "Deploying Redis..."
kubectl apply -f 11-redis.yaml
wait_for_deployment petshop-demo redis 180

# Step 6: Deploy ADOT Collector
print_info "Deploying ADOT Collector..."
kubectl apply -f 40-adot-collector.yaml
sleep 10  # Give DaemonSet time to start

# Step 7: Deploy microservices
print_info "Deploying Catalog Service..."
kubectl apply -f 20-catalog-service.yaml
wait_for_deployment petshop-demo catalog-service 180

print_info "Deploying Cart Service..."
kubectl apply -f 21-cart-service.yaml
wait_for_deployment petshop-demo cart-service 180

print_info "Deploying Checkout Service..."
kubectl apply -f 22-checkout-service.yaml
wait_for_deployment petshop-demo checkout-service 180

print_info "Deploying Feature Flag Service..."
kubectl apply -f 23-feature-flag-service.yaml
wait_for_deployment petshop-demo feature-flag-service 180

# Step 8: Deploy Frontend
print_info "Deploying Frontend..."
kubectl apply -f 30-frontend.yaml
wait_for_deployment petshop-demo frontend 180

# Step 9: Deploy Ingress (ALB)
print_info "Deploying Ingress (ALB)..."
kubectl apply -f 35-frontend-ingress.yaml
print_info "Ingress deployed. ALB will be provisioned by AWS Load Balancer Controller..."

# Step 10: Get LoadBalancer URL
print_info "Getting Ingress URL..."
sleep 30  # Give ALB time to provision

FRONTEND_URL=$(kubectl get ingress frontend-ingress -n petshop-demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

if [ -z "$FRONTEND_URL" ]; then
    FRONTEND_URL=$(kubectl get ingress frontend-ingress -n petshop-demo -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
fi

print_info "Deployment completed successfully!"
echo ""
print_info "=== Deployment Summary ==="
echo ""
print_info "Namespace: petshop-demo"
echo ""
print_info "Services deployed:"
echo "  - PostgreSQL (RDS - managed by CloudFormation)"
echo "  - Redis (Deployment)"
echo "  - ADOT Collector (DaemonSet)"
echo "  - Catalog Service (2 replicas)"
echo "  - Cart Service (2 replicas)"
echo "  - Checkout Service (2 replicas)"
echo "  - Feature Flag Service (1 replica)"
echo "  - Frontend (2 replicas)"
echo ""

if [ -n "$FRONTEND_URL" ]; then
    print_info "Frontend URL: http://$FRONTEND_URL"
    print_info "Admin Panel: http://$FRONTEND_URL/admin"
else
    print_warning "ALB URL not yet available. It may take 2-3 minutes to provision."
    print_warning "Run the following command to get it:"
    echo "  kubectl get ingress frontend-ingress -n petshop-demo"
fi

echo ""
print_info "To view all resources:"
echo "  kubectl get all -n petshop-demo"
echo ""
print_info "To view logs:"
echo "  kubectl logs -f deployment/catalog-service -n petshop-demo"
echo ""
print_info "To access CloudWatch, ensure your ADOT Collector ServiceAccount has the correct IAM role."
