#!/bin/bash
# Post-deployment validation script
# Validates that all components are working correctly

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Deployment Validation                        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

# Configuration
AWS_REGION=${AWS_REGION:-us-east-2}
NAMESPACE=${NAMESPACE:-petshop-demo}
STACK_NAME=${STACK_NAME:-petshop-observability-demo}

echo "Configuration:"
echo "  Region: $AWS_REGION"
echo "  Namespace: $NAMESPACE"
echo "  Stack: $STACK_NAME"
echo ""

# Test function
test_component() {
  local name=$1
  local command=$2
  
  echo -n "Testing $name... "
  if eval "$command" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
  else
    echo -e "${RED}✗ FAIL${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi
}

# Test 1: CloudFormation Stack
echo -e "${YELLOW}Infrastructure Tests${NC}"
test_component "CloudFormation Stack" \
  "aws cloudformation describe-stacks --stack-name $STACK_NAME --region $AWS_REGION --query 'Stacks[0].StackStatus' --output text | grep -q 'CREATE_COMPLETE\|UPDATE_COMPLETE'"

# Test 2: EKS Cluster
test_component "EKS Cluster" \
  "kubectl cluster-info"

# Test 3: Nodes
test_component "EKS Nodes" \
  "kubectl get nodes | grep -q Ready"

echo ""

# Test 4-8: Pods
echo -e "${YELLOW}Application Tests${NC}"
test_component "Catalog Service Pods" \
  "kubectl get pods -n $NAMESPACE -l app=catalog-service | grep -q Running"

test_component "Cart Service Pods" \
  "kubectl get pods -n $NAMESPACE -l app=cart-service | grep -q Running"

test_component "Checkout Service Pods" \
  "kubectl get pods -n $NAMESPACE -l app=checkout-service | grep -q Running"

test_component "Feature Flag Service Pods" \
  "kubectl get pods -n $NAMESPACE -l app=feature-flag-service | grep -q Running"

test_component "Frontend Pods" \
  "kubectl get pods -n $NAMESPACE -l app=frontend | grep -q Running"

echo ""

# Test 9: ALB
echo -e "${YELLOW}Networking Tests${NC}"
ALB_URL=$(kubectl get ingress -n $NAMESPACE frontend-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)

if [ -n "$ALB_URL" ]; then
  echo -e "${GREEN}✓ ALB URL: http://$ALB_URL${NC}"
  TESTS_PASSED=$((TESTS_PASSED + 1))
  
  # Test 10: Application endpoints
  test_component "Products API" \
    "curl -s -o /dev/null -w '%{http_code}' http://$ALB_URL/api/products | grep -q 200"
  
  test_component "Flags API" \
    "curl -s -o /dev/null -w '%{http_code}' http://$ALB_URL/api/flags | grep -q 200"
  
  test_component "Frontend" \
    "curl -s -o /dev/null -w '%{http_code}' http://$ALB_URL | grep -q '200\|301\|302'"
else
  echo -e "${RED}✗ ALB URL not found${NC}"
  TESTS_FAILED=$((TESTS_FAILED + 3))
fi

echo ""

# Test 11-13: Observability
echo -e "${YELLOW}Observability Tests${NC}"
test_component "ADOT Collector" \
  "kubectl get pods -n $NAMESPACE -l app=adot-collector | grep -q Running"

test_component "CloudWatch Dashboard" \
  "aws cloudwatch list-dashboards --region $AWS_REGION | grep -q Petshop-Observability-Demo"

test_component "CloudWatch Alarms" \
  "aws cloudwatch describe-alarms --region $AWS_REGION --alarm-name-prefix Petshop- --query 'length(MetricAlarms)' --output text | grep -q '[1-9]'"

echo ""

# Test 14: Secrets
echo -e "${YELLOW}Security Tests${NC}"
test_component "Database Password Secret" \
  "aws secretsmanager describe-secret --secret-id ${STACK_NAME}/db-password --region $AWS_REGION"

# Test 15-19: ECR Repositories
echo ""
echo -e "${YELLOW}Container Registry Tests${NC}"
for service in catalog-service cart-service checkout-service feature-flag-service frontend; do
  test_component "ECR: $service" \
    "aws ecr describe-repositories --repository-names petshop-demo/$service --region $AWS_REGION"
done

echo ""

# Summary
echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Validation Summary                           ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Tests Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Tests Failed: $TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
  echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║   ✓ ALL TESTS PASSED                          ║${NC}"
  echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "${GREEN}Deployment is healthy and ready to use!${NC}"
  echo ""
  echo "Application URL: http://$ALB_URL"
  echo ""
  echo "Next steps:"
  echo "  1. Open the application in your browser"
  echo "  2. View CloudWatch dashboard:"
  echo "     https://console.aws.amazon.com/cloudwatch/home?region=$AWS_REGION#dashboards:name=Petshop-Observability-Demo"
  echo "  3. Test chaos engineering:"
  echo "     cd aws && ./test-chaos-scenarios.sh"
  echo ""
  exit 0
else
  echo -e "${RED}╔════════════════════════════════════════════════╗${NC}"
  echo -e "${RED}║   ✗ SOME TESTS FAILED                         ║${NC}"
  echo -e "${RED}╚════════════════════════════════════════════════╝${NC}"
  echo ""
  echo "Please check the failed components and review logs:"
  echo "  kubectl get pods -n $NAMESPACE"
  echo "  kubectl logs -n $NAMESPACE <pod-name>"
  echo ""
  exit 1
fi
