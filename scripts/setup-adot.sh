#!/bin/bash

# Exit on any error
set -e

# Default values
CLUSTER_NAME="my-cluster"
REGION="us-east-1"
SERVICE_ACCOUNT_NAME="adot-collector"
SERVICE_ACCOUNT_NAMESPACE="bioapptives"
SERVICE_ACCOUNT_IAM_ROLE="adot-collector-role"

# Create namespace if it doesn't exist
kubectl create namespace $SERVICE_ACCOUNT_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Create SNS topic for notifications
echo "Creating SNS topic for notifications..."
SNS_TOPIC_ARN=$(aws sns create-topic --name bioapptives-alerts --region $REGION --output text --query 'TopicArn')
aws sns subscribe \
    --topic-arn $SNS_TOPIC_ARN \
    --protocol email \
    --notification-endpoint "anastasia.nayden@iff.com" \
    --region $REGION

# Install ADOT Operator
echo "Installing ADOT Operator..."
kubectl apply -f https://amazon-eks.s3.amazonaws.com/docs/addons-otel-permissions.yaml

# Create IAM policy for ADOT Collector
echo "Creating IAM policy for ADOT Collector..."
cat << EOF > /tmp/adot-collector-policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "cloudwatch:PutMetricData",
                "cloudwatch:GetMetricData",
                "cloudwatch:PutMetricAlarm",
                "cloudwatch:DescribeAlarms",
                "cloudwatch:DeleteAlarms",
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents",
                "logs:DescribeLogStreams",
                "sns:Publish"
            ],
            "Resource": "*"
        }
    ]
}
EOF

POLICY_ARN=$(aws iam create-policy \
    --policy-name ADOTCollectorPolicy \
    --policy-document file:///tmp/adot-collector-policy.json \
    --query 'Policy.Arn' \
    --output text)

# Create service account with eksctl
echo "Creating service account with eksctl..."
eksctl create iamserviceaccount \
    --cluster=$CLUSTER_NAME \
    --region=$REGION \
    --name=$SERVICE_ACCOUNT_NAME \
    --namespace=$SERVICE_ACCOUNT_NAMESPACE \
    --role-name=$SERVICE_ACCOUNT_IAM_ROLE \
    --attach-policy-arn=$POLICY_ARN \
    --override-existing-serviceaccounts \
    --approve

# Apply ADOT Collector configuration
echo "Applying ADOT Collector configuration..."
kubectl apply -f ../kubernetes/adot-collector-config.yaml

# Create CloudWatch alarms for specific error patterns
echo "Creating CloudWatch alarms..."
aws cloudwatch put-metric-alarm \
    --alarm-name "BioapptivesOperationalError" \
    --alarm-description "Alert for OperationalError in bioapptives-worker" \
    --metric-name "ErrorCount" \
    --namespace "BioapptivesErrors" \
    --statistic "Sum" \
    --period 300 \
    --threshold 1 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 1 \
    --alarm-actions $SNS_TOPIC_ARN \
    --region $REGION

aws cloudwatch put-metric-alarm \
    --alarm-name "BioapptivesConnectionError" \
    --alarm-description "Alert for Connection Reset errors in bioapptives-worker" \
    --metric-name "ConnectionErrorCount" \
    --namespace "BioapptivesErrors" \
    --statistic "Sum" \
    --period 300 \
    --threshold 1 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 1 \
    --alarm-actions $SNS_TOPIC_ARN \
    --region $REGION

echo "ADOT setup completed successfully!"
