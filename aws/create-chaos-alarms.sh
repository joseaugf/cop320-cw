#!/bin/bash
set -e

# Load configuration
source "$(dirname "$0")/config.sh"

echo "=== Creating Chaos Engineering Alarms ==="

LOG_GROUP="/aws/eks/petshop-demo/application"

# Create metric filters for chaos events
echo "Creating chaos event metric filters..."

# 1. Disk Stress Events Metric Filter
echo "Creating disk stress events metric filter..."
aws logs put-metric-filter \
  --log-group-name "$LOG_GROUP" \
  --filter-name "PetshopDiskStressEvents" \
  --filter-pattern '[..., msg="*disk I/O stress*" || msg="*CHAOS: Starting disk*" || msg="*CHAOS: Disk stress*"]' \
  --metric-transformations \
    metricName=DiskStressEvents,metricNamespace=PetshopDemo/Chaos,metricValue=1,defaultValue=0 \
  --region $AWS_REGION

# 2. Pod Crash Events Metric Filter
echo "Creating pod crash events metric filter..."
aws logs put-metric-filter \
  --log-group-name "$LOG_GROUP" \
  --filter-name "PetshopPodCrashEvents" \
  --filter-pattern '[..., msg="*pod crash*" || msg="*CHAOS: Simulating pod crash*" || msg="*CHAOS: Pod crash*"]' \
  --metric-transformations \
    metricName=PodCrashEvents,metricNamespace=PetshopDemo/Chaos,metricValue=1,defaultValue=0 \
  --region $AWS_REGION

# 3. Database Connection Failure Events Metric Filter
echo "Creating database connection failure metric filter..."
aws logs put-metric-filter \
  --log-group-name "$LOG_GROUP" \
  --filter-name "PetshopDBConnectionFailures" \
  --filter-pattern '[..., msg="*database connection failure*" || msg="*CHAOS: Simulated database*" || msg="*CHAOS: DB connection*"]' \
  --metric-transformations \
    metricName=DBConnectionFailures,metricNamespace=PetshopDemo/Chaos,metricValue=1,defaultValue=0 \
  --region $AWS_REGION

# 4. Network Delay Events Metric Filter
echo "Creating network delay events metric filter..."
aws logs put-metric-filter \
  --log-group-name "$LOG_GROUP" \
  --filter-name "PetshopNetworkDelayEvents" \
  --filter-pattern '[..., msg="*network delay*" || msg="*CHAOS: Simulating network*" || msg="*CHAOS: Network delay*"]' \
  --metric-transformations \
    metricName=NetworkDelayEvents,metricNamespace=PetshopDemo/Chaos,metricValue=1,defaultValue=0 \
  --region $AWS_REGION

echo ""
echo "✓ Chaos metric filters created"

# Create SNS topic for alarms (reuse existing or create new)
echo ""
echo "Checking SNS topic..."
SNS_TOPIC_ARN=$(aws sns create-topic \
  --name petshop-demo-alarms \
  --region $AWS_REGION \
  --query 'TopicArn' \
  --output text 2>/dev/null || aws sns list-topics --region $AWS_REGION --query "Topics[?contains(TopicArn, 'petshop-demo-alarms')].TopicArn" --output text)

echo "SNS Topic ARN: $SNS_TOPIC_ARN"

# Create CloudWatch Alarms for chaos events
echo ""
echo "Creating CloudWatch Alarms for chaos events..."

# 1. Disk Stress Events Alarm
echo "Creating Disk Stress Events alarm..."
aws cloudwatch put-metric-alarm \
  --alarm-name "Petshop-DiskStress-Chaos" \
  --alarm-description "Triggers when disk I/O stress chaos events are detected" \
  --metric-name DiskStressEvents \
  --namespace PetshopDemo/Chaos \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 1 \
  --comparison-operator GreaterThanThreshold \
  --treat-missing-data notBreaching \
  --region $AWS_REGION

# 2. Pod Crash Events Alarm
echo "Creating Pod Crash Events alarm..."
aws cloudwatch put-metric-alarm \
  --alarm-name "Petshop-PodCrash-Chaos" \
  --alarm-description "Triggers when pod crash chaos events are detected" \
  --metric-name PodCrashEvents \
  --namespace PetshopDemo/Chaos \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 1 \
  --comparison-operator GreaterThanThreshold \
  --treat-missing-data notBreaching \
  --region $AWS_REGION

# 3. Database Connection Failures Alarm
echo "Creating Database Connection Failures alarm..."
aws cloudwatch put-metric-alarm \
  --alarm-name "Petshop-DBFailure-Chaos" \
  --alarm-description "Triggers when database connection failure chaos events are detected" \
  --metric-name DBConnectionFailures \
  --namespace PetshopDemo/Chaos \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 3 \
  --comparison-operator GreaterThanThreshold \
  --treat-missing-data notBreaching \
  --region $AWS_REGION

# 4. Network Delay Events Alarm
echo "Creating Network Delay Events alarm..."
aws cloudwatch put-metric-alarm \
  --alarm-name "Petshop-NetworkDelay-Chaos" \
  --alarm-description "Triggers when network delay chaos events are detected" \
  --metric-name NetworkDelayEvents \
  --namespace PetshopDemo/Chaos \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 5 \
  --comparison-operator GreaterThanThreshold \
  --treat-missing-data notBreaching \
  --region $AWS_REGION

echo ""
echo "✓ Chaos alarms created successfully"

echo ""
echo "=== Setup Complete ==="
echo ""
echo "🔔 Chaos engineering alarms created:"
echo "  - Petshop-DiskStress-Chaos (threshold: 1 event in 5 min)"
echo "  - Petshop-PodCrash-Chaos (threshold: 1 event in 5 min)"
echo "  - Petshop-DBFailure-Chaos (threshold: 3 events in 5 min)"
echo "  - Petshop-NetworkDelay-Chaos (threshold: 5 events in 5 min)"
echo ""
echo "📊 Metric filters created in log group: $LOG_GROUP"
echo "📈 Metrics namespace: PetshopDemo/Chaos"
echo ""
echo "View alarms at:"
echo "https://console.aws.amazon.com/cloudwatch/home?region=${AWS_REGION}#alarmsV2:"
echo ""
echo "💡 To test chaos scenarios:"
echo "  1. Enable chaos feature flags via API or Admin UI:"
echo "     - infrastructure_disk_stress"
echo "     - infrastructure_pod_crash"
echo "     - infrastructure_db_connection_fail"
echo "     - infrastructure_network_delay"
echo "  2. Generate traffic: ./generate-traffic.sh"
echo "  3. Wait 5-10 minutes for metrics to populate"
echo "  4. Check alarms in CloudWatch console"
echo ""
echo "📝 View logs with chaos events:"
echo "aws logs tail $LOG_GROUP --follow --filter-pattern 'CHAOS' --region $AWS_REGION"
