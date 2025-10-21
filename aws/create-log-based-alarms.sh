#!/bin/bash
set -e

# Load configuration
source "$(dirname "$0")/config.sh"

echo "=== Creating Log-Based Alarms ==="

LOG_GROUP="/aws/eks/petshop-demo/application"

# Create metric filters from logs
echo "Creating metric filters..."

# 1. Error Count Metric Filter
echo "Creating error count metric filter..."
aws logs put-metric-filter \
  --log-group-name "$LOG_GROUP" \
  --filter-name "PetshopErrorCount" \
  --filter-pattern '[timestamp, level=ERROR* || level=error*, ...]' \
  --metric-transformations \
    metricName=ErrorCount,metricNamespace=PetshopDemo/Logs,metricValue=1,defaultValue=0 \
  --region $AWS_REGION

# 2. High Latency Metric Filter (for catalog service)
echo "Creating high latency metric filter..."
aws logs put-metric-filter \
  --log-group-name "$LOG_GROUP" \
  --filter-name "PetshopHighLatency" \
  --filter-pattern '[..., msg="*high latency*" || msg="*Simulating high latency*"]' \
  --metric-transformations \
    metricName=HighLatencyEvents,metricNamespace=PetshopDemo/Logs,metricValue=1,defaultValue=0 \
  --region $AWS_REGION

# 3. Catalog Service Errors
echo "Creating catalog service error metric filter..."
aws logs put-metric-filter \
  --log-group-name "$LOG_GROUP" \
  --filter-name "PetshopCatalogErrors" \
  --filter-pattern '{ ($.kubernetes.labels.app = "catalog-service") && (($.log = "*ERROR*") || ($.log = "*error*")) }' \
  --metric-transformations \
    metricName=CatalogErrors,metricNamespace=PetshopDemo/Logs,metricValue=1,defaultValue=0 \
  --region $AWS_REGION

# 4. Checkout Service Errors
echo "Creating checkout service error metric filter..."
aws logs put-metric-filter \
  --log-group-name "$LOG_GROUP" \
  --filter-name "PetshopCheckoutErrors" \
  --filter-pattern '{ ($.kubernetes.labels.app = "checkout-service") && (($.log = "*ERROR*") || ($.log = "*error*")) }' \
  --metric-transformations \
    metricName=CheckoutErrors,metricNamespace=PetshopDemo/Logs,metricValue=1,defaultValue=0 \
  --region $AWS_REGION

echo ""
echo "✓ Metric filters created"

# Create SNS topic for alarms
echo ""
echo "Creating SNS topic..."
SNS_TOPIC_ARN=$(aws sns create-topic \
  --name petshop-demo-alarms \
  --region $AWS_REGION \
  --query 'TopicArn' \
  --output text 2>/dev/null || aws sns list-topics --region $AWS_REGION --query "Topics[?contains(TopicArn, 'petshop-demo-alarms')].TopicArn" --output text)

echo "SNS Topic ARN: $SNS_TOPIC_ARN"

# Create Alarms based on log metrics
echo ""
echo "Creating CloudWatch Alarms..."

# 1. High Error Rate Alarm
echo "Creating High Error Rate alarm..."
aws cloudwatch put-metric-alarm \
  --alarm-name "Petshop-HighErrorRate-Logs" \
  --alarm-description "Triggers when error rate from logs exceeds 5 in 5 minutes" \
  --metric-name ErrorCount \
  --namespace PetshopDemo/Logs \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 5 \
  --comparison-operator GreaterThanThreshold \
  --treat-missing-data notBreaching \
  --region $AWS_REGION

# 2. High Latency Alarm
echo "Creating High Latency alarm..."
aws cloudwatch put-metric-alarm \
  --alarm-name "Petshop-HighLatency-Logs" \
  --alarm-description "Triggers when high latency events are detected" \
  --metric-name HighLatencyEvents \
  --namespace PetshopDemo/Logs \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 3 \
  --comparison-operator GreaterThanThreshold \
  --treat-missing-data notBreaching \
  --region $AWS_REGION

# 3. Catalog Service Errors
echo "Creating Catalog Service Error alarm..."
aws cloudwatch put-metric-alarm \
  --alarm-name "Petshop-CatalogErrors-Logs" \
  --alarm-description "Triggers when catalog service has errors in logs" \
  --metric-name CatalogErrors \
  --namespace PetshopDemo/Logs \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 3 \
  --comparison-operator GreaterThanThreshold \
  --treat-missing-data notBreaching \
  --region $AWS_REGION

# 4. Checkout Service Errors
echo "Creating Checkout Service Error alarm..."
aws cloudwatch put-metric-alarm \
  --alarm-name "Petshop-CheckoutErrors-Logs" \
  --alarm-description "Triggers when checkout service has errors in logs" \
  --metric-name CheckoutErrors \
  --namespace PetshopDemo/Logs \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 2 \
  --comparison-operator GreaterThanThreshold \
  --treat-missing-data notBreaching \
  --region $AWS_REGION

echo ""
echo "✓ Alarms created successfully"

echo ""
echo "=== Setup Complete ==="
echo ""
echo "🔔 Log-based alarms created:"
echo "  - Petshop-HighErrorRate-Logs"
echo "  - Petshop-HighLatency-Logs"
echo "  - Petshop-CatalogErrors-Logs"
echo "  - Petshop-CheckoutErrors-Logs"
echo ""
echo "📊 Metric filters created in log group: $LOG_GROUP"
echo ""
echo "View alarms at:"
echo "https://console.aws.amazon.com/cloudwatch/home?region=${AWS_REGION}#alarmsV2:"
echo ""
echo "💡 To test:"
echo "  1. Enable feature flags (catalog_high_latency, catalog_error_rate)"
echo "  2. Run: ./generate-traffic.sh"
echo "  3. Wait 5-10 minutes"
echo "  4. Check alarms in CloudWatch console"
