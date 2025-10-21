#!/bin/bash
# Verify all critical files exist before pushing to GitHub

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Verifying critical files for automated deployment..."
echo ""

MISSING=0
FOUND=0

check_file() {
  local file=$1
  if [ -f "$file" ]; then
    echo -e "${GREEN}✓${NC} $file"
    FOUND=$((FOUND + 1))
  else
    echo -e "${RED}✗${NC} $file - MISSING!"
    MISSING=$((MISSING + 1))
  fi
}

echo "=== Core Deployment Files ==="
check_file "buildspec-full-deploy.yml"
check_file "scripts/generate-k8s-manifests.py"
check_file "scripts/full-deploy.sh"
check_file "scripts/validate-deployment.sh"
echo ""

echo "=== CloudFormation Templates ==="
check_file "aws/cloudformation/eks-infrastructure.yaml"
check_file "aws/cloudformation/codebuild-deployment.yaml"
echo ""

echo "=== AWS Scripts ==="
check_file "aws/install-alb-controller.sh"
check_file "aws/setup-application-signals.sh"
check_file "aws/create-alarms-and-dashboard.sh"
check_file "aws/create-chaos-alarms.sh"
check_file "aws/create-log-based-alarms.sh"
check_file "aws/config.sh"
echo ""

echo "=== Kubernetes Manifests ==="
check_file "k8s/10-postgresql.yaml"
check_file "k8s/20-catalog-service.yaml"
check_file "k8s/25-cart-service.yaml"
check_file "k8s/30-checkout-service.yaml"
check_file "k8s/30-frontend.yaml"
check_file "k8s/35-feature-flag-service.yaml"
check_file "k8s/35-frontend-ingress.yaml"
check_file "k8s/40-adot-collector.yaml"
echo ""

echo "=== AWS Kubernetes Manifests ==="
check_file "aws/k8s/60-adot-collector.yaml"
check_file "aws/k8s/61-application-signals.yaml"
check_file "aws/k8s/62-fluent-bit-logs.yaml"
check_file "aws/k8s/35-frontend-ingress.yaml"
echo ""

echo "=== Service Dockerfiles ==="
check_file "catalog-service/Dockerfile"
check_file "cart-service/Dockerfile"
check_file "checkout-service/Dockerfile"
check_file "feature-flag-service/Dockerfile"
check_file "frontend/Dockerfile"
echo ""

echo "=== Chaos Engineering ==="
check_file "catalog-service/src/chaos_simulator.py"
check_file "cart-service/src/chaos-simulator.ts"
check_file "checkout-service/src/chaos_simulator.py"
check_file "aws/test-chaos-scenarios.sh"
check_file "aws/verify-chaos-safety.sh"
echo ""

echo "=== Documentation ==="
check_file "README.md"
check_file "DEPLOYMENT.md"
check_file "QUICKSTART.md"
check_file ".gitignore"
echo ""

echo "=== Summary ==="
echo -e "${GREEN}Found: $FOUND${NC}"
echo -e "${RED}Missing: $MISSING${NC}"
echo ""

if [ $MISSING -eq 0 ]; then
  echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║   ✓ ALL CRITICAL FILES PRESENT                ║${NC}"
  echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
  echo ""
  echo "Ready to push to GitHub!"
  echo ""
  echo "Next steps:"
  echo "  1. git add ."
  echo "  2. git commit -m 'Add automated deployment'"
  echo "  3. git push origin main"
  echo ""
  exit 0
else
  echo -e "${RED}╔════════════════════════════════════════════════╗${NC}"
  echo -e "${RED}║   ✗ MISSING CRITICAL FILES                    ║${NC}"
  echo -e "${RED}╚════════════════════════════════════════════════╝${NC}"
  echo ""
  echo "Please ensure all critical files are present before pushing."
  echo ""
  exit 1
fi
