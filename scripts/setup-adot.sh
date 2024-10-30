#!/bin/bash

# Exit on any error
set -e

# Required environment variables
if [ -z "$CLUSTER_NAME" ]; then
    echo "Error: CLUSTER_NAME environment variable is required"
    exit 1
fi

# Default values for other variables
REGION="${REGION:-us-east-1}"
SERVICE_ACCOUNT_NAME="adot-collector-script"
SERVICE_ACCOUNT_NAMESPACE="bioapptives"
SERVICE_ACCOUNT_IAM_ROLE="adot-collector-script-role"
POLICY_NAME="ADOTCollectorScriptPolicy"
SNS_TOPIC_NAME="bioapptives-alerts-script"
ALARM_PREFIX="Script-Bioapptives"

# Get script directory for relative paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

# Function to check if resource is Terraform managed
is_terraform_managed() {
    local resource_arn=$1
    local tags=$(aws iam list-role-tags --role-name "${resource_arn##*/}" 2>/dev/null || echo '{"Tags": []}')
    echo "$tags" | grep -q "Terraform" && return 0 || return 1
}

# Function to delete existing IAM service account
delete_service_account() {
    echo "Deleting existing IAM service account..."
    eksctl delete iamserviceaccount \
        --cluster=$CLUSTER_NAME \
        --region=$REGION \
        --name=$SERVICE_ACCOUNT_NAME \
        --namespace=$SERVICE_ACCOUNT_NAMESPACE || true
}

# Function to delete existing IAM policy
delete_iam_policy() {
    echo "Deleting existing IAM policy..."
    EXISTING_POLICY_ARN=$(aws iam list-policies --query "Policies[?PolicyName=='$POLICY_NAME'].Arn" --output text)
    if [ ! -z "$EXISTING_POLICY_ARN" ]; then
        if ! is_terraform_managed "$EXISTING_POLICY_ARN"; then
            aws iam delete-policy --policy-arn $EXISTING_POLICY_ARN || true
        else
            echo "Skipping deletion of Terraform-managed policy: $EXISTING_POLICY_ARN"
        fi
    fi
}

# Function to delete existing SNS topic
delete_sns_topic() {
    echo "Deleting existing SNS topic..."
    EXISTING_TOPIC_ARN=$(aws sns list-topics --region $REGION --query "Topics[?contains(TopicArn, '$SNS_TOPIC_NAME')].TopicArn" --output text)
    if [ ! -z "$EXISTING_TOPIC_ARN" ]; then
        local tags=$(aws sns list-tags-for-resource --resource-arn $EXISTING_TOPIC_ARN --region $REGION 2>/dev/null || echo '{"Tags": []}')
        if ! echo "$tags" | grep -q "Terraform"; then
            aws sns delete-topic --topic-arn $EXISTING_TOPIC_ARN --region $REGION || true
        else
            echo "Skipping deletion of Terraform-managed SNS topic: $EXISTING_TOPIC_ARN"
        fi
    fi
}

# Function to delete existing CloudWatch alarms
delete_cloudwatch_alarms() {
    echo "Deleting existing CloudWatch alarms..."
    local alarms=("${ALARM_PREFIX}OperationalError" "${ALARM_PREFIX}ConnectionError")
    for alarm in "${alarms[@]}"; do
        local tags=$(aws cloudwatch list-tags-for-resource --resource-arn "arn:aws:cloudwatch:${REGION}:$(aws sts get-caller-identity --query Account --output text):alarm:${alarm}" 2>/dev/null || echo '{"Tags": []}')
        if ! echo "$tags" | grep -q "Terraform"; then
            aws cloudwatch delete-alarms --alarm-names "$alarm" --region $REGION || true
        else
            echo "Skipping deletion of Terraform-managed alarm: $alarm"
        fi
    done
}

# Clean up existing resources
echo "Starting cleanup of existing resources..."
delete_service_account
delete_iam_policy
delete_sns_topic
delete_cloudwatch_alarms
echo "Cleanup completed."

# Create namespace if it doesn't exist
kubectl create namespace $SERVICE_ACCOUNT_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Create SNS topic for notifications
echo "Creating SNS topic for notifications..."
SNS_TOPIC_ARN=$(aws sns create-topic --name $SNS_TOPIC_NAME --region $REGION --tags Key=ManagedBy,Value=Script --output text --query 'TopicArn')
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
    --policy-name $POLICY_NAME \
    --policy-document file:///tmp/adot-collector-policy.json \
    --tags Key=ManagedBy,Value=Script \
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
kubectl apply -f "${REPO_ROOT}/kubernetes/adot-collector-config.yaml"

# Create CloudWatch alarms for specific error patterns
echo "Creating CloudWatch alarms..."
aws cloudwatch put-metric-alarm \
    --alarm-name "${ALARM_PREFIX}OperationalError" \
    --alarm-description "Alert for OperationalError in bioapptives-worker" \
    --metric-name "ErrorCount" \
    --namespace "BioapptivesErrors" \
    --statistic "Sum" \
    --period 300 \
    --threshold 1 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 1 \
    --alarm-actions $SNS_TOPIC_ARN \
    --tags Key=ManagedBy,Value=Script \
    --region $REGION

aws cloudwatch put-metric-alarm \
    --alarm-name "${ALARM_PREFIX}ConnectionError" \
    --alarm-description "Alert for Connection Reset errors in bioapptives-worker" \
    --metric-name "ConnectionErrorCount" \
    --namespace "BioapptivesErrors" \
    --statistic "Sum" \
    --period 300 \
    --threshold 1 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 1 \
    --alarm-actions $SNS_TOPIC_ARN \
    --tags Key=ManagedBy,Value=Script \
    --region $REGION

echo "ADOT setup completed successfully!"
