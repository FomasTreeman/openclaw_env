# =============================================================================
# VARIABLES.TF - INPUT VARIABLES
# =============================================================================
#
# Variables make your Terraform reusable and configurable.
# Instead of hardcoding "us-east-1" everywhere, use var.aws_region.
#
# You can set these via:
# 1. terraform.tfvars file (most common)
# 2. Command line: terraform apply -var="aws_region=us-west-2"
# 3. Environment variables: TF_VAR_aws_region=us-west-2
#
# Learn more:
# - Variables: https://developer.hashicorp.com/terraform/language/values/variables
# =============================================================================

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^(us|eu|ap|sa|ca|me|af)-(north|south|east|west|central)-[0-9]$", var.aws_region))
    error_message = "Must be a valid AWS region (e.g., us-east-1, eu-west-2)."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "waf_rate_limit" {
  description = "Max requests per 5 minutes per IP before blocking"
  type        = number
  default     = 2000

  # 2000 requests per 5 min = ~6.6 requests/second sustained
  # Adjust based on expected legitimate traffic
}

variable "allowed_egress_domains" {
  description = "Domains that OpenClaw is allowed to reach (DNS firewall allowlist)"
  type        = list(string)
  default = [
    "api.openai.com",
    "api.anthropic.com",
    "api.brave.com",
    "*.amazonaws.com"
  ]
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "alert_email" {
  description = "Email address for security alerts (leave empty to skip)"
  type        = string
  default     = ""
}

# =============================================================================
# EXAMPLE terraform.tfvars
# =============================================================================
#
#   aws_region             = "us-west-2"
#   environment            = "prod"
#   instance_type          = "t3.medium"
#   waf_rate_limit         = 1000
#   alert_email            = "security@example.com"
#   allowed_egress_domains = [
#     "api.openai.com",
#     "api.anthropic.com"
#   ]
#
# =============================================================================
