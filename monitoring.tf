# =============================================================================
# MONITORING.TF - SECURITY MONITORING & ALERTING
# =============================================================================
#
# This file sets up continuous security monitoring:
# - Amazon Inspector: Vulnerability scanning
# - GuardDuty: Threat detection
# - CloudWatch Alarms: Operational alerts
#
# Learn more:
# - Inspector: https://docs.aws.amazon.com/inspector/latest/user/what-is-inspector.html
# - GuardDuty: https://docs.aws.amazon.com/guardduty/latest/ug/what-is-guardduty.html
# =============================================================================

# =============================================================================
# AMAZON INSPECTOR - Vulnerability Scanning
# =============================================================================
# Continuously scans EC2 instances and container images for:
# - Software vulnerabilities (CVEs)
# - Network exposure issues
# - Unpatched packages
#
# Cost: ~$0.01 per instance-hour scanned

resource "aws_inspector2_enabler" "main" {
  account_ids    = [data.aws_caller_identity.current.account_id]
  resource_types = ["EC2", "ECR"] # Scan EC2 and any container images
}

data "aws_caller_identity" "current" {}

# =============================================================================
# GUARDDUTY - Threat Detection
# =============================================================================
# Analyzes VPC Flow Logs, DNS logs, and CloudTrail to detect:
# - Cryptocurrency mining
# - Command & control traffic
# - Compromised credentials
# - Unusual API calls
#
# Cost: ~$4/month for small workloads

resource "aws_guardduty_detector" "main" {
  enable = true

  # S3 protection (if you add S3 later)
  datasources {
    s3_logs {
      enable = true
    }
  }

  tags = {
    Name = "openclaw-guardduty"
  }
}

# =============================================================================
# SNS TOPIC - Alert Notifications
# =============================================================================
# All alerts go to this topic. Subscribe your email/Slack webhook.

resource "aws_sns_topic" "alerts" {
  name              = "openclaw-security-alerts"
  kms_master_key_id = aws_kms_key.openclaw.id

  tags = {
    Name = "openclaw-alerts"
  }
}

# Subscribe your email (update the email address)
resource "aws_sns_topic_subscription" "email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# =============================================================================
# CLOUDWATCH ALARMS
# =============================================================================

# High CPU - might indicate crypto mining or DoS
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "openclaw-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300 # 5 minutes
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "CPU utilization above 80% for 10 minutes"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    InstanceId = aws_instance.openclaw.id
  }

  tags = {
    Name = "openclaw-high-cpu-alarm"
  }
}

# High network out - might indicate data exfiltration
resource "aws_cloudwatch_metric_alarm" "high_network_out" {
  alarm_name          = "openclaw-high-network-out"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "NetworkOut"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Sum"
  threshold           = 1000000000 # 1 GB in 5 minutes
  alarm_description   = "Unusual outbound network traffic (possible exfiltration)"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    InstanceId = aws_instance.openclaw.id
  }

  tags = {
    Name = "openclaw-high-network-alarm"
  }
}

# Instance status check failed
resource "aws_cloudwatch_metric_alarm" "status_check" {
  alarm_name          = "openclaw-status-check-failed"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "EC2 instance status check failed"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    InstanceId = aws_instance.openclaw.id
  }

  tags = {
    Name = "openclaw-status-alarm"
  }
}

# =============================================================================
# EVENTBRIDGE RULE - GuardDuty Findings to SNS
# =============================================================================
# Route GuardDuty findings to our alert topic.

resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  name        = "openclaw-guardduty-findings"
  description = "Route GuardDuty findings to SNS"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
  })

  tags = {
    Name = "openclaw-guardduty-rule"
  }
}

resource "aws_cloudwatch_event_target" "guardduty_to_sns" {
  rule      = aws_cloudwatch_event_rule.guardduty_findings.name
  target_id = "send-to-sns"
  arn       = aws_sns_topic.alerts.arn
}

# Allow EventBridge to publish to SNS
resource "aws_sns_topic_policy" "alerts" {
  arn = aws_sns_topic.alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEventBridge"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.alerts.arn
      }
    ]
  })
}

# =============================================================================
# EVENTBRIDGE RULE - Inspector Findings to SNS
# =============================================================================

resource "aws_cloudwatch_event_rule" "inspector_findings" {
  name        = "openclaw-inspector-findings"
  description = "Route Inspector findings to SNS"

  event_pattern = jsonencode({
    source      = ["aws.inspector2"]
    detail-type = ["Inspector2 Finding"]
    detail = {
      severity = ["CRITICAL", "HIGH"]
    }
  })

  tags = {
    Name = "openclaw-inspector-rule"
  }
}

resource "aws_cloudwatch_event_target" "inspector_to_sns" {
  rule      = aws_cloudwatch_event_rule.inspector_findings.name
  target_id = "send-to-sns"
  arn       = aws_sns_topic.alerts.arn
}
