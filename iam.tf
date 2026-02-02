# =============================================================================
# IAM.TF - IDENTITY AND ACCESS MANAGEMENT
# =============================================================================
#
# Defines IAM roles for:
# - EC2 instance (SSM, Secrets Manager, CloudWatch)
# - Lambda functions (janitor tasks)
# - SSM maintenance window
#
# KEY CONCEPT: Least Privilege
# Each role only has permissions it actually needs.
#
# Learn more:
# - IAM Best Practices: https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html
# =============================================================================

# =============================================================================
# EC2 INSTANCE ROLE
# =============================================================================
# The OpenClaw EC2 instance needs:
# - SSM: For remote access and patching
# - Secrets Manager: To fetch API keys
# - CloudWatch: To send logs and metrics

resource "aws_iam_role" "openclaw" {
  name = "openclaw-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "openclaw-ec2-role"
  }
}

resource "aws_iam_instance_profile" "openclaw" {
  name = "openclaw-instance-profile"
  role = aws_iam_role.openclaw.name
}

# SSM access (for Session Manager and Patch Manager)
resource "aws_iam_role_policy_attachment" "openclaw_ssm" {
  role       = aws_iam_role.openclaw.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Secrets Manager - read only our specific secret
resource "aws_iam_policy" "openclaw_secrets" {
  name        = "openclaw-secrets-policy"
  description = "Allow OpenClaw to read its API keys"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GetSecretValue"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.api_keys.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "openclaw_secrets" {
  role       = aws_iam_role.openclaw.name
  policy_arn = aws_iam_policy.openclaw_secrets.arn
}

# CloudWatch - write logs
resource "aws_iam_policy" "openclaw_cloudwatch" {
  name        = "openclaw-cloudwatch-policy"
  description = "Allow OpenClaw to write CloudWatch logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "WriteLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          aws_cloudwatch_log_group.openclaw.arn,
          "${aws_cloudwatch_log_group.openclaw.arn}:*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "openclaw_cloudwatch" {
  role       = aws_iam_role.openclaw.name
  policy_arn = aws_iam_policy.openclaw_cloudwatch.arn
}

# =============================================================================
# CLOUDWATCH LOG GROUP FOR OPENCLAW
# =============================================================================

resource "aws_cloudwatch_log_group" "openclaw" {
  name              = "/openclaw/gateway"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.openclaw.arn

  tags = {
    Name = "openclaw-gateway-logs"
  }
}

# =============================================================================
# WHAT WE DELIBERATELY DID NOT INCLUDE
# =============================================================================
#
# The EC2 role:
# - Cannot create/delete secrets (only GetSecretValue)
# - Cannot read other secrets (only our specific ARN)
# - Cannot modify IAM (no privilege escalation)
# - Cannot launch EC2 instances or modify security groups
#
# The Lambda roles (defined in janitor.tf):
# - Can only manage instances with our Project tag
# - Cannot access secrets
# - Limited to specific SSM commands
#
# This limits blast radius if any component is compromised.
# =============================================================================
