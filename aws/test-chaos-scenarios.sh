#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Get ALB URL
get_alb_url() {
  ALB_URL=$(kubectl get ingress -n petshop-demo frontend-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
  
  if [ -z "$ALB_URL" ]; then
    echo -e "${RED}Error: Could not get ALB URL${NC}"
    echo "Make sure you have deployed the application to EKS"
    exit 1
  fi
  
  echo "$ALB_URL"
}

# Enable a chaos flag
enable_chaos_flag() {
  local flag_name=$1
  local config=$2
  local alb_url=$3
  
  echo -e "${CYAN}Enabling flag: ${flag_name}${NC}"
  
  response=$(curl -s -X PUT "http://${alb_url}/api/flags/${flag_name}" \
    -H "Content-Type: application/json" \
    -d "{\"enabled\":true,\"config\":${config}}")
  
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Flag enabled successfully${NC}"
    return 0
  else
    echo -e "${RED}✗ Failed to enable flag${NC}"
    return 1
  fi
}

# Disable a chaos flag
disable_chaos_flag() {
  local flag_name=$1
  local alb_url=$2
  
  echo -e "${CYAN}Disabling flag: ${flag_name}${NC}"
  
  response=$(curl -s -X PUT "http://${alb_url}/api/flags/${flag_name}" \
    -H "Content-Type: application/json" \
    -d '{"enabled":false}')
  
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Flag disabled${NC}"
    return 0
  else
    echo -e "${RED}✗ Failed to disable flag${NC}"
    return 1
  fi
}

# Generate traffic
generate_traffic() {
  local alb_url=$1
  local count=$2
  local delay=$3
  
  echo -e "${CYAN}Generating ${count} requests...${NC}"
  
  for i in $(seq 1 $count); do
    # Rotate through different endpoints
    endpoint=$((i % 4))
    case $endpoint in
      0) curl -s "http://${alb_url}/api/products" > /dev/null ;;
      1) curl -s "http://${alb_url}/api/cart/test-session-${i}" > /dev/null ;;
      2) curl -s "http://${alb_url}/api/flags" > /dev/null ;;
      3) curl -s -X POST "http://${alb_url}/api/cart/test-session-${i}" \
           -H "Content-Type: application/json" \
           -d '{"productId":"test-product","quantity":1}' > /dev/null ;;
    esac
    echo -n "."
    sleep $delay
  done
  
  echo ""
  echo -e "${GREEN}✓ Traffic generation complete${NC}"
}

# Show monitoring instructions
show_monitoring_instructions() {
  local scenario=$1
  local alb_url=$2
  
  echo ""
  echo -e "${YELLOW}=== Monitoring Instructions ===${NC}"
  echo ""
  echo "1. Watch pod status:"
  echo "   kubectl get pods -n petshop-demo -w"
  echo ""
  echo "2. View service logs:"
  echo "   kubectl logs -n petshop-demo -l app=catalog-service --tail=50 -f"
  echo "   kubectl logs -n petshop-demo -l app=cart-service --tail=50 -f"
  echo "   kubectl logs -n petshop-demo -l app=checkout-service --tail=50 -f"
  echo ""
  echo "3. Check chaos metrics:"
  echo "   curl http://${alb_url}/chaos/metrics"
  echo ""
  echo "4. CloudWatch Logs Insights queries:"
  echo "   - Disk stress events:"
  echo "     fields @timestamp, @message | filter @message like /disk I\/O stress/ | sort @timestamp desc"
  echo ""
  echo "   - Pod crash events:"
  echo "     fields @timestamp, @message | filter @message like /pod crash/ | sort @timestamp desc"
  echo ""
  echo "   - DB connection failures:"
  echo "     fields @timestamp, @message | filter @message like /database connection failure/ | sort @timestamp desc"
  echo ""
  echo "   - Network delay events:"
  echo "     fields @timestamp, @message | filter @message like /network delay/ | sort @timestamp desc"
  echo ""
  echo "5. CloudWatch Dashboard:"
  echo "   https://console.aws.amazon.com/cloudwatch/home?region=us-east-2#dashboards:name=Petshop-Observability-Demo"
  echo ""
  echo "6. CloudWatch Alarms:"
  echo "   https://console.aws.amazon.com/cloudwatch/home?region=us-east-2#alarmsV2:"
  echo ""
  echo "7. X-Ray Service Map:"
  echo "   https://console.aws.amazon.com/xray/home?region=us-east-2#/service-map"
  echo ""
}

# Test Scenario 1: Disk I/O Stress
test_disk_stress() {
  local alb_url=$1
  
  echo ""
  echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║     Scenario 1: Disk I/O Stress Test          ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
  echo ""
  echo "This scenario simulates high disk I/O stress on services."
  echo "Expected effects:"
  echo "  - Increased disk read/write operations"
  echo "  - Higher CPU usage"
  echo "  - Increased response latency"
  echo "  - Logs showing disk stress simulation"
  echo ""
  read -p "Press Enter to start the test..."
  
  # Enable disk stress flag
  config='{"intensityLevel":7,"durationSeconds":60}'
  enable_chaos_flag "infrastructure_disk_stress" "$config" "$alb_url"
  
  echo ""
  echo -e "${YELLOW}Waiting 5 seconds for simulation to activate...${NC}"
  sleep 5
  
  # Generate traffic
  generate_traffic "$alb_url" 30 1
  
  echo ""
  echo -e "${GREEN}✓ Disk stress test running${NC}"
  echo -e "${YELLOW}The simulation will run for 60 seconds${NC}"
  
  show_monitoring_instructions "disk_stress" "$alb_url"
  
  read -p "Press Enter to disable the chaos flag..."
  disable_chaos_flag "infrastructure_disk_stress" "$alb_url"
}

# Test Scenario 2: Pod Crash
test_pod_crash() {
  local alb_url=$1
  
  echo ""
  echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║     Scenario 2: Pod Crash Test                ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
  echo ""
  echo "This scenario causes pods to crash periodically."
  echo "Expected effects:"
  echo "  - Pods will restart (check with kubectl get pods -w)"
  echo "  - Brief service interruptions"
  echo "  - Increased pod restart count"
  echo "  - Logs showing crash simulation before exit"
  echo ""
  echo -e "${RED}WARNING: This will cause pods to crash and restart!${NC}"
  echo ""
  read -p "Press Enter to start the test..."
  
  # Enable pod crash flag with high probability for demo
  config='{"crashIntervalMinutes":1,"crashProbability":80}'
  enable_chaos_flag "infrastructure_pod_crash" "$config" "$alb_url"
  
  echo ""
  echo -e "${YELLOW}Waiting 10 seconds for simulation to activate...${NC}"
  sleep 10
  
  # Generate traffic
  generate_traffic "$alb_url" 20 2
  
  echo ""
  echo -e "${GREEN}✓ Pod crash test running${NC}"
  echo -e "${YELLOW}Pods will crash within the next 1-2 minutes${NC}"
  
  show_monitoring_instructions "pod_crash" "$alb_url"
  
  echo ""
  echo -e "${RED}IMPORTANT: Disable this flag to stop pod crashes${NC}"
  read -p "Press Enter to disable the chaos flag..."
  disable_chaos_flag "infrastructure_pod_crash" "$alb_url"
}

# Test Scenario 3: Database Connection Failures
test_db_failures() {
  local alb_url=$1
  
  echo ""
  echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║     Scenario 3: Database Connection Failures  ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
  echo ""
  echo "This scenario simulates database connection failures."
  echo "Expected effects:"
  echo "  - Intermittent 500 errors"
  echo "  - Increased error rate in metrics"
  echo "  - Logs showing simulated DB failures"
  echo "  - X-Ray traces showing failed DB operations"
  echo ""
  read -p "Press Enter to start the test..."
  
  # Enable DB failure flag
  config='{"failureRate":50,"timeoutMs":1000}'
  enable_chaos_flag "infrastructure_db_connection_fail" "$config" "$alb_url"
  
  echo ""
  echo -e "${YELLOW}Waiting 5 seconds for simulation to activate...${NC}"
  sleep 5
  
  # Generate traffic to catalog service (uses DB)
  echo -e "${CYAN}Generating requests to catalog service...${NC}"
  for i in $(seq 1 40); do
    response=$(curl -s -w "%{http_code}" "http://${alb_url}/api/products" -o /dev/null)
    if [ "$response" != "200" ]; then
      echo -n -e "${RED}E${NC}"
    else
      echo -n -e "${GREEN}.${NC}"
    fi
    sleep 0.5
  done
  
  echo ""
  echo -e "${GREEN}✓ Database failure test complete${NC}"
  
  show_monitoring_instructions "db_failures" "$alb_url"
  
  read -p "Press Enter to disable the chaos flag..."
  disable_chaos_flag "infrastructure_db_connection_fail" "$alb_url"
}

# Test Scenario 4: Network Delay
test_network_delay() {
  local alb_url=$1
  
  echo ""
  echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║     Scenario 4: Network Delay Test            ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
  echo ""
  echo "This scenario simulates network latency between services."
  echo "Expected effects:"
  echo "  - Increased response times"
  echo "  - Higher latency in metrics"
  echo "  - X-Ray traces showing additional delay"
  echo "  - Logs showing network delay simulation"
  echo ""
  read -p "Press Enter to start the test..."
  
  # Enable network delay flag
  config='{"delayMs":2000,"jitterMs":500}'
  enable_chaos_flag "infrastructure_network_delay" "$config" "$alb_url"
  
  echo ""
  echo -e "${YELLOW}Waiting 5 seconds for simulation to activate...${NC}"
  sleep 5
  
  # Generate traffic and measure response times
  echo -e "${CYAN}Generating requests and measuring response times...${NC}"
  for i in $(seq 1 20); do
    start=$(date +%s%N)
    curl -s "http://${alb_url}/api/products" > /dev/null
    end=$(date +%s%N)
    duration=$(( (end - start) / 1000000 ))
    echo "Request $i: ${duration}ms"
    sleep 1
  done
  
  echo ""
  echo -e "${GREEN}✓ Network delay test complete${NC}"
  
  show_monitoring_instructions "network_delay" "$alb_url"
  
  read -p "Press Enter to disable the chaos flag..."
  disable_chaos_flag "infrastructure_network_delay" "$alb_url"
}

# Test Scenario 5: Combined Chaos
test_combined_chaos() {
  local alb_url=$1
  
  echo ""
  echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║     Scenario 5: Combined Chaos Test           ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
  echo ""
  echo "This scenario enables multiple chaos simulations simultaneously."
  echo "Expected effects:"
  echo "  - All chaos effects combined"
  echo "  - High system stress"
  echo "  - Multiple types of failures"
  echo "  - Complex failure scenarios"
  echo ""
  echo -e "${RED}WARNING: This will enable multiple chaos scenarios!${NC}"
  echo ""
  read -p "Press Enter to start the test..."
  
  # Enable multiple chaos flags
  echo ""
  echo -e "${CYAN}Enabling multiple chaos scenarios...${NC}"
  
  enable_chaos_flag "infrastructure_disk_stress" '{"intensityLevel":5,"durationSeconds":120}' "$alb_url"
  sleep 2
  
  enable_chaos_flag "infrastructure_db_connection_fail" '{"failureRate":30,"timeoutMs":800}' "$alb_url"
  sleep 2
  
  enable_chaos_flag "infrastructure_network_delay" '{"delayMs":1500,"jitterMs":300}' "$alb_url"
  
  echo ""
  echo -e "${YELLOW}Waiting 10 seconds for simulations to activate...${NC}"
  sleep 10
  
  # Generate sustained traffic
  echo -e "${CYAN}Generating sustained traffic...${NC}"
  for i in $(seq 1 50); do
    endpoint=$((i % 4))
    case $endpoint in
      0) curl -s "http://${alb_url}/api/products" > /dev/null ;;
      1) curl -s "http://${alb_url}/api/cart/chaos-session-${i}" > /dev/null ;;
      2) curl -s "http://${alb_url}/api/flags" > /dev/null ;;
      3) curl -s -X POST "http://${alb_url}/api/checkout" \
           -H "Content-Type: application/json" \
           -d '{"items":[],"total":0}' > /dev/null ;;
    esac
    echo -n "."
    sleep 1
  done
  
  echo ""
  echo -e "${GREEN}✓ Combined chaos test running${NC}"
  
  show_monitoring_instructions "combined_chaos" "$alb_url"
  
  echo ""
  echo -e "${RED}IMPORTANT: Disable all flags to stop chaos${NC}"
  read -p "Press Enter to disable all chaos flags..."
  
  disable_chaos_flag "infrastructure_disk_stress" "$alb_url"
  disable_chaos_flag "infrastructure_db_connection_fail" "$alb_url"
  disable_chaos_flag "infrastructure_network_delay" "$alb_url"
}

# View System Metrics
view_system_metrics() {
  local alb_url=$1
  
  echo ""
  echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║     System Metrics                             ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
  echo ""
  
  echo -e "${CYAN}Fetching metrics from all services...${NC}"
  echo ""
  
  # Try to get metrics from catalog service
  echo -e "${YELLOW}Catalog Service Metrics:${NC}"
  catalog_metrics=$(curl -s "http://${alb_url}/chaos/metrics" 2>/dev/null)
  if [ $? -eq 0 ] && [ -n "$catalog_metrics" ]; then
    echo "$catalog_metrics" | python3 -m json.tool 2>/dev/null || echo "$catalog_metrics"
  else
    echo "Unable to fetch metrics"
  fi
  
  echo ""
  echo -e "${YELLOW}Pod Status:${NC}"
  kubectl get pods -n petshop-demo
  
  echo ""
  echo -e "${YELLOW}Pod Resource Usage:${NC}"
  kubectl top pods -n petshop-demo 2>/dev/null || echo "Metrics server not available"
  
  echo ""
  read -p "Press Enter to return to menu..."
}

# Disable All Chaos
disable_all_chaos() {
  local alb_url=$1
  
  echo ""
  echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║     Disable All Chaos Scenarios               ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
  echo ""
  
  echo -e "${CYAN}Disabling all chaos flags...${NC}"
  echo ""
  
  disable_chaos_flag "infrastructure_disk_stress" "$alb_url"
  disable_chaos_flag "infrastructure_pod_crash" "$alb_url"
  disable_chaos_flag "infrastructure_db_connection_fail" "$alb_url"
  disable_chaos_flag "infrastructure_network_delay" "$alb_url"
  
  echo ""
  echo -e "${GREEN}✓ All chaos scenarios disabled${NC}"
  echo ""
  echo "Services should return to normal operation."
  echo ""
  read -p "Press Enter to return to menu..."
}

# Main menu
show_menu() {
  clear
  echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║   Chaos Engineering Test Script               ║${NC}"
  echo -e "${BLUE}║   Petshop Observability Demo                   ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "${CYAN}ALB URL: ${GREEN}http://$ALB_URL${NC}"
  echo ""
  echo "Select a chaos scenario to test:"
  echo ""
  echo "  1. Disk I/O Stress Test"
  echo "  2. Pod Crash Test"
  echo "  3. Database Connection Failures"
  echo "  4. Network Delay Test"
  echo "  5. Combined Chaos (multiple scenarios)"
  echo "  6. View System Metrics"
  echo "  7. Disable All Chaos"
  echo "  8. Exit"
  echo ""
}

# Main script
main() {
  echo -e "${CYAN}Initializing chaos testing script...${NC}"
  
  # Get ALB URL
  ALB_URL=$(get_alb_url)
  
  while true; do
    show_menu
    read -p "Enter choice [1-8]: " choice
    
    case $choice in
      1) test_disk_stress "$ALB_URL" ;;
      2) test_pod_crash "$ALB_URL" ;;
      3) test_db_failures "$ALB_URL" ;;
      4) test_network_delay "$ALB_URL" ;;
      5) test_combined_chaos "$ALB_URL" ;;
      6) view_system_metrics "$ALB_URL" ;;
      7) disable_all_chaos "$ALB_URL" ;;
      8)
        echo ""
        echo -e "${GREEN}Exiting chaos testing script${NC}"
        echo ""
        exit 0
        ;;
      *)
        echo -e "${RED}Invalid choice. Please select 1-8.${NC}"
        sleep 2
        ;;
    esac
  done
}

# Run main
main
