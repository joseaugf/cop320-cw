#!/bin/bash
set -e

# Load configuration
source "$(dirname "$0")/config.sh"

echo "=== Setting up Application Signals and CloudWatch Logs ==="

# Get EKS cluster OIDC provider
OIDC_PROVIDER=$(aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION --query "cluster.identity.oidc.issuer" --output text | sed -e "s/^https:\/\///")
echo "OIDC Provider: $OIDC_PROVIDER"

# Create IAM policy for Application Signals and CloudWatch Logs
POLICY_NAME="petshop-demo-observability-policy"
echo "Creating IAM policy: $POLICY_NAME"

cat > /tmp/observability-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "xray:PutTraceSegments",
        "xray:PutTelemetryRecords",
        "xray:GetSamplingRules",
        "xray:GetSamplingTargets",
        "xray:GetSamplingStatisticSummaries"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:PutLogEvents",
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:DescribeLogStreams",
        "logs:DescribeLogGroups",
        "logs:PutRetentionPolicy"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "cloudwatch:PutMetricData",
        "ec2:DescribeVolumes",
        "ec2:DescribeTags",
        "ec2:DescribeInstances",
        "ec2:DescribeInstanceStatus"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter",
        "ssm:GetParameters"
      ],
      "Resource": "arn:aws:ssm:*:*:parameter/aws/service/eks/optimized-ami/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "application-signals:*"
      ],
      "Resource": "*"
    }
  ]
}
EOF

# Create or update the policy
POLICY_ARN=$(aws iam list-policies --query "Policies[?PolicyName=='$POLICY_NAME'].Arn" --output text)

if [ -z "$POLICY_ARN" ]; then
  echo "Creating new policy..."
  POLICY_ARN=$(aws iam create-policy \
    --policy-name $POLICY_NAME \
    --policy-document file:///tmp/observability-policy.json \
    --query 'Policy.Arn' \
    --output text)
  echo "Created policy: $POLICY_ARN"
else
  echo "Policy already exists: $POLICY_ARN"
  echo "Creating new policy version..."
  aws iam create-policy-version \
    --policy-arn $POLICY_ARN \
    --policy-document file:///tmp/observability-policy.json \
    --set-as-default
  echo "Updated policy version"
fi

# Create IAM role for ADOT Collector
ROLE_NAME="petshop-demo-adot-collector-role"
echo "Creating IAM role: $ROLE_NAME"

cat > /tmp/trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/${OIDC_PROVIDER}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${OIDC_PROVIDER}:sub": "system:serviceaccount:petshop-demo:adot-collector",
          "${OIDC_PROVIDER}:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
EOF

# Check if role exists
if aws iam get-role --role-name $ROLE_NAME 2>/dev/null; then
  echo "Role already exists, updating trust policy..."
  aws iam update-assume-role-policy \
    --role-name $ROLE_NAME \
    --policy-document file:///tmp/trust-policy.json
else
  echo "Creating new role..."
  aws iam create-role \
    --role-name $ROLE_NAME \
    --assume-role-policy-document file:///tmp/trust-policy.json \
    --description "IAM role for ADOT Collector with Application Signals"
fi

# Attach policy to role
echo "Attaching policy to role..."
aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn $POLICY_ARN

ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME}"
echo "Role ARN: $ROLE_ARN"

# Create IAM role for Fluent Bit
FLUENT_BIT_ROLE_NAME="petshop-demo-fluent-bit-role"
echo "Creating IAM role for Fluent Bit: $FLUENT_BIT_ROLE_NAME"

cat > /tmp/fluent-bit-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/${OIDC_PROVIDER}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${OIDC_PROVIDER}:sub": "system:serviceaccount:amazon-cloudwatch:fluent-bit",
          "${OIDC_PROVIDER}:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
EOF

if aws iam get-role --role-name $FLUENT_BIT_ROLE_NAME 2>/dev/null; then
  echo "Fluent Bit role already exists, updating trust policy..."
  aws iam update-assume-role-policy \
    --role-name $FLUENT_BIT_ROLE_NAME \
    --policy-document file:///tmp/fluent-bit-trust-policy.json
else
  echo "Creating new Fluent Bit role..."
  aws iam create-role \
    --role-name $FLUENT_BIT_ROLE_NAME \
    --assume-role-policy-document file:///tmp/fluent-bit-trust-policy.json \
    --description "IAM role for Fluent Bit to send logs to CloudWatch"
fi

# Attach CloudWatch policy to Fluent Bit role
echo "Attaching CloudWatch policy to Fluent Bit role..."
aws iam attach-role-policy \
  --role-name $FLUENT_BIT_ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy

FLUENT_BIT_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${FLUENT_BIT_ROLE_NAME}"
echo "Fluent Bit Role ARN: $FLUENT_BIT_ROLE_ARN"

# Update service account annotations
echo "Updating ADOT Collector service account..."
kubectl annotate serviceaccount adot-collector \
  -n petshop-demo \
  eks.amazonaws.com/role-arn=$ROLE_ARN \
  --overwrite

# Update Fluent Bit service account
echo "Updating Fluent Bit service account..."
kubectl annotate serviceaccount fluent-bit \
  -n amazon-cloudwatch \
  eks.amazonaws.com/role-arn=$FLUENT_BIT_ROLE_ARN \
  --overwrite || echo "Fluent Bit service account will be created with deployment"

# Deploy Application Signals configuration
echo "Deploying Application Signals configuration..."
kubectl apply -f k8s/61-application-signals.yaml

# Deploy Fluent Bit
echo "Deploying Fluent Bit for CloudWatch Logs..."
kubectl apply -f k8s/62-fluent-bit-logs.yaml

# Wait for pods to be ready
echo "Waiting for ADOT Collector pods to be ready..."
kubectl rollout status daemonset/adot-collector -n petshop-demo --timeout=300s

echo "Waiting for Fluent Bit pods to be ready..."
kubectl rollout status daemonset/fluent-bit -n amazon-cloudwatch --timeout=300s

echo ""
echo "✓ Application Signals and CloudWatch Logs setup complete!"
echo ""
echo "Verification:"
echo "  kubectl get pods -n petshop-demo -l app=adot-collector"
echo "  kubectl get pods -n amazon-cloudwatch -l k8s-app=fluent-bit"
echo ""
echo "CloudWatch Log Groups created:"
echo "  - /aws/eks/petshop-demo/application (Application logs)"
echo "  - /aws/eks/petshop-demo/dataplane (System logs)"
echo "  - /aws/application-signals/data (Application Signals metrics)"
echo ""
echo "View in AWS Console:"
echo "  - CloudWatch > Application Signals"
echo "  - CloudWatch > Log groups"
echo "  - X-Ray > Service map"

# Cleanup temp files
rm -f /tmp/observability-policy.json /tmp/trust-policy.json /tmp/fluent-bit-trust-policy.json
