# =============================================================================
# OUTPUTS.TF - USEFUL INFO AFTER DEPLOYMENT
# =============================================================================

output "cloudfront_domain" {
  description = "CloudFront distribution domain - access OpenClaw here"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "cloudfront_url" {
  description = "Full HTTPS URL to access OpenClaw"
  value       = "https://${aws_cloudfront_distribution.main.domain_name}"
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (for cache invalidation)"
  value       = aws_cloudfront_distribution.main.id
}

output "waf_web_acl_arn" {
  description = "WAF Web ACL ARN"
  value       = aws_wafv2_web_acl.main.arn
}

output "ec2_instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.openclaw.id
}

output "ec2_private_ip" {
  description = "EC2 instance private IP"
  value       = aws_instance.openclaw.private_ip
}

output "secret_arn" {
  description = "Secrets Manager ARN - update with real API keys"
  value       = aws_secretsmanager_secret.api_keys.arn
}

output "update_secret_command" {
  description = "Command to update the secret with real API keys"
  value       = <<-EOT
    aws secretsmanager put-secret-value \
      --secret-id ${aws_secretsmanager_secret.api_keys.id} \
      --secret-string '{"ANTHROPIC_API_KEY":"YOUR_KEY","OPENAI_API_KEY":"YOUR_KEY"}' \
      --region ${var.aws_region}
  EOT
}

output "view_logs_command" {
  description = "Command to view OpenClaw gateway logs"
  value       = "aws logs tail /openclaw/gateway --follow --region ${var.aws_region}"
}

output "ssm_connect_command" {
  description = "Command to connect to the EC2 instance via SSM"
  value       = "aws ssm start-session --target ${aws_instance.openclaw.id} --region ${var.aws_region}"
}

output "invalidate_cache_command" {
  description = "Command to invalidate CloudFront cache after updates"
  value       = "aws cloudfront create-invalidation --distribution-id ${aws_cloudfront_distribution.main.id} --paths '/*'"
}

# =============================================================================
# AFTER DEPLOYMENT
# =============================================================================
#
# 1. Update the secret with real API keys:
#    (use the update_secret_command output)
#
# 2. Access OpenClaw:
#    https://<cloudfront_domain>
#
# 3. View logs:
#    aws logs tail /openclaw/gateway --follow
#
# 4. Connect to instance via SSM:
#    aws ssm start-session --target <instance-id>
#
# 5. Restart OpenClaw service:
#    sudo systemctl restart openclaw-gateway
#
# 6. Clear CloudFront cache if needed:
#    aws cloudfront create-invalidation --distribution-id <id> --paths '/*'
# =============================================================================
