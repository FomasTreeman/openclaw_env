# Hardened AI Agent Infrastructure

A production-ready AWS infrastructure for securely deploying AI agents that require shell access, file system operations, and external API connectivity. This project demonstrates enterprise-grade DevSecOps practices including defense-in-depth security, infrastructure as code, automated compliance scanning, and operational automation.

## Overview

AI agents with autonomous execution capabilities present unique security challenges. This infrastructure addresses those challenges through seven layers of security controls while maintaining reasonable operational costs (~$65-70/month).

### Key Security Features

- **Network Isolation**: Private subnets with no direct internet exposure
- **Egress Control**: DNS-based filtering restricts outbound connections to allowlisted domains
- **Secrets Management**: API keys stored in AWS Secrets Manager, never in code or on disk
- **Threat Detection**: GuardDuty and Inspector provide continuous monitoring
- **Automated Patching**: SSM Patch Manager applies security updates weekly
- **Access Logging**: VPC Flow Logs, DNS query logs, and CloudWatch provide full audit trails

## Architecture

```
                                    ┌─────────────────────────────────────────────────────────┐
                                    │                        VPC                              │
┌──────────┐    ┌───────────────┐   │  ┌──────────────┐    ┌─────────────────────────────┐   │
│          │    │  CloudFront   │   │  │   Internal   │    │      Private Subnet         │   │
│  Users   │───▶│  + WAF        │───┼─▶│     ALB      │───▶│  ┌─────────────────────┐    │   │
│          │    │  (HTTPS/TLS)  │   │  │              │    │  │   EC2 Instance      │    │   │
└──────────┘    └───────────────┘   │  └──────────────┘    │  │   - AI Gateway      │    │   │
                                    │                       │  │   - Docker Runtime  │    │   │
                                    │                       │  └─────────────────────┘    │   │
                                    │                       └─────────────────────────────┘   │
                                    │                                     │                   │
                                    │                       ┌─────────────▼───────────────┐   │
                                    │                       │      DNS Firewall           │   │
                                    │                       │  (Egress Allowlist Only)    │   │
                                    │                       └─────────────────────────────┘   │
                                    └─────────────────────────────────────────────────────────┘

Monitoring & Automation:
├── Amazon Inspector (CVE scanning)
├── GuardDuty (threat detection)
├── CloudWatch Alarms → SNS (alerting)
├── SSM Patch Manager (automated patching)
└── Lambda (scheduled maintenance tasks)
```

## Security Controls

| Layer | Threat | Control |
|-------|--------|---------|
| Edge | DDoS, Brute Force | CloudFront + WAF rate limiting, IP reputation filtering |
| Network | Port Scanning | Private subnet, no public IP |
| Network | Data Exfiltration | DNS Firewall allowlist, VPC Flow Logs |
| Host | SSRF Attacks | IMDSv2 required |
| Host | Privilege Escalation | Unprivileged service user, systemd hardening |
| Secrets | Credential Theft | Secrets Manager with KMS encryption |
| Monitoring | Undetected Compromise | GuardDuty, Inspector, CloudWatch alarms |
| Maintenance | Unpatched CVEs | SSM Patch Manager (weekly) |

## Prerequisites

- **AWS Account** with appropriate IAM permissions
- **AWS CLI** v2.x configured with credentials
- **Terraform** >= 1.0
- **Git** for version control

### Required AWS Permissions

The deploying IAM user/role needs permissions for:
- VPC, EC2, ELB, CloudFront, WAF
- IAM (role/policy creation)
- Secrets Manager, KMS
- Route 53 Resolver
- CloudWatch, SNS, Lambda
- Systems Manager, Inspector, GuardDuty

## Deployment

### 1. Clone and Configure

```bash
git clone https://github.com/YOUR_USERNAME/hardened-ai-infrastructure.git
cd hardened-ai-infrastructure
```

### 2. Set Variables

Create a `terraform.tfvars` file:

```hcl
aws_region    = "us-east-1"
environment   = "production"
instance_type = "t3.small"
alert_email   = "your-email@example.com"

# Domains the AI agent is allowed to reach
allowed_egress_domains = [
  "api.openai.com",
  "api.anthropic.com",
  "*.amazonaws.com"
]

# WAF rate limit (requests per 5 minutes per IP)
waf_rate_limit = 2000
```

### 3. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Review planned changes
terraform plan

# Apply infrastructure
terraform apply
```

### 4. Configure Secrets

After deployment, add your API keys to Secrets Manager:

```bash
aws secretsmanager put-secret-value \
  --secret-id openclaw/api-keys \
  --secret-string '{"ANTHROPIC_API_KEY":"your-key-here","OPENAI_API_KEY":"your-key-here"}' \
  --region us-east-1
```

### 5. Verify Deployment

```bash
# Get the CloudFront URL
terraform output cloudfront_url

# Connect to the instance via SSM (no SSH required)
terraform output ssm_connect_command

# View application logs
terraform output view_logs_command
```

## File Structure

```
.
├── main.tf              # VPC, subnets, NAT Gateway, VPC endpoints, flow logs
├── ec2.tf               # EC2 instance configuration, security groups
├── cloudfront.tf        # CloudFront distribution, WAF Web ACL
├── iam.tf               # IAM roles and policies (least privilege)
├── secrets.tf           # Secrets Manager, KMS key
├── dns_firewall.tf      # Route 53 DNS Firewall for egress control
├── monitoring.tf        # Inspector, GuardDuty, CloudWatch alarms, SNS
├── janitor.tf           # Lambda functions for automated maintenance
├── ssm.tf               # Systems Manager patch baseline and maintenance window
├── variables.tf         # Input variable definitions
├── outputs.tf           # Output values
├── ansible/
│   ├── playbook.yml     # OS hardening and application setup
│   └── inventory.yml    # Ansible inventory
├── policies/
│   └── *.json           # IAM policy documents for linting
├── diagrams/
│   └── *.py             # Architecture diagram source (Python diagrams library)
└── .github/
    └── workflows/
        └── security.yml # CI/CD security scanning pipeline
```

## CI/CD Security Pipeline

The GitHub Actions workflow runs on every pull request:

| Tool | Purpose |
|------|---------|
| Checkov | Terraform security and compliance scanning |
| Gitleaks | Secret detection in code |
| Trivy | Container vulnerability scanning |
| Parliament | IAM policy linting and validation |

## Operational Runbook

### Connecting to the Instance

```bash
# Via AWS SSM (recommended)
aws ssm start-session --target <instance-id> --region us-east-1

# View instance ID
terraform output ec2_instance_id
```

### Viewing Logs

```bash
# Application logs
aws logs tail /openclaw/gateway --follow --region us-east-1

# DNS query logs (egress audit)
aws logs tail /openclaw/dns-queries --follow --region us-east-1

# VPC flow logs
aws logs tail /openclaw/vpc-flow-logs --follow --region us-east-1
```

### Restarting the Service

```bash
# Connect via SSM first, then:
sudo systemctl restart openclaw-gateway
sudo systemctl status openclaw-gateway
```

### Invalidating CloudFront Cache

```bash
aws cloudfront create-invalidation \
  --distribution-id $(terraform output -raw cloudfront_distribution_id) \
  --paths '/*'
```

### Updating Allowed Egress Domains

Edit `terraform.tfvars`:

```hcl
allowed_egress_domains = [
  "api.openai.com",
  "api.anthropic.com",
  "api.newservice.com",  # Add new domain
  "*.amazonaws.com"
]
```

Then apply:

```bash
terraform apply
```

## Cost Breakdown

| Resource | Monthly Cost | Notes |
|----------|--------------|-------|
| EC2 t3.small | ~$15 | Compute instance |
| NAT Gateway | ~$32 | Enables outbound internet access |
| CloudFront | ~$1-5 | Usage-based pricing |
| WAF | ~$5 | Web ACL + managed rules |
| VPC Endpoints | ~$7 | Private AWS service access |
| Inspector | ~$1 | Vulnerability scanning |
| GuardDuty | ~$4 | Threat detection |
| **Total** | **~$65-70** | |

### Cost Optimization Options

- **Remove NAT Gateway** (-$32/month): Use VPC endpoints only, no external API access
- **Smaller instance** (-$5/month): Use t3.micro for development
- **Auto-stop idle instances**: Lambda function to stop instances during off-hours

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

Note: Secrets Manager secrets have a 7-day recovery window before permanent deletion.

## Security Considerations

### What This Infrastructure Does NOT Protect Against

- **Direct IP connections**: DNS filtering can be bypassed if an attacker knows the destination IP
- **Application-level vulnerabilities**: This infrastructure secures the environment, not the application itself
- **Insider threats**: Users with AWS console access can modify security controls

### Recommended Enhancements for Production

- AWS Network Firewall for full L7 egress inspection (~$300/month additional)
- AWS Config rules for continuous compliance monitoring
- Security Hub for centralized security findings
- Custom domain with ACM certificate for TLS 1.2+ enforcement
- Multi-AZ deployment for high availability

## License

MIT License - See [LICENSE](LICENSE) for details.
