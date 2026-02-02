# =============================================================================
# EC2.TF - COMPUTE INSTANCE FOR OPENCLAW
# =============================================================================
#
# OpenClaw runs on the host (not containerized) and spawns Docker containers
# for agent sandboxes. This requires EC2, not Fargate.
#
# KEY SECURITY FEATURES:
# - Private subnet (no public IP)
# - SSM for access (no SSH from internet)
# - IMDSv2 required (blocks SSRF attacks)
# - Encrypted root volume
#
# Learn more:
# - EC2: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/concepts.html
# - IMDSv2: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configuring-instance-metadata-service.html
# =============================================================================

# =============================================================================
# SECURITY GROUP
# =============================================================================
# Only allows traffic from CloudFront. No SSH from internet.

resource "aws_security_group" "openclaw" {
  name        = "openclaw-ec2-sg"
  description = "Security group for OpenClaw EC2"
  vpc_id      = aws_vpc.main.id

  # Allow inbound from CloudFront (via VPC origin)
  ingress {
    from_port   = 18789
    to_port     = 18789
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
    description = "OpenClaw gateway from VPC"
  }

  # HTTPS outbound for API calls
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS for API calls and package downloads"
  }

  # HTTP outbound for package repos (some still use HTTP)
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP for package downloads"
  }

  # DNS for Route53 DNS Firewall
  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "DNS queries"
  }

  tags = {
    Name = "openclaw-ec2-sg"
  }
}

# =============================================================================
# AMI - Ubuntu 22.04 LTS (OpenClaw requirement)
# =============================================================================

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# =============================================================================
# EC2 INSTANCE
# =============================================================================

resource "aws_instance" "openclaw" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private_a.id
  vpc_security_group_ids = [aws_security_group.openclaw.id]
  iam_instance_profile   = aws_iam_instance_profile.openclaw.name
  ebs_optimized          = true

  # No public IP - private subnet only
  associate_public_ip_address = false

  # Encrypted root volume
  root_block_device {
    volume_size           = 30 # GB - enough for Docker images
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true

    tags = {
      Name = "openclaw-root-volume"
    }
  }

  # IMDSv2 required - blocks SSRF credential theft
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # User data runs Ansible on first boot
  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e

    # Log everything
    exec > >(tee /var/log/user-data.log) 2>&1
    echo "Starting OpenClaw setup at $(date)"

    # Install Ansible
    apt-get update
    apt-get install -y ansible git

    # Clone OpenClaw Ansible repo
    git clone https://github.com/openclaw/openclaw-ansible.git /opt/openclaw-ansible
    cd /opt/openclaw-ansible

    # Install Ansible collections
    ansible-galaxy collection install -r requirements.yml

    # Run playbook (non-interactive)
    ansible-playbook playbook.yml --connection=local

    echo "OpenClaw setup completed at $(date)"
  EOF
  )

  # Enable detailed monitoring
  monitoring = true

  tags = {
    Name = "openclaw-instance"
  }

  # Wait for IAM role
  depends_on = [
    aws_iam_role_policy_attachment.openclaw_ssm,
    aws_iam_role_policy_attachment.openclaw_secrets
  ]
}

# =============================================================================
# ELASTIC IP (Optional - for consistent CloudFront origin)
# =============================================================================
# Not strictly needed since CloudFront uses VPC origin, but useful for
# direct Tailscale access if configured.

# resource "aws_eip" "openclaw" {
#   instance = aws_instance.openclaw.id
#   domain   = "vpc"
#
#   tags = {
#     Name = "openclaw-eip"
#   }
# }
