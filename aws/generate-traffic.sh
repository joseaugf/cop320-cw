#!/bin/bash

# Get ALB URL
ALB_URL=$(kubectl get ingress -n petshop-demo frontend-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

if [ -z "$ALB_URL" ]; then
  echo "Error: Could not get ALB URL"
  exit 1
fi

echo "=== Traffic Generator for Petshop Demo ==="
echo "ALB URL: http://$ALB_URL"
echo ""
echo "Select a scenario:"
echo "1. Normal traffic (no errors)"
echo "2. High latency scenario"
echo "3. High error rate scenario"
echo "4. Checkout errors scenario"
echo "5. Memory leak scenario"
echo "6. All scenarios (chaos!)"
echo ""
read -p "Enter choice [1-6]: " choice

case $choice in
  1)
    echo "Generating normal traffic..."
    for i in {1..50}; do
      curl -s "http://$ALB_URL/api/products" > /dev/null
      echo -n "."
      sleep 0.5
    done
    ;;
  2)
    echo "First, enable 'catalog_high_latency' flag in admin page"
    read -p "Press Enter when ready..."
    echo "Generating traffic with high latency..."
    for i in {1..30}; do
      curl -s "http://$ALB_URL/api/products" > /dev/null
      echo -n "."
      sleep 1
    done
    ;;
  3)
    echo "First, enable 'catalog_error_rate' flag with 50% error rate"
    read -p "Press Enter when ready..."
    echo "Generating traffic to trigger errors..."
    for i in {1..50}; do
      response=$(curl -s -w "%{http_code}" "http://$ALB_URL/api/products" -o /dev/null)
      if [ "$response" != "200" ]; then
        echo -n "E"
      else
        echo -n "."
      fi
      sleep 0.3
    done
    ;;
  4)
    echo "First, enable 'checkout_errors' flag with 40% error rate"
    read -p "Press Enter when ready..."
    echo "Generating checkout traffic..."
    for i in {1..20}; do
      # Simulate checkout
      curl -s -X POST "http://$ALB_URL/api/checkout" \
        -H "Content-Type: application/json" \
        -d '{"items":[{"product_id":"test","quantity":1}],"total":10.00}' > /dev/null
      echo -n "."
      sleep 1
    done
    ;;
  5)
    echo "First, enable 'cart_memory_leak' flag with 10 MB/min"
    read -p "Press Enter when ready..."
    echo "Generating cart traffic to trigger memory leak..."
    for i in {1..100}; do
      # Add to cart
      curl -s -X POST "http://$ALB_URL/api/cart" \
        -H "Content-Type: application/json" \
        -d '{"product_id":"test-'$i'","quantity":1}' > /dev/null
      echo -n "."
      sleep 0.5
    done
    ;;
  6)
    echo "CHAOS MODE! Enable all flags first:"
    echo "  - catalog_high_latency (2000ms)"
    echo "  - catalog_error_rate (30%)"
    echo "  - checkout_errors (40%)"
    echo "  - cart_memory_leak (10 MB/min)"
    read -p "Press Enter when ready..."
    echo "Generating chaotic traffic..."
    for i in {1..100}; do
      # Random endpoint
      endpoint=$((RANDOM % 4))
      case $endpoint in
        0) curl -s "http://$ALB_URL/api/products" > /dev/null ;;
        1) curl -s "http://$ALB_URL/api/cart" > /dev/null ;;
        2) curl -s -X POST "http://$ALB_URL/api/checkout" \
             -H "Content-Type: application/json" \
             -d '{"items":[],"total":0}' > /dev/null ;;
        3) curl -s "http://$ALB_URL/api/flags" > /dev/null ;;
      esac
      echo -n "."
      sleep 0.2
    done
    ;;
  *)
    echo "Invalid choice"
    exit 1
    ;;
esac

echo ""
echo ""
echo "✓ Traffic generation complete!"
echo ""
echo "Next steps:"
echo "1. Wait 5-10 minutes for metrics to appear"
echo "2. Check the dashboard:"
echo "   https://console.aws.amazon.com/cloudwatch/home?region=us-east-2#dashboards:name=Petshop-Observability-Demo"
echo "3. Check alarms:"
echo "   https://console.aws.amazon.com/cloudwatch/home?region=us-east-2#alarmsV2:"
echo "4. Check X-Ray traces:"
echo "   https://console.aws.amazon.com/xray/home?region=us-east-2#/service-map"
