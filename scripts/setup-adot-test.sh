#!/bin/bash

# Mock AWS commands for testing
function aws() {
    case "$1" in
        "iam")
            case "$2" in
                "list-policies")
                    echo '{"Policies": [{"Arn": "arn:aws:iam::123456789012:policy/ADOTCollectorScriptPolicy"}]}'
                    ;;
                "list-role-tags")
                    if [[ "$4" == *"terraform"* ]]; then
                        echo '{"Tags": [{"Key": "Terraform", "Value": "true"}]}'
                    else
                        echo '{"Tags": [{"Key": "ManagedBy", "Value": "Script"}]}'
                    fi
                    ;;
                "create-policy")
                    echo '{"Policy": {"Arn": "arn:aws:iam::123456789012:policy/ADOTCollectorScriptPolicy"}}'
                    ;;
                "delete-policy")
                    echo "Policy deleted"
                    ;;
            esac
            ;;
        "sns")
            case "$2" in
                "list-topics")
                    echo '{"Topics": [{"TopicArn": "arn:aws:sns:us-east-1:123456789012:bioapptives-alerts-script"}]}'
                    ;;
                "list-tags-for-resource")
                    if [[ "$4" == *"terraform"* ]]; then
                        echo '{"Tags": [{"Key": "Terraform", "Value": "true"}]}'
                    else
                        echo '{"Tags": [{"Key": "ManagedBy", "Value": "Script"}]}'
                    fi
                    ;;
                "create-topic")
                    echo '{"TopicArn": "arn:aws:sns:us-east-1:123456789012:bioapptives-alerts-script"}'
                    ;;
                "subscribe")
                    echo '{"SubscriptionArn": "arn:aws:sns:us-east-1:123456789012:bioapptives-alerts-script:1234567890"}'
                    ;;
            esac
            ;;
        "cloudwatch")
            case "$2" in
                "list-tags-for-resource")
                    if [[ "$4" == *"terraform"* ]]; then
                        echo '{"Tags": [{"Key": "Terraform", "Value": "true"}]}'
                    else
                        echo '{"Tags": [{"Key": "ManagedBy", "Value": "Script"}]}'
                    fi
                    ;;
                "put-metric-alarm")
                    echo "Alarm created"
                    ;;
                "delete-alarms")
                    echo "Alarms deleted"
                    ;;
            esac
            ;;
        "sts")
            case "$2" in
                "get-caller-identity")
                    echo '{"Account": "123456789012"}'
                    ;;
            esac
            ;;
    esac
}

# Mock eksctl command
function eksctl() {
    case "$1" in
        "create")
            echo "Creating IAM service account"
            ;;
        "delete")
            echo "Deleting IAM service account"
            ;;
    esac
}

# Mock kubectl command
function kubectl() {
    case "$1" in
        "create")
            echo "Creating Kubernetes resource"
            ;;
        "apply")
            echo "Applying Kubernetes configuration"
            ;;
        "delete")
            echo "Deleting Kubernetes resource"
            ;;
    esac
}

# Export mock functions
export -f aws
export -f eksctl
export -f kubectl

# Run tests
echo "=== Testing with script-managed resources ==="
export CLUSTER_NAME="test-cluster"
bash ./scripts/setup-adot.sh

echo -e "\n=== Testing with Terraform-managed resources ==="
# Override aws function for Terraform resources
aws() {
    echo '{"Tags": [{"Key": "Terraform", "Value": "true"}]}'
}
export -f aws
export CLUSTER_NAME="test-cluster-terraform"
bash ./scripts/setup-adot.sh

echo -e "\n=== Testing with mixed resources ==="
# Override aws function for mixed resources
aws() {
    if [[ "$*" == *"script"* ]]; then
        echo '{"Tags": [{"Key": "ManagedBy", "Value": "Script"}]}'
    else
        echo '{"Tags": [{"Key": "Terraform", "Value": "true"}]}'
    fi
}
export -f aws
export CLUSTER_NAME="test-cluster-mixed"
bash ./scripts/setup-adot.sh
