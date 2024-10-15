# Update the AWS provider region and add data source for existing EKS cluster
provider "aws" {
  region = "us-east-1"
}

data "aws_eks_cluster" "existing_cluster" {
  name = "protein-engineering-cluster-new"
}

data "aws_eks_cluster_auth" "existing_cluster_auth" {
  name = "protein-engineering-cluster-new"
}

# Configure the Kubernetes provider
provider "kubernetes" {
  host                   = data.aws_eks_cluster.existing_cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.existing_cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.existing_cluster_auth.token
}

# IAM role for ADOT Collector
resource "aws_iam_role" "adot_collector_role" {
  name = "adot-collector-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks-fargate-pods.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "adot_collector_cloudwatch_policy" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.adot_collector_role.name
}

resource "aws_iam_role_policy_attachment" "adot_collector_xray_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
  role       = aws_iam_role.adot_collector_role.name
}

resource "aws_iam_role_policy" "adot_collector_eks_policy" {
  name = "adot-collector-eks-policy"
  role = aws_iam_role.adot_collector_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "ec2:DescribeInstances",
          "ec2:DescribeTags",
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
      }
    ]
  })
}

# Output the endpoint of the cluster
output "cluster_endpoint" {
  value = data.aws_eks_cluster.existing_cluster.endpoint
}

# Output the cluster name
output "cluster_name" {
  value = data.aws_eks_cluster.existing_cluster.name
}
