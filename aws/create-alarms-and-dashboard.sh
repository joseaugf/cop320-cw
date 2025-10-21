#!/bin/bash
set -e

# Load configuration
source "$(dirname "$0")/config.sh"

echo "=== Creating CloudWatch Alarms and Dashboard ==="

# Create SNS topic for alarms (optional - for notifications)
echo "Creating SNS topic for alarm notifications..."
SNS_TOPIC_ARN=$(aws sns create-topic \
  --name petshop-demo-alarms \
  --region $AWS_REGION \
  --query 'TopicArn' \
  --output text 2>/dev/null || aws sns list-topics --region $AWS_REGION --query "Topics[?contains(TopicArn, 'petshop-demo-alarms')].TopicArn" --output text)

echo "SNS Topic ARN: $SNS_TOPIC_ARN"

# Create Alarms
echo ""
echo "Creating CloudWatch Alarms..."

# 1. High Error Rate Alarm
echo "Creating High Error Rate alarm..."
aws cloudwatch put-metric-alarm \
  --alarm-name "Petshop-HighErrorRate" \
  --alarm-description "Triggers when error rate exceeds 10%" \
  --metric-name error_count \
  --namespace PetshopDemo \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 10 \
  --comparison-operator GreaterThanThreshold \
  --treat-missing-data notBreaching \
  --region $AWS_REGION

# 2. High Latency Alarm
echo "Creating High Latency alarm..."
aws cloudwatch put-metric-alarm \
  --alarm-name "Petshop-HighLatency" \
  --alarm-description "Triggers when response time exceeds 2 seconds" \
  --metric-name request_duration \
  --namespace PetshopDemo \
  --statistic Average \
  --period 300 \
  --evaluation-periods 2 \
  --threshold 2000 \
  --comparison-operator GreaterThanThreshold \
  --treat-missing-data notBreaching \
  --region $AWS_REGION

# 3. Catalog Service Errors
echo "Creating Catalog Service Error alarm..."
aws cloudwatch put-metric-alarm \
  --alarm-name "Petshop-CatalogServiceErrors" \
  --alarm-description "Triggers when catalog service has errors" \
  --metric-name error_count \
  --namespace PetshopDemo \
  --dimensions Name=service,Value=catalog-service \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 5 \
  --comparison-operator GreaterThanThreshold \
  --treat-missing-data notBreaching \
  --region $AWS_REGION

# 4. Checkout Service Errors
echo "Creating Checkout Service Error alarm..."
aws cloudwatch put-metric-alarm \
  --alarm-name "Petshop-CheckoutServiceErrors" \
  --alarm-description "Triggers when checkout service has errors" \
  --metric-name error_count \
  --namespace PetshopDemo \
  --dimensions Name=service,Value=checkout-service \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 3 \
  --comparison-operator GreaterThanThreshold \
  --treat-missing-data notBreaching \
  --region $AWS_REGION

# 5. Cart Service High Memory
echo "Creating Cart Service Memory alarm..."
aws cloudwatch put-metric-alarm \
  --alarm-name "Petshop-CartServiceHighMemory" \
  --alarm-description "Triggers when cart service memory usage is high" \
  --metric-name memory_usage_mb \
  --namespace PetshopDemo \
  --dimensions Name=service,Value=cart-service \
  --statistic Average \
  --period 300 \
  --evaluation-periods 2 \
  --threshold 500 \
  --comparison-operator GreaterThanThreshold \
  --treat-missing-data notBreaching \
  --region $AWS_REGION

echo ""
echo "✓ Alarms created successfully"

# Create Dashboard
echo ""
echo "Creating CloudWatch Dashboard..."

cat > /tmp/dashboard.json << 'EOF'
{
  "widgets": [
    {
      "type": "metric",
      "properties": {
        "metrics": [
          [ "PetshopDemo", "request_count", { "stat": "Sum", "label": "Total Requests" } ]
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "us-east-2",
        "title": "Total Requests",
        "period": 300,
        "yAxis": {
          "left": {
            "min": 0
          }
        }
      },
      "width": 12,
      "height": 6,
      "x": 0,
      "y": 0
    },
    {
      "type": "metric",
      "properties": {
        "metrics": [
          [ "PetshopDemo", "error_count", { "stat": "Sum", "label": "Total Errors", "color": "#d62728" } ]
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "us-east-2",
        "title": "Error Count",
        "period": 300,
        "yAxis": {
          "left": {
            "min": 0
          }
        }
      },
      "width": 12,
      "height": 6,
      "x": 12,
      "y": 0
    },
    {
      "type": "metric",
      "properties": {
        "metrics": [
          [ "PetshopDemo", "request_duration", { "stat": "Average", "label": "Avg Latency (ms)" } ],
          [ "...", { "stat": "p99", "label": "P99 Latency (ms)" } ]
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "us-east-2",
        "title": "Response Time",
        "period": 300,
        "yAxis": {
          "left": {
            "min": 0
          }
        }
      },
      "width": 12,
      "height": 6,
      "x": 0,
      "y": 6
    },
    {
      "type": "metric",
      "properties": {
        "metrics": [
          [ "PetshopDemo", "error_count", "service", "catalog-service", { "stat": "Sum", "label": "Catalog Errors" } ],
          [ "...", "cart-service", { "stat": "Sum", "label": "Cart Errors" } ],
          [ "...", "checkout-service", { "stat": "Sum", "label": "Checkout Errors" } ],
          [ "...", "feature-flag-service", { "stat": "Sum", "label": "Feature Flag Errors" } ]
        ],
        "view": "timeSeries",
        "stacked": true,
        "region": "us-east-2",
        "title": "Errors by Service",
        "period": 300
      },
      "width": 12,
      "height": 6,
      "x": 12,
      "y": 6
    },
    {
      "type": "metric",
      "properties": {
        "metrics": [
          [ "PetshopDemo", "request_count", "service", "catalog-service", { "stat": "Sum" } ],
          [ "...", "cart-service", { "stat": "Sum" } ],
          [ "...", "checkout-service", { "stat": "Sum" } ],
          [ "...", "feature-flag-service", { "stat": "Sum" } ]
        ],
        "view": "timeSeries",
        "stacked": true,
        "region": "us-east-2",
        "title": "Requests by Service",
        "period": 300
      },
      "width": 12,
      "height": 6,
      "x": 0,
      "y": 12
    },
    {
      "type": "metric",
      "properties": {
        "metrics": [
          [ "PetshopDemo", "request_duration", "service", "catalog-service", { "stat": "Average" } ],
          [ "...", "cart-service", { "stat": "Average" } ],
          [ "...", "checkout-service", { "stat": "Average" } ],
          [ "...", "feature-flag-service", { "stat": "Average" } ]
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "us-east-2",
        "title": "Latency by Service (ms)",
        "period": 300
      },
      "width": 12,
      "height": 6,
      "x": 12,
      "y": 12
    },
    {
      "type": "metric",
      "properties": {
        "metrics": [
          [ "PetshopDemo", "memory_usage_mb", "service", "cart-service", { "stat": "Average", "label": "Cart Memory (MB)" } ]
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "us-east-2",
        "title": "Cart Service Memory Usage",
        "period": 300,
        "yAxis": {
          "left": {
            "min": 0
          }
        }
      },
      "width": 12,
      "height": 6,
      "x": 0,
      "y": 18
    },
    {
      "type": "log",
      "properties": {
        "query": "SOURCE '/aws/eks/petshop-demo/application'\n| fields @timestamp, kubernetes.labels.app as service, log\n| filter log like /ERROR|error|Error/\n| sort @timestamp desc\n| limit 20",
        "region": "us-east-2",
        "stacked": false,
        "title": "Recent Errors",
        "view": "table"
      },
      "width": 12,
      "height": 6,
      "x": 12,
      "y": 18
    },
    {
      "type": "metric",
      "properties": {
        "metrics": [
          [ "PetshopDemo", "flag_change", "flag_name", "catalog_high_latency", { "stat": "Sum", "label": "Catalog High Latency" } ],
          [ "...", "catalog_error_rate", { "stat": "Sum", "label": "Catalog Errors" } ],
          [ "...", "checkout_errors", { "stat": "Sum", "label": "Checkout Errors" } ],
          [ "...", "cart_memory_leak", { "stat": "Sum", "label": "Cart Memory Leak" } ]
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "us-east-2",
        "title": "Feature Flag Changes",
        "period": 300
      },
      "width": 24,
      "height": 6,
      "x": 0,
      "y": 24
    },
    {
      "type": "metric",
      "properties": {
        "metrics": [
          [ "PetshopDemo/Chaos", "DiskStressEvents", { "stat": "Sum", "label": "Disk Stress", "color": "#ff7f0e" } ],
          [ ".", "PodCrashEvents", { "stat": "Sum", "label": "Pod Crashes", "color": "#d62728" } ],
          [ ".", "DBConnectionFailures", { "stat": "Sum", "label": "DB Failures", "color": "#9467bd" } ],
          [ ".", "NetworkDelayEvents", { "stat": "Sum", "label": "Network Delays", "color": "#8c564b" } ]
        ],
        "view": "timeSeries",
        "stacked": true,
        "region": "us-east-2",
        "title": "Chaos Engineering Events",
        "period": 300,
        "yAxis": {
          "left": {
            "min": 0
          }
        }
      },
      "width": 24,
      "height": 6,
      "x": 0,
      "y": 30
    }
  ]
}
EOF

# Create the dashboard
aws cloudwatch put-dashboard \
  --dashboard-name "Petshop-Observability-Demo" \
  --dashboard-body file:///tmp/dashboard.json \
  --region $AWS_REGION

echo ""
echo "✓ Dashboard created successfully"

# Cleanup
rm -f /tmp/dashboard.json

echo ""
echo "=== Setup Complete ==="
echo ""
echo "📊 Dashboard URL:"
echo "https://console.aws.amazon.com/cloudwatch/home?region=${AWS_REGION}#dashboards:name=Petshop-Observability-Demo"
echo ""
echo "🔔 Alarms created:"
echo "  - Petshop-HighErrorRate"
echo "  - Petshop-HighLatency"
echo "  - Petshop-CatalogServiceErrors"
echo "  - Petshop-CheckoutServiceErrors"
echo "  - Petshop-CartServiceHighMemory"
echo ""
echo "View alarms at:"
echo "https://console.aws.amazon.com/cloudwatch/home?region=${AWS_REGION}#alarmsV2:"
echo ""
echo "💡 To test the alarms:"
echo "  1. Enable feature flags in the admin page"
echo "  2. Generate traffic to the application"
echo "  3. Wait 5-10 minutes for alarms to trigger"
