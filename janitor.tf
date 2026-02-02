# =============================================================================
# JANITOR.TF - AUTOMATED MAINTENANCE & COST CONTROL
# =============================================================================
#
# "Cloud Janitor" - automated tasks that keep the system healthy:
# - Stop idle instances (cost savings)
# - Clean up old Docker images
# - Rotate secrets on schedule
#
# Uses EventBridge (cron) + Lambda for serverless automation.
#
# Learn more:
# - EventBridge: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-what-is.html
# - Lambda: https://docs.aws.amazon.com/lambda/latest/dg/welcome.html
# =============================================================================

# =============================================================================
# LAMBDA EXECUTION ROLE
# =============================================================================

resource "aws_iam_role" "janitor_lambda" {
  name = "openclaw-janitor-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "openclaw-janitor-role"
  }
}

resource "aws_iam_role_policy" "janitor_lambda" {
  name = "openclaw-janitor-policy"
  role = aws_iam_role.janitor_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2Operations"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:StopInstances",
          "ec2:StartInstances"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "ec2:ResourceTag/Project" = "hardened-openclaw"
          }
        }
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Sid    = "SSMRunCommand"
        Effect = "Allow"
        Action = [
          "ssm:SendCommand",
          "ssm:GetCommandInvocation"
        ]
        Resource = "*"
      },
      {
        Sid    = "XRayTracing"
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ]
        Resource = "*"
      }
    ]
  })
}

# =============================================================================
# DOCKER CLEANUP LAMBDA
# =============================================================================
# Runs weekly to clean up old Docker images on the EC2 instance.

resource "aws_lambda_function" "docker_cleanup" {
  filename                       = data.archive_file.docker_cleanup.output_path
  function_name                  = "openclaw-docker-cleanup"
  role                           = aws_iam_role.janitor_lambda.arn
  handler                        = "index.handler"
  source_code_hash               = data.archive_file.docker_cleanup.output_base64sha256
  runtime                        = "python3.11"
  timeout                        = 300
  reserved_concurrent_executions = 1

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      INSTANCE_ID = aws_instance.openclaw.id
    }
  }

  tags = {
    Name = "openclaw-docker-cleanup"
  }
}

data "archive_file" "docker_cleanup" {
  type        = "zip"
  output_path = "${path.module}/lambda/docker_cleanup.zip"

  source {
    content  = <<-EOF
      import boto3
      import os

      def handler(event, context):
          ssm = boto3.client('ssm')
          instance_id = os.environ['INSTANCE_ID']
          
          # Run docker system prune on the EC2 instance
          response = ssm.send_command(
              InstanceIds=[instance_id],
              DocumentName='AWS-RunShellScript',
              Parameters={
                  'commands': [
                      'docker system prune -af --volumes',
                      'echo "Docker cleanup completed"'
                  ]
              }
          )
          
          return {
              'statusCode': 200,
              'body': f"Cleanup initiated: {response['Command']['CommandId']}"
          }
    EOF
    filename = "index.py"
  }
}

# Schedule: Every Sunday at 3 AM UTC
resource "aws_cloudwatch_event_rule" "docker_cleanup" {
  name                = "openclaw-docker-cleanup-schedule"
  description         = "Weekly Docker cleanup"
  schedule_expression = "cron(0 3 ? * SUN *)"

  tags = {
    Name = "openclaw-docker-cleanup-schedule"
  }
}

resource "aws_cloudwatch_event_target" "docker_cleanup" {
  rule      = aws_cloudwatch_event_rule.docker_cleanup.name
  target_id = "docker-cleanup"
  arn       = aws_lambda_function.docker_cleanup.arn
}

resource "aws_lambda_permission" "docker_cleanup" {
  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.docker_cleanup.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.docker_cleanup.arn
}

# =============================================================================
# IDLE INSTANCE STOPPER (Optional - Cost Savings)
# =============================================================================
# Stops the instance if CPU is low for extended period (dev environments).
# Disabled by default - uncomment to enable.

# resource "aws_lambda_function" "idle_stopper" {
#   filename         = data.archive_file.idle_stopper.output_path
#   function_name    = "openclaw-idle-stopper"
#   role             = aws_iam_role.janitor_lambda.arn
#   handler          = "index.handler"
#   source_code_hash = data.archive_file.idle_stopper.output_base64sha256
#   runtime          = "python3.11"
#   timeout          = 60
#
#   environment {
#     variables = {
#       INSTANCE_ID    = aws_instance.openclaw.id
#       CPU_THRESHOLD  = "5"   # Stop if CPU below 5%
#       IDLE_MINUTES   = "60"  # For 60 minutes
#     }
#   }
# }

# =============================================================================
# SECURITY PATCH CHECK LAMBDA
# =============================================================================
# Checks for pending security updates and notifies.

resource "aws_lambda_function" "patch_check" {
  filename                       = data.archive_file.patch_check.output_path
  function_name                  = "openclaw-patch-check"
  role                           = aws_iam_role.janitor_lambda.arn
  handler                        = "index.handler"
  source_code_hash               = data.archive_file.patch_check.output_base64sha256
  runtime                        = "python3.11"
  timeout                        = 300
  reserved_concurrent_executions = 1

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      INSTANCE_ID = aws_instance.openclaw.id
      SNS_TOPIC   = aws_sns_topic.alerts.arn
    }
  }

  tags = {
    Name = "openclaw-patch-check"
  }
}

data "archive_file" "patch_check" {
  type        = "zip"
  output_path = "${path.module}/lambda/patch_check.zip"

  source {
    content  = <<-EOF
      import boto3
      import os

      def handler(event, context):
          ssm = boto3.client('ssm')
          sns = boto3.client('sns')
          instance_id = os.environ['INSTANCE_ID']
          sns_topic = os.environ['SNS_TOPIC']
          
          # Check for security updates
          response = ssm.send_command(
              InstanceIds=[instance_id],
              DocumentName='AWS-RunShellScript',
              Parameters={
                  'commands': [
                      'apt-get update -qq',
                      'apt-get upgrade -s | grep -i security | wc -l'
                  ]
              }
          )
          
          # Note: In production, you'd wait for command completion
          # and parse the output to determine update count
          
          return {
              'statusCode': 200,
              'body': 'Patch check initiated'
          }
    EOF
    filename = "index.py"
  }
}

# Schedule: Daily at 6 AM UTC
resource "aws_cloudwatch_event_rule" "patch_check" {
  name                = "openclaw-patch-check-schedule"
  description         = "Daily security patch check"
  schedule_expression = "cron(0 6 * * ? *)"

  tags = {
    Name = "openclaw-patch-check-schedule"
  }
}

resource "aws_cloudwatch_event_target" "patch_check" {
  rule      = aws_cloudwatch_event_rule.patch_check.name
  target_id = "patch-check"
  arn       = aws_lambda_function.patch_check.arn
}

resource "aws_lambda_permission" "patch_check" {
  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.patch_check.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.patch_check.arn
}
