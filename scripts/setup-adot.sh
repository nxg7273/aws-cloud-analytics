#!/bin/bash

# Default values
CLUSTER_NAME=${CLUSTER_NAME:-"my-cluster"}
REGION=${AWS_REGION:-"us-east-1"}
EMAIL=${NOTIFICATION_EMAIL:-"anastasia.nayden@iff.com"}

# Function to check required environment variables
check_env_vars() {
  if [[ -z "${AWS_ACCESS_KEY_ID}" || -z "${AWS_SECRET_ACCESS_KEY}" ]]; then
    echo "Error: AWS credentials not set. Please set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY"
    exit 1
  fi
}

# Function to create Fargate profiles
create_fargate_profiles() {
  echo "Creating Fargate profiles..."
  eksctl create fargateprofile \
    --cluster ${CLUSTER_NAME} \
    --name fp-adot-collector \
    --namespace fargate-container-insights \
    --region ${REGION} || true

  eksctl create fargateprofile \
    --cluster ${CLUSTER_NAME} \
    --name fp-bioapptives \
    --namespace bioapptives \
    --region ${REGION} || true
}

# Function to setup ADOT collector
setup_adot_collector() {
  echo "Setting up ADOT collector..."
  kubectl apply -f kubernetes/cluster-info-configmap.yaml
  kubectl apply -f kubernetes/adot-collector-config.yaml
  kubectl apply -f kubernetes/adot-collector-deployment.yaml
}

# Function to setup monitoring
setup_monitoring() {
  echo "Setting up monitoring..."
  SNS_TOPIC_ARN=$(aws sns create-topic --name adot-alerts --output json | jq -r '.TopicArn')
  aws sns subscribe \
    --topic-arn ${SNS_TOPIC_ARN} \
    --protocol email \
    --notification-endpoint ${EMAIL}

  aws logs create-log-group --log-group-name "/aws/eks/${CLUSTER_NAME}/bioapptives" || true

  aws logs put-metric-filter \
    --log-group-name "/aws/eks/${CLUSTER_NAME}/bioapptives" \
    --filter-name "ErrorFilter" \
    --filter-pattern "?OperationalError ?\"Name or service not known\" ?\"Connection reset by peer\"" \
    --metric-transformations \
      metricName=ErrorCount,metricNamespace=Bioapptives,metricValue=1,defaultValue=0

  aws cloudwatch put-metric-alarm \
    --alarm-name "BioapptivesErrorAlarm" \
    --alarm-description "Alert on application errors in bioapptives namespace" \
    --metric-name "ErrorCount" \
    --namespace "Bioapptives" \
    --statistic Sum \
    --period 300 \
    --threshold 1 \
    --comparison-operator GreaterThanOrEqualToThreshold \
    --evaluation-periods 1 \
    --alarm-actions ${SNS_TOPIC_ARN}
}

# Main execution
check_env_vars
create_fargate_profiles
setup_adot_collector
setup_monitoring

echo "Setup complete. Please check your email to confirm the SNS subscription."
