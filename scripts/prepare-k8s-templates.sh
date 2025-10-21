#!/bin/bash
# Prepare Kubernetes manifests as templates
# This script updates existing manifests to use placeholders

set -e

echo "Preparing Kubernetes templates..."

# Update catalog service
sed -i.bak 's|image: petshop/catalog-service:latest|image: ${CATALOG_IMAGE}|g' k8s/20-catalog-service.yaml
sed -i.bak 's|image: .*catalog-service:latest|image: ${CATALOG_IMAGE}|g' k8s/20-catalog-service.yaml

# Update cart service  
sed -i.bak 's|image: petshop/cart-service:latest|image: ${CART_IMAGE}|g' k8s/25-cart-service.yaml
sed -i.bak 's|image: .*cart-service:latest|image: ${CART_IMAGE}|g' k8s/25-cart-service.yaml

# Update checkout service
sed -i.bak 's|image: petshop/checkout-service:latest|image: ${CHECKOUT_IMAGE}|g' k8s/30-checkout-service.yaml  
sed -i.bak 's|image: .*checkout-service:latest|image: ${CHECKOUT_IMAGE}|g' k8s/30-checkout-service.yaml

# Update feature flag service
sed -i.bak 's|image: petshop/feature-flag-service:latest|image: ${FEATURE_FLAG_IMAGE}|g' k8s/35-feature-flag-service.yaml
sed -i.bak 's|image: .*feature-flag-service:latest|image: ${FEATURE_FLAG_IMAGE}|g' k8s/35-feature-flag-service.yaml

# Update frontend
sed -i.bak 's|image: petshop/frontend:latest|image: ${FRONTEND_IMAGE}|g' k8s/30-frontend.yaml
sed -i.bak 's|image: .*frontend:latest|image: ${FRONTEND_IMAGE}|g' k8s/30-frontend.yaml

# Update PostgreSQL password
sed -i.bak 's|password: changeme123|password: ${DB_PASSWORD}|g' k8s/10-postgresql.yaml

# Update namespace references
for file in k8s/*.yaml aws/k8s/*.yaml; do
  if [ -f "$file" ]; then
    sed -i.bak 's|namespace: petshop-demo|namespace: ${NAMESPACE}|g' "$file"
  fi
done

# Clean up backup files
find k8s/ aws/k8s/ -name "*.bak" -delete

echo "✓ Templates prepared"
