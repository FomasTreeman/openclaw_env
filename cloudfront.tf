# =============================================================================
# CLOUDFRONT.TF - HTTPS TERMINATION + WAF
# =============================================================================
#
# CloudFront provides:
# - HTTPS termination (no HTTP option = secure by default)
# - Global edge caching
# - WAF integration for security rules
# - DDoS protection (AWS Shield Standard included)
#
# Learn more:
# - CloudFront: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/Introduction.html
# - VPC Origins: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-vpc-origins.html
# - WAF: https://docs.aws.amazon.com/waf/latest/developerguide/waf-chapter.html
# =============================================================================

# =============================================================================
# APPLICATION LOAD BALANCER (Internal)
# =============================================================================
# CloudFront VPC origins need a load balancer or service discovery endpoint.
# We use an internal ALB as the bridge between CloudFront and EC2.

resource "aws_security_group" "alb" {
  name        = "openclaw-alb-sg"
  description = "Security group for internal ALB"
  vpc_id      = aws_vpc.main.id

  # Allow from CloudFront (VPC origin uses internal IPs)
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
    description = "HTTPS from VPC"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
    description = "HTTP from VPC"
  }

  egress {
    from_port   = 18789
    to_port     = 18789
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
    description = "Allow outbound to OpenClaw EC2"
  }

  tags = {
    Name = "openclaw-alb-sg"
  }
}

resource "aws_lb" "internal" {
  name                       = "openclaw-internal-alb"
  internal                   = true # Not internet-facing
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb.id]
  subnets                    = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  enable_deletion_protection = true
  drop_invalid_header_fields = true

  tags = {
    Name = "openclaw-internal-alb"
  }
}

resource "aws_lb_target_group" "openclaw" {
  name        = "openclaw-tg"
  port        = 18789
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/health"
    protocol            = "HTTP"
  }

  tags = {
    Name = "openclaw-tg"
  }
}

resource "aws_lb_target_group_attachment" "openclaw" {
  target_group_arn = aws_lb_target_group.openclaw.arn
  target_id        = aws_instance.openclaw.id
  port             = 18789
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.internal.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.openclaw.arn
  }
}

# =============================================================================
# CLOUDFRONT DISTRIBUTION
# =============================================================================
# HTTPS only - no HTTP listener, so all traffic is encrypted.

resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  comment             = "OpenClaw secure distribution"
  default_root_object = ""
  price_class         = "PriceClass_100" # US, Canada, Europe only (cheapest)

  # Origin - Internal ALB
  origin {
    domain_name = aws_lb.internal.dns_name
    origin_id   = "alb-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only" # ALB is internal, uses HTTP
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Default behavior - forward all requests to ALB
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "alb-origin"

    # Don't cache - OpenClaw is dynamic
    cache_policy_id          = data.aws_cloudfront_cache_policy.disabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer.id

    viewer_protocol_policy = "https-only" # HTTPS enforced, HTTP rejected
    compress               = true
  }

  # Use CloudFront's default certificate
  # Note: minimum_protocol_version only applies with custom certificates (ACM)
  # CloudFront default certificate enforces TLS 1.0+ but we document this limitation
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  # Restrict to US, Canada, Europe for cost and security
  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "CA", "GB", "DE", "FR", "IE", "NL", "AU"]
    }
  }

  # Attach WAF
  web_acl_id = aws_wafv2_web_acl.main.arn

  tags = {
    Name = "openclaw-distribution"
  }
}

# AWS managed cache policies
data "aws_cloudfront_cache_policy" "disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_origin_request_policy" "all_viewer" {
  name = "Managed-AllViewer"
}

# =============================================================================
# WAF WEB ACL
# =============================================================================
# Web Application Firewall rules to protect OpenClaw.
#
# Learn more:
# - Managed Rules: https://docs.aws.amazon.com/waf/latest/developerguide/aws-managed-rule-groups.html

resource "aws_wafv2_web_acl" "main" {
  name        = "openclaw-waf"
  description = "WAF rules for OpenClaw"
  scope       = "CLOUDFRONT"

  # Default action - allow traffic that doesn't match any rules
  default_action {
    allow {}
  }

  # Rule 1: Rate limiting - prevent DDoS/brute force
  rule {
    name     = "RateLimitRule"
    priority = 1

    override_action {
      none {}
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitRule"
      sampled_requests_enabled   = true
    }
  }

  # Rule 2: AWS Managed Common Rule Set
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # Rule 3: Known Bad Inputs
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesKnownBadInputsRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # Rule 4: IP Reputation
  rule {
    name     = "AWSManagedRulesAmazonIpReputationList"
    priority = 4

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesAmazonIpReputationList"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "openclaw-waf"
    sampled_requests_enabled   = true
  }

  tags = {
    Name = "openclaw-waf"
  }
}
