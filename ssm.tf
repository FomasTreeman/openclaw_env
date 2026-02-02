# =============================================================================
# SSM.TF - SYSTEMS MANAGER PATCH MANAGEMENT
# =============================================================================
#
# AWS Systems Manager Patch Manager automates OS patching:
# - Scans for missing patches
# - Applies security updates on schedule
# - Reports compliance status
#
# No SSH needed - uses SSM agent (pre-installed on Amazon Linux, Ubuntu).
#
# Learn more:
# - Patch Manager: https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-patch.html
# =============================================================================

# =============================================================================
# PATCH BASELINE - What Gets Patched
# =============================================================================
# Defines which patches to apply. We focus on security patches.

resource "aws_ssm_patch_baseline" "ubuntu" {
  name             = "openclaw-ubuntu-security-baseline"
  description      = "Security patches for Ubuntu"
  operating_system = "UBUNTU"

  # Approve security patches automatically
  approval_rule {
    approve_after_days = 0 # Apply immediately

    patch_filter {
      key    = "PRIORITY"
      values = ["Required", "Important", "Standard"]
    }

    patch_filter {
      key    = "SECTION"
      values = ["security"]
    }
  }

  # Also include recommended updates (optional)
  approval_rule {
    approve_after_days = 7 # Wait 7 days for non-security

    patch_filter {
      key    = "PRIORITY"
      values = ["Required", "Important"]
    }

    patch_filter {
      key    = "SECTION"
      values = ["updates"]
    }
  }

  tags = {
    Name = "openclaw-patch-baseline"
  }
}

# Register our baseline as the default for Ubuntu
resource "aws_ssm_patch_group" "openclaw" {
  baseline_id = aws_ssm_patch_baseline.ubuntu.id
  patch_group = "openclaw-servers"
}

# =============================================================================
# MAINTENANCE WINDOW - When Patching Happens
# =============================================================================
# Patches are applied during this window to minimize disruption.

resource "aws_ssm_maintenance_window" "patching" {
  name              = "openclaw-patching-window"
  description       = "Weekly patching window for OpenClaw"
  schedule          = "cron(0 4 ? * SUN *)" # Sunday 4 AM UTC
  duration          = 2                       # 2 hours
  cutoff            = 1                       # Stop 1 hour before end
  allow_unassociated_targets = false

  tags = {
    Name = "openclaw-maintenance-window"
  }
}

# Target: Our EC2 instance
resource "aws_ssm_maintenance_window_target" "openclaw" {
  window_id     = aws_ssm_maintenance_window.patching.id
  name          = "openclaw-instance"
  description   = "OpenClaw EC2 instance"
  resource_type = "INSTANCE"

  targets {
    key    = "InstanceIds"
    values = [aws_instance.openclaw.id]
  }
}

# Task: Run patch scan and install
resource "aws_ssm_maintenance_window_task" "patch" {
  window_id        = aws_ssm_maintenance_window.patching.id
  name             = "patch-openclaw"
  description      = "Apply security patches"
  task_type        = "RUN_COMMAND"
  task_arn         = "AWS-RunPatchBaseline"
  priority         = 1
  max_concurrency  = "1"
  max_errors       = "0"
  service_role_arn = aws_iam_role.ssm_maintenance.arn

  targets {
    key    = "WindowTargetIds"
    values = [aws_ssm_maintenance_window_target.openclaw.id]
  }

  task_invocation_parameters {
    run_command_parameters {
      parameter {
        name   = "Operation"
        values = ["Install"]
      }
      parameter {
        name   = "RebootOption"
        values = ["RebootIfNeeded"]
      }
    }
  }
}

# IAM role for maintenance window
resource "aws_iam_role" "ssm_maintenance" {
  name = "openclaw-ssm-maintenance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ssm.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "openclaw-ssm-maintenance-role"
  }
}

resource "aws_iam_role_policy_attachment" "ssm_maintenance" {
  role       = aws_iam_role.ssm_maintenance.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonSSMMaintenanceWindowRole"
}

# =============================================================================
# COMPLIANCE REPORTING
# =============================================================================
# Track patch compliance in a resource data sync.

resource "aws_ssm_resource_data_sync" "compliance" {
  name = "openclaw-compliance-sync"

  s3_destination {
    bucket_name = aws_s3_bucket.compliance.id
    region      = var.aws_region
    prefix      = "ssm-compliance"
  }
}

resource "aws_s3_bucket" "compliance" {
  bucket_prefix = "openclaw-compliance-"
  force_destroy = true # Allow deletion in dev

  tags = {
    Name = "openclaw-compliance-bucket"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "compliance" {
  bucket = aws_s3_bucket.compliance.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "compliance" {
  bucket = aws_s3_bucket.compliance.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
