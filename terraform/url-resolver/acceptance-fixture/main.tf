terraform {
  required_version = "= 1.12.1"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = "us-east-1"
}

variable "vpc_id" {
  type = string
}
variable "subnet_id" {
  type = string
}
variable "resolver_egress_ipv4" {
  type = string
  validation {
    condition     = can(cidrnetmask("${var.resolver_egress_ipv4}/32"))
    error_message = "Supply the resolver's single public IPv4 address, not a CIDR range."
  }
}
variable "ami_id" {
  description = "Verified current Amazon Linux 2023 ARM64 AMI from the AWS public SSM parameter."
  type        = string
}
variable "user_data" {
  description = "Reviewed Lambda-agent fixture script, containing synthetic responses only and no secrets."
  type        = string
}

variable "bootstrap_metadata_enabled" {
  description = "Enable IMDSv2 only while cloud-init retrieves the fixture user-data, then set false after readiness. Instance has no IAM role at any time."
  type        = bool
  default     = true
  nullable    = false
}

resource "aws_security_group" "fixture" {
  name_prefix = "trustcheckradar-dev-url-resolver-fixture-"
  description = "Temporary synthetic fixture; only resolver NAT may connect on HTTP"
  vpc_id      = var.vpc_id
  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["${var.resolver_egress_ipv4}/32"]
  }
  # Only OS package retrieval, if needed; no SSH or SSM access.
  egress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Project = "trustcheckradar", Environment = "dev", Purpose = "url-resolver-acceptance", ManagedBy = "terraform" }
}

resource "aws_instance" "fixture" {
  ami                                  = var.ami_id
  instance_type                        = "t4g.nano"
  subnet_id                            = var.subnet_id
  associate_public_ip_address          = true
  vpc_security_group_ids               = [aws_security_group.fixture.id]
  user_data                            = var.user_data
  user_data_replace_on_change          = true
  instance_initiated_shutdown_behavior = "terminate"
  metadata_options {
    http_endpoint               = var.bootstrap_metadata_enabled ? "enabled" : "disabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 8
    encrypted             = true
    delete_on_termination = true
  }
  tags = { Name = "trustcheckradar-dev-url-resolver-fixture", Project = "trustcheckradar", Environment = "dev", Purpose = "url-resolver-acceptance", ManagedBy = "terraform" }
}

output "fixture" {
  value = {
    instance_id          = aws_instance.fixture.id
    public_ipv4          = aws_instance.fixture.public_ip
    private_ipv4         = aws_instance.fixture.private_ip
    network_interface_id = aws_instance.fixture.primary_network_interface_id
  }
}
