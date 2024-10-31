# AWS Cloud Analytics

This repository contains configurations for AWS Distro for OpenTelemetry (ADOT) collector and Fluent Bit to collect and monitor logs from EKS clusters.

## Overview

The setup includes:
- ADOT collector deployment in the fargate-container-insights namespace
- Log collection from bioapptives and marcador namespaces
- Error pattern monitoring and alerting
- CloudWatch integration
- SNS notifications for alerts

## Components

### ADOT Collector
- Deployed as a StatefulSet in the fargate-container-insights namespace
- Configured with OpenTelemetry protocol support (gRPC and HTTP)
- Resource limits: 1 CPU, 2Gi memory

### Log Collection
Collects logs from two namespaces:
1. bioapptives namespace
2. marcador namespace

### Error Pattern Monitoring
Monitors for specific error patterns:
- "kombu.exceptions.OperationalError: [Errno -2] Name or service not known"
- "consumer: Cannot connect to amqp://guest:**@rabbitmq-0.rabbitmq.bioapptives.svc.cluster.local:5672//"
- "ConnectionError due to connection reset by peer"

### CloudWatch Integration
- Log groups:
  - /aws/eks/${CLUSTER_NAME}/bioapptives
  - /aws/eks/${CLUSTER_NAME}/marcador
- Metric filters for error patterns
- CloudWatch alarms for error monitoring

### SNS Notifications
- Topic: adot-alerts
- Email notifications configured for: anastasia.nayden@iff.com
- Alerts triggered when error patterns are detected

## Setup Instructions

1. Clone the repository
2. Configure environment variables:
   - CLUSTER_NAME: Your EKS cluster name
   - REGION: AWS region
   - POD_NAME: ADOT collector pod name

3. Run the setup script:
   ```bash
   ./scripts/setup-adot.sh
   ```

## Configuration Details

### ADOT Collector Configuration
The ADOT collector is configured with:
- Receivers: OTLP (gRPC and HTTP)
- Processors:
  - Batch processor
  - Filter processors for namespace-specific logs
  - Filter processors for error pattern detection
- Exporters:
  - CloudWatch Metrics (awsemf)
  - Separate exporters for each namespace

### Log Pipeline Configuration
Four separate pipelines are configured:
1. bioapptives logs pipeline
2. bioapptives error monitoring pipeline
3. marcador logs pipeline
4. marcador error monitoring pipeline

## Monitoring and Alerting

### CloudWatch Metrics
- Namespace-specific metrics
- Error count metrics
- Custom metric declarations for monitoring

### Alerts
- SNS notifications for error patterns
- Email alerts to anastasia.nayden@iff.com
- Configurable alert thresholds

## Prerequisites
- AWS CLI configured with appropriate permissions
- kubectl access to the EKS cluster
- Necessary IAM roles and policies
- eksctl installed

## Notes
- The bioapptives and marcador namespaces must exist in the cluster
- ADOT collector uses AWS OpenTelemetry v0.32.0 syntax
- All logs from both namespaces are collected, not just errors
- Error monitoring is maintained separately from general log collection

## Troubleshooting
- Check ADOT collector logs in the fargate-container-insights namespace
- Verify CloudWatch log groups are receiving logs
- Confirm SNS topic subscription
- Check IAM roles and permissions
