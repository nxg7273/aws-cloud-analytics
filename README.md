# EKS Monitoring Project

This project sets up a detailed tracking system for monitoring metrics of all pods in an Amazon EKS cluster, including their names, services within the pods, as well as CPU and memory usage. It also integrates AWS CloudWatch and AWS Distro for OpenTelemetry for comprehensive monitoring.

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform installed
- kubectl installed
- Docker installed
- Python 3.x with boto3, pandas, and matplotlib libraries

## Setup Instructions

1. Configure AWS CLI:
   ```
   aws configure
   ```

2. Initialize Terraform:
   ```
   cd terraform
   terraform init
   ```

3. Apply Terraform configuration:
   ```
   terraform apply
   ```

4. Configure kubectl to use the new EKS cluster:
   ```
   aws eks --region $(terraform output -raw region) update-kubeconfig --name $(terraform output -raw cluster_name)
   ```

5. Deploy ADOT Collector for bioapptives namespace:
   ```bash
   # Make the setup script executable
   chmod +x scripts/setup-adot.sh

   # Set required environment variables
   export CLUSTER_NAME="my-cluster"
   export REGION="us-east-1"

   # Run the setup script
   ./scripts/setup-adot.sh
   ```

6. Verify deployment:
   ```bash
   kubectl get pods -n bioapptives
   kubectl get services -n bioapptives
   ```

7. Confirm SNS subscription:
   Check your email (anastasia.nayden@iff.com) for the SNS subscription confirmation.

## Dashboard Usage Guide

1. Access the AWS CloudWatch console:
   - Go to the AWS Management Console
   - Navigate to CloudWatch service

2. Find the "ContainerInsights" dashboard:
   - In the CloudWatch sidebar, click on "Dashboards"
   - Look for a dashboard named "ContainerInsights-protein-engineering-cluster-new"

3. Interpreting the dashboard:
   - CPU Utilization: Shows the CPU usage across all pods
   - Memory Utilization: Displays memory consumption of pods
   - Network RX/TX: Indicates network traffic in and out of pods
   - Pod Status: Provides an overview of running, pending, and failed pods

4. Using custom metrics:
   - Click on "Add widget" to create custom visualizations
   - Select "Metrics" as the widget type
   - Choose "ContainerInsights" as the namespace
   - Pick desired metrics and customize the graph as needed

5. Setting up alarms:
   - From the dashboard, click on a metric graph
   - Select "Create alarm" from the Actions menu
   - Configure threshold and notification settings

## Troubleshooting

If you encounter issues, please check the following:

1. AWS CLI Configuration:
   ```
   aws configure list
   aws sts get-caller-identity
   ```
   Ensure your credentials are correct and have necessary permissions.

2. Terraform State:
   ```
   terraform show
   ```
   Verify that all resources are properly created.

3. EKS Cluster Status:
   ```
   aws eks describe-cluster --name protein-engineering-cluster-new
   ```
   Check if the cluster is active and properly configured.

4. ADOT Collector Logs:
    ```bash
    kubectl logs -l app=adot-collector -n bioapptives
    ```
    Look for any error messages or configuration issues in the logs.

    To verify error pattern monitoring:
    ```bash
    # Check CloudWatch alarms status
    aws cloudwatch describe-alarms \
      --alarm-names BioapptivesOperationalError BioapptivesConnectionError

    # Check SNS subscriptions
    aws sns list-subscriptions
    ```

5. CloudWatch Logs:
   - Check the CloudWatch Log groups for any error messages
   - Verify that metrics are being received in the ContainerInsights namespace

6. IAM Roles and Policies:
   - Ensure that the EKS cluster and Fargate profiles have the correct IAM roles attached
   - Verify that the roles have the necessary permissions for CloudWatch and ADOT

For more detailed troubleshooting, refer to the AWS EKS and ADOT documentation.

## Best Practices for Ongoing Management

1. Regular Updates:
   - Keep AWS CLI, Terraform, and kubectl up to date
   - Regularly update the ADOT Collector to the latest version

2. Monitoring and Alerting:
    - CloudWatch Alarms are configured for specific error patterns in bioapptives namespace:
      - OperationalError monitoring
      - Connection reset errors
      - AMQP connection issues
    - SNS notifications are sent to anastasia.nayden@iff.com
    - Error patterns monitored include:
      ```
      kombu.exceptions.OperationalError: [Errno -2] Name or service not known
      consumer: Cannot connect to amqp://guest:**@rabbitmq-0.rabbitmq.bioapptives.svc.cluster.local:5672//
      ConnectionError due to connection reset by peer
      ```

3. Cost Optimization:
   - Regularly review and optimize your EKS cluster size
   - Use Fargate profiles efficiently to manage compute resources

4. Security:
   - Rotate AWS access keys regularly
   - Use IAM roles with least privilege principle
   - Keep your EKS cluster updated with the latest security patches

5. Backup and Disaster Recovery:
   - Regularly backup your Terraform state
   - Consider using multiple availability zones for high availability

6. Performance Tuning:
   - Use the correlation script (correlate_metrics.py) to identify performance bottlenecks
   - Adjust resource allocation based on observed metrics

7. Documentation:
   - Keep this README and other documentation up to date
   - Document any custom configurations or scripts added to the project

By following these best practices, you can ensure the reliability, security, and efficiency of your EKS monitoring system.
