# =============================================================================
# MAIN.TF - VPC AND NETWORKING
# =============================================================================
#
# This file creates the network foundation for our secure OpenClaw deployment.
#
# KEY CONCEPT: Defense in Depth
# We use multiple layers of network isolation:
# 1. VPC (our own private network in AWS)
# 2. Private subnet (no direct internet access)
# 3. Security groups (firewall rules)
#
# Learn more:
# - VPCs: https://docs.aws.amazon.com/vpc/latest/userguide/what-is-amazon-vpc.html
# - Subnets: https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Subnets.html
# =============================================================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # Tags applied to ALL resources - helps with cost tracking and organization
  default_tags {
    tags = {
      Project     = "hardened-openclaw"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# =============================================================================
# VPC - Your Private Network
# =============================================================================
# Think of a VPC as your own private data center in AWS.
# Nothing can talk to your resources unless you explicitly allow it.
#
# CIDR block 10.0.0.0/16 means:
# - 10.0.x.x addresses are available
# - /16 gives us 65,536 IP addresses (way more than we need, but room to grow)

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  # DNS settings - needed for ECS service discovery
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "openclaw-vpc"
  }
}

# =============================================================================
# PRIVATE SUBNETS (2 required for ECS/ALB)
# =============================================================================
# A private subnet has NO internet gateway attached.
# Resources here cannot be reached from the internet directly.
#
# ECS Fargate and ALB require subnets in at least 2 availability zones
# for high availability.

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.aws_region}a"

  map_public_ip_on_launch = false

  tags = {
    Name = "openclaw-private-subnet-a"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "${var.aws_region}b"

  map_public_ip_on_launch = false

  tags = {
    Name = "openclaw-private-subnet-b"
  }
}

# =============================================================================
# VPC ENDPOINTS - How Private Subnet Talks to AWS Services
# =============================================================================
# Problem: Our Fargate tasks are in a private subnet with no internet access.
# But they need to talk to AWS services (ECR, Secrets Manager, CloudWatch).
#
# Solution: VPC Endpoints create private connections to AWS services
# that never leave Amazon's network.
#
# Learn more: https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints.html

# Security group for VPC endpoints
resource "aws_security_group" "vpc_endpoints" {
  name        = "vpc-endpoints-sg"
  description = "Allow HTTPS from VPC for AWS service endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
    description = "HTTPS from VPC"
  }

  tags = {
    Name = "vpc-endpoints-sg"
  }
}

# Secrets Manager endpoint - to fetch API keys without internet
resource "aws_vpc_endpoint" "secrets_manager" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "secrets-manager-endpoint"
  }
}

# CloudWatch Logs endpoint - for logging without internet
resource "aws_vpc_endpoint" "cloudwatch_logs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "cloudwatch-logs-endpoint"
  }
}

# ECR API endpoint - for pulling container images
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "ecr-api-endpoint"
  }
}

# ECR DKR endpoint - for Docker layer downloads
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "ecr-dkr-endpoint"
  }
}

# S3 endpoint (Gateway type) - ECR stores layers in S3
# Gateway endpoints are free, Interface endpoints cost money
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = {
    Name = "s3-endpoint"
  }
}

# =============================================================================
# NAT GATEWAY - For Outbound Internet Access
# =============================================================================
# OpenClaw needs to call external APIs (OpenAI, Anthropic, web browsing).
# A NAT Gateway allows OUTBOUND traffic but blocks all INBOUND traffic.
#
# NOTE: NAT Gateways cost ~$32/month. Required for external API calls.

# Public subnets for NAT Gateway and ALB
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "openclaw-public-subnet-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = {
    Name = "openclaw-public-subnet-b"
  }
}

# Internet Gateway - the door to the internet
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "openclaw-igw"
  }
}

# Route table for public subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "openclaw-public-rt"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "openclaw-nat-eip"
  }
}

# NAT Gateway
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id

  tags = {
    Name = "openclaw-nat"
  }

  depends_on = [aws_internet_gateway.main]
}

# Route table for private subnets - outbound via NAT
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "openclaw-private-rt"
  }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

# =============================================================================
# VPC FLOW LOGS - Network Audit Trail
# =============================================================================
# Captures all network traffic metadata (not content) for security analysis.
# Useful for:
# - Detecting unusual traffic patterns
# - Investigating security incidents
# - Compliance requirements
#
# Learn more:
# - Flow Logs: https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs.html

resource "aws_flow_log" "main" {
  vpc_id                   = aws_vpc.main.id
  traffic_type             = "ALL" # ACCEPT, REJECT, or ALL
  log_destination_type     = "cloud-watch-logs"
  log_destination          = aws_cloudwatch_log_group.flow_logs.arn
  iam_role_arn             = aws_iam_role.flow_logs.arn
  max_aggregation_interval = 60 # 1 minute (or 600 for 10 min)

  tags = {
    Name = "openclaw-vpc-flow-logs"
  }
}

resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/openclaw/vpc-flow-logs"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.openclaw.arn

  tags = {
    Name = "openclaw-flow-logs"
  }
}

# IAM role for VPC Flow Logs to write to CloudWatch
resource "aws_iam_role" "flow_logs" {
  name = "openclaw-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "openclaw-flow-logs-role"
  }
}

resource "aws_iam_role_policy" "flow_logs" {
  name = "openclaw-flow-logs-policy"
  role = aws_iam_role.flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "${aws_cloudwatch_log_group.flow_logs.arn}:*"
      }
    ]
  })
}
