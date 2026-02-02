# =============================================================================
# SECRETS.TF - AWS SECRETS MANAGER
# =============================================================================
#
# This file sets up secure storage for API keys.
#
# KEY CONCEPT: Never Store Secrets in Code
# API keys in .env files, config files, or Terraform state = BAD
# Anyone with access to your repo or state file can steal them.
#
# Secrets Manager:
# - Encrypts secrets at rest (AES-256)
# - Encrypts in transit (TLS)
# - Audit trail via CloudTrail
# - Automatic rotation (optional)
#
# Learn more:
# - Secrets Manager: https://docs.aws.amazon.com/secretsmanager/latest/userguide/intro.html
# - Why not .env: https://blog.gitguardian.com/secrets-credentials-api-keys/
# =============================================================================

# =============================================================================
# KMS KEY FOR ENCRYPTION
# =============================================================================
# Customer-managed KMS key for encrypting secrets, logs, and SNS topics.

resource "aws_kms_key" "openclaw" {
  description             = "KMS key for OpenClaw encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
          }
        }
      },
      {
        Sid    = "Allow SNS"
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey*",
          "kms:Decrypt"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "openclaw-kms-key"
  }
}

resource "aws_kms_alias" "openclaw" {
  name          = "alias/openclaw"
  target_key_id = aws_kms_key.openclaw.key_id
}

# =============================================================================
# THE SECRET (Container)
# =============================================================================
# This creates the "secret" resource - think of it as a labeled box.
# The actual secret value is stored separately.

resource "aws_secretsmanager_secret" "api_keys" {
  name        = "openclaw/api-keys"
  description = "API keys for OpenClaw (Anthropic, OpenAI)"
  kms_key_id  = aws_kms_key.openclaw.arn

  # Recovery window - how long you can recover a deleted secret
  # Set to 7 days minimum (can't set to 0 for safety)
  recovery_window_in_days = 7

  tags = {
    Name = "openclaw-api-keys"
  }
}

# =============================================================================
# THE SECRET VALUE (Contents)
# =============================================================================
# This stores the actual key values inside the secret.
#
# IMPORTANT: These are placeholder values!
# After running terraform apply, you must update this secret manually:
#
#   aws secretsmanager put-secret-value \
#     --secret-id openclaw/api-keys \
#     --secret-string '{"ANTHROPIC_API_KEY":"sk-ant-xxx","OPENAI_API_KEY":"sk-xxx"}'
#
# Or use the AWS Console: Secrets Manager > openclaw/api-keys > Retrieve/Edit
#
# WHY PLACEHOLDERS?
# If we put real keys here, they'd be stored in:
# - Terraform state file (often in S3)
# - Git history (if committed)
# - CI/CD logs
#
# By using placeholders and updating manually, the real keys never touch code.

resource "aws_secretsmanager_secret_version" "api_keys" {
  secret_id = aws_secretsmanager_secret.api_keys.id

  # PLACEHOLDER VALUES - replace after deployment!
  secret_string = jsonencode({
    ANTHROPIC_API_KEY = "REPLACE_ME_AFTER_DEPLOYMENT"
    OPENAI_API_KEY    = "REPLACE_ME_AFTER_DEPLOYMENT"
  })

  # Ignore changes to the secret string after initial creation
  # This prevents Terraform from overwriting manually-set keys
  lifecycle {
    ignore_changes = [secret_string]
  }
}

# =============================================================================
# HOW THE EC2 INSTANCE USES THIS
# =============================================================================
#
# 1. EC2 boots up and runs user_data.sh
# 2. Script calls: aws secretsmanager get-secret-value --secret-id openclaw/api-keys
# 3. AWS checks: Does the EC2's IAM role have permission? (Yes, from iam.tf)
# 4. Secret value is returned (encrypted in transit via VPC endpoint)
# 5. Script parses JSON and sets environment variables
# 6. Docker container receives keys as env vars (never written to disk)
# 7. Script unsets the variables from shell memory
#
# At no point are the keys:
# - Written to a file
# - Logged (unless you explicitly echo them, which you shouldn't)
# - Stored in Terraform state (only placeholders)
# =============================================================================

# =============================================================================
# OPTIONAL: SECRET ROTATION
# =============================================================================
# For production, you might want automatic key rotation.
# This requires a Lambda function that knows how to rotate your specific keys.
#
# resource "aws_secretsmanager_secret_rotation" "api_keys" {
#   secret_id           = aws_secretsmanager_secret.api_keys.id
#   rotation_lambda_arn = aws_lambda_function.rotate_keys.arn
#   rotation_rules {
#     automatically_after_days = 30
#   }
# }
#
# Learn more: https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotating-secrets.html
# =============================================================================
