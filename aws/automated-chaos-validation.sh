#!/bin/bash

# Automated Chaos Engineering Validation Script
# This script tests all chaos scenarios and validates the implementation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test results
TESTS_PASSED=0
TESTS_FAILED=0
TEST_RESULTS=()

# Get ALB URL
ALB_URL=$(kubectl get ingress -n petshop-demo frontend-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)

if [ -z "$ALB_URL" ]; then
  echo -e "${RED}Error: Could not get ALB URL${NC}"
  exit 1
fi

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Automated Chaos Engineering Validation      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}ALB URL: ${GREEN}http://$ALB_URL${NC}"
echo ""

# Helper function to record test result
record_test() {
  local test_name=$1
  local result=$2
  local message=$3
  
  if [ "$result" = "PASS" ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    TEST_RESULTS+=("${GREEN}✓${NC} $test_name: $message")
    echo -e "${GREEN}✓ PASS${NC}: $test_name"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    TEST_RESULTS+=("${RED}✗${NC} $test_name: $message")
    echo -e "${RED}✗ FAIL${NC}: $test_name - $message"
  fi
}

# Test 1: Verify chaos simulator code is deployed
echo -e "${YELLOW}Test 1: Verifying chaos simulator code deployment...${NC}"
catalog_pod=$(kubectl get pods -n petshop-demo -l app=catalog-service -o jsonpath='{.items[0].metadata.name}')
if kubectl exec -n petshop-demo $catalog_pod -- ls /app/src/chaos_simulator.py > /dev/null 2>&1; then
  record_test "Chaos Code Deployment" "PASS" "chaos_simulator.py found in catalog-service"
else
  record_test "Chaos Code Deployment" "FAIL" "chaos_simulator.py not found"
fi
echo ""

# Test 2: Verify feature flag service is accessible
echo -e "${YELLOW}Test 2: Verifying feature flag service...${NC}"
flags_response=$(curl -s -w "%{http_code}" "http://${ALB_URL}/api/flags" -o /tmp/flags_response.json)
if [ "$flags_response" = "200" ]; then
  record_test "Feature Flag Service" "PASS" "Service responding with 200"
else
  record_test "Feature Flag Service" "FAIL" "Service returned $flags_response"
fi
echo ""

# Test 3: Verify chaos metrics endpoint
echo -e "${YELLOW}Test 3: Verifying chaos metrics endpoint...${NC}"
metrics_response=$(curl -s -w "%{http_code}" "http://${ALB_URL}/chaos/metrics" -o /tmp/metrics_response.json)
if [ "$metrics_response" = "200" ]; then
  record_test "Chaos Metrics Endpoint" "PASS" "Metrics endpoint responding"
else
  record_test "Chaos Metrics Endpoint" "FAIL" "Endpoint returned $metrics_response"
fi
echo ""

# Test 4: Test disk stress scenario
echo -e "${YELLOW}Test 4: Testing disk stress scenario...${NC}"
curl -s -X PUT "http://${ALB_URL}/api/flags/infrastructure_disk_stress" \
  -H "Content-Type: application/json" \
  -d '{"enabled":true,"description":"Simulates high disk I/O stress","config":{"intensityLevel":5,"durationSeconds":30}}' > /dev/null

sleep 5

# Generate some traffic
for i in {1..10}; do
  curl -s "http://${ALB_URL}/api/products" > /dev/null
  sleep 1
done

# Check logs for disk stress
disk_stress_logs=$(kubectl logs -n petshop-demo -l app=catalog-service --tail=100 | grep -i "disk.*stress\|CHAOS.*disk" | wc -l)
if [ "$disk_stress_logs" -gt 0 ]; then
  record_test "Disk Stress Scenario" "PASS" "Found $disk_stress_logs disk stress log entries"
else
  record_test "Disk Stress Scenario" "FAIL" "No disk stress logs found"
fi

# Disable flag
curl -s -X PUT "http://${ALB_URL}/api/flags/infrastructure_disk_stress" \
  -H "Content-Type: application/json" \
  -d '{"enabled":false,"description":"Simulates high disk I/O stress","config":{"intensityLevel":5,"durationSeconds":30}}' > /dev/null
echo ""

# Test 5: Test database connection failure scenario
echo -e "${YELLOW}Test 5: Testing database connection failure scenario...${NC}"
curl -s -X PUT "http://${ALB_URL}/api/flags/infrastructure_db_connection_fail" \
  -H "Content-Type: application/json" \
  -d '{"enabled":true,"description":"Simulates database connection failures","config":{"failureRate":80,"timeoutMs":1000}}' > /dev/null

sleep 5

# Generate traffic
for i in {1..10}; do
  curl -s "http://${ALB_URL}/api/products" > /dev/null
  sleep 1
done

# Check logs for DB failure simulation
db_failure_logs=$(kubectl logs -n petshop-demo -l app=catalog-service --tail=100 | grep -i "database connection failure\|CHAOS.*database" | wc -l)

if [ "$db_failure_logs" -gt 3 ]; then
  record_test "DB Connection Failure" "PASS" "Found $db_failure_logs DB failure log entries"
else
  record_test "DB Connection Failure" "FAIL" "Only $db_failure_logs DB failure logs found (expected more)"
fi

# Disable flag
curl -s -X PUT "http://${ALB_URL}/api/flags/infrastructure_db_connection_fail" \
  -H "Content-Type: application/json" \
  -d '{"enabled":false,"description":"Simulates database connection failures","config":{"failureRate":80,"timeoutMs":1000}}' > /dev/null
echo ""

# Test 6: Test network delay scenario
echo -e "${YELLOW}Test 6: Testing network delay scenario...${NC}"
curl -s -X PUT "http://${ALB_URL}/api/flags/infrastructure_network_delay" \
  -H "Content-Type: application/json" \
  -d '{"enabled":true,"description":"Simulates network latency between services","config":{"delayMs":1500,"jitterMs":300}}' > /dev/null

sleep 5

# Measure response time
start=$(date +%s%N)
curl -s "http://${ALB_URL}/api/products" > /dev/null
end=$(date +%s%N)
duration=$(( (end - start) / 1000000 ))

if [ "$duration" -gt 1000 ]; then
  record_test "Network Delay Scenario" "PASS" "Response time ${duration}ms (expected >1000ms)"
else
  record_test "Network Delay Scenario" "FAIL" "Response time ${duration}ms (expected >1000ms)"
fi

# Disable flag
curl -s -X PUT "http://${ALB_URL}/api/flags/infrastructure_network_delay" \
  -H "Content-Type: application/json" \
  -d '{"enabled":false,"description":"Simulates network latency between services","config":{"delayMs":1500,"jitterMs":300}}' > /dev/null
echo ""

# Test 7: Verify all chaos flags can be disabled
echo -e "${YELLOW}Test 7: Verifying chaos flags can be disabled...${NC}"
all_disabled=true

# Get descriptions for each flag
disk_desc="Simulates high disk I/O stress"
pod_desc="Causes pods to crash periodically"
db_desc="Simulates database connection failures"
net_desc="Simulates network latency between services"

# Disable each flag with proper description
curl -s -X PUT "http://${ALB_URL}/api/flags/infrastructure_disk_stress" \
  -H "Content-Type: application/json" \
  -d "{\"enabled\":false,\"description\":\"$disk_desc\",\"config\":{}}" > /dev/null

curl -s -X PUT "http://${ALB_URL}/api/flags/infrastructure_pod_crash" \
  -H "Content-Type: application/json" \
  -d "{\"enabled\":false,\"description\":\"$pod_desc\",\"config\":{}}" > /dev/null

curl -s -X PUT "http://${ALB_URL}/api/flags/infrastructure_db_connection_fail" \
  -H "Content-Type: application/json" \
  -d "{\"enabled\":false,\"description\":\"$db_desc\",\"config\":{}}" > /dev/null

curl -s -X PUT "http://${ALB_URL}/api/flags/infrastructure_network_delay" \
  -H "Content-Type: application/json" \
  -d "{\"enabled\":false,\"description\":\"$net_desc\",\"config\":{}}" > /dev/null

sleep 2

# Verify all are disabled
for flag in infrastructure_disk_stress infrastructure_pod_crash infrastructure_db_connection_fail infrastructure_network_delay; do
  flag_status=$(curl -s "http://${ALB_URL}/api/flags/${flag}" | grep -o '"enabled":[^,}]*' | cut -d':' -f2)
  if [ "$flag_status" != "false" ]; then
    all_disabled=false
  fi
done

if [ "$all_disabled" = true ]; then
  record_test "Disable All Chaos Flags" "PASS" "All flags successfully disabled"
else
  record_test "Disable All Chaos Flags" "FAIL" "Some flags could not be disabled"
fi
echo ""

# Test 8: Verify services recover after chaos
echo -e "${YELLOW}Test 8: Verifying service recovery...${NC}"
sleep 10

success_count=0
for i in {1..10}; do
  response=$(curl -s -w "%{http_code}" "http://${ALB_URL}/api/products" -o /dev/null)
  if [ "$response" = "200" ]; then
    success_count=$((success_count + 1))
  fi
  sleep 1
done

if [ "$success_count" -ge 8 ]; then
  record_test "Service Recovery" "PASS" "$success_count/10 requests successful after chaos disabled"
else
  record_test "Service Recovery" "FAIL" "Only $success_count/10 requests successful"
fi
echo ""

# Test 9: Verify CloudWatch alarms exist
echo -e "${YELLOW}Test 9: Verifying CloudWatch alarms...${NC}"
alarm_count=$(aws cloudwatch describe-alarms --region us-east-2 --alarm-name-prefix "Petshop-" --query 'length(MetricAlarms[?contains(AlarmName, `Chaos`)])' --output text 2>/dev/null || echo "0")

if [ "$alarm_count" -ge 4 ]; then
  record_test "CloudWatch Alarms" "PASS" "Found $alarm_count chaos-related alarms"
else
  record_test "CloudWatch Alarms" "FAIL" "Only found $alarm_count chaos alarms (expected 4)"
fi
echo ""

# Test 10: Verify pod health
echo -e "${YELLOW}Test 10: Verifying pod health...${NC}"
not_ready=$(kubectl get pods -n petshop-demo -o json | jq '[.items[] | select(.status.phase != "Running" or ([.status.conditions[] | select(.type == "Ready" and .status != "True")] | length) > 0)] | length')

if [ "$not_ready" = "0" ]; then
  record_test "Pod Health" "PASS" "All pods are healthy"
else
  record_test "Pod Health" "FAIL" "$not_ready pods are not ready"
fi
echo ""

# Print summary
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Validation Summary                           ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

for result in "${TEST_RESULTS[@]}"; do
  echo -e "$result"
done

echo ""
echo -e "${CYAN}Total Tests: $((TESTS_PASSED + TESTS_FAILED))${NC}"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo ""

if [ "$TESTS_FAILED" -eq 0 ]; then
  echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║   ✓ ALL TESTS PASSED                          ║${NC}"
  echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
  exit 0
else
  echo -e "${RED}╔════════════════════════════════════════════════╗${NC}"
  echo -e "${RED}║   ✗ SOME TESTS FAILED                         ║${NC}"
  echo -e "${RED}╚════════════════════════════════════════════════╝${NC}"
  exit 1
fi
