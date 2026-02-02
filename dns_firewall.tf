# =============================================================================
# DNS_FIREWALL.TF - EGRESS FILTERING VIA ROUTE 53 DNS FIREWALL
# =============================================================================
#
# This implements egress control by filtering DNS queries.
# Only allowlisted domains can be resolved - everything else is blocked.
#
# WHY DNS FILTERING?
# - OpenClaw needs to call external APIs (OpenAI, Anthropic)
# - Without egress control, a compromised container could exfiltrate data anywhere
# - DNS Firewall is cheap (~$1/month) vs AWS Network Firewall (~$300/month)
#
# LIMITATION:
# - Doesn't stop direct IP connections (attacker could hardcode an IP)
# - For full protection, use AWS Network Firewall (but expensive for demos)
#
# Learn more:
# - DNS Firewall: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resolver-dns-firewall.html
# =============================================================================

# =============================================================================
# FIREWALL DOMAIN LIST - What's Allowed
# =============================================================================
# Only these domains can be resolved. Everything else returns NXDOMAIN.

resource "aws_route53_resolver_firewall_domain_list" "allowed" {
  name    = "openclaw-allowed-domains"
  domains = var.allowed_egress_domains

  tags = {
    Name = "openclaw-allowed-domains"
  }
}

# =============================================================================
# FIREWALL RULE GROUP
# =============================================================================
# Contains the rules that reference the domain list.

resource "aws_route53_resolver_firewall_rule_group" "main" {
  name = "openclaw-egress-rules"

  tags = {
    Name = "openclaw-egress-rules"
  }
}

# Rule 1: ALLOW traffic to our allowlisted domains
resource "aws_route53_resolver_firewall_rule" "allow_listed" {
  name                    = "allow-listed-domains"
  firewall_rule_group_id  = aws_route53_resolver_firewall_rule_group.main.id
  firewall_domain_list_id = aws_route53_resolver_firewall_domain_list.allowed.id
  priority                = 100
  action                  = "ALLOW"
}

# Rule 2: BLOCK everything else
# This is the "default deny" - if not explicitly allowed, it's blocked
resource "aws_route53_resolver_firewall_rule" "block_all" {
  name                    = "block-all-other"
  firewall_rule_group_id  = aws_route53_resolver_firewall_rule_group.main.id
  firewall_domain_list_id = aws_route53_resolver_firewall_domain_list.blocked.id
  priority                = 200
  action                  = "BLOCK"
  block_response          = "NXDOMAIN" # Returns "domain not found"
}

# Wildcard domain list for "block everything"
resource "aws_route53_resolver_firewall_domain_list" "blocked" {
  name    = "openclaw-block-all"
  domains = ["*"] # Wildcard - matches any domain

  tags = {
    Name = "openclaw-block-all"
  }
}

# =============================================================================
# ASSOCIATE WITH VPC
# =============================================================================
# The firewall rules only apply to VPCs they're associated with.

resource "aws_route53_resolver_firewall_rule_group_association" "main" {
  name                   = "openclaw-firewall-association"
  firewall_rule_group_id = aws_route53_resolver_firewall_rule_group.main.id
  vpc_id                 = aws_vpc.main.id
  priority               = 100 # Lower = evaluated first

  tags = {
    Name = "openclaw-firewall-association"
  }
}

# =============================================================================
# CLOUDWATCH LOGGING FOR DNS QUERIES
# =============================================================================
# Log all DNS queries for audit trail - see what OpenClaw is trying to reach.

resource "aws_route53_resolver_query_log_config" "main" {
  name            = "openclaw-dns-logs"
  destination_arn = aws_cloudwatch_log_group.dns_logs.arn

  tags = {
    Name = "openclaw-dns-logs"
  }
}

resource "aws_route53_resolver_query_log_config_association" "main" {
  resolver_query_log_config_id = aws_route53_resolver_query_log_config.main.id
  resource_id                  = aws_vpc.main.id
}

resource "aws_cloudwatch_log_group" "dns_logs" {
  name              = "/openclaw/dns-queries"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.openclaw.arn

  tags = {
    Name = "openclaw-dns-logs"
  }
}
