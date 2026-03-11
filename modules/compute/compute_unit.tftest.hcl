# Unit tests for modules/compute
# Run with: terraform -chdir=modules/compute test

mock_provider "aws" {}

# ── Test: IMDSv2 is always required ──────────────────────────────────────────
# IMDSv2 prevents SSRF attacks from reaching the metadata API and must always
# be enforced. This is a security-critical invariant.

run "imdsv2_required" {
  command = plan

  variables {
    name               = "test-app"
    environment        = "test"
    ami_id             = "ami-0123456789abcdef0"
    subnet_ids         = ["subnet-aaaaaaaa", "subnet-bbbbbbbb"]
    security_group_ids = ["sg-11111111"]
  }

  assert {
    condition     = aws_launch_template.this.metadata_options[0].http_tokens == "required"
    error_message = "http_tokens must be 'required' to enforce IMDSv2. This is a security requirement."
  }

  assert {
    condition     = aws_launch_template.this.metadata_options[0].http_endpoint == "enabled"
    error_message = "http_endpoint must be 'enabled' for IMDSv2 to function."
  }

  assert {
    condition     = aws_launch_template.this.metadata_options[0].http_put_response_hop_limit == 1
    error_message = "hop_limit must be 1 to prevent metadata access from containers on the host."
  }
}

# ── Test: EBS volume is always encrypted ─────────────────────────────────────

run "ebs_encryption_enabled" {
  command = plan

  variables {
    name               = "test-app"
    environment        = "test"
    ami_id             = "ami-0123456789abcdef0"
    subnet_ids         = ["subnet-aaaaaaaa"]
    security_group_ids = ["sg-11111111"]
  }

  assert {
    condition     = aws_launch_template.this.block_device_mappings[0].ebs[0].encrypted == "true"
    error_message = "Root EBS volume must always be encrypted."
  }
}

# ── Test: detailed monitoring is always enabled ───────────────────────────────

run "detailed_monitoring_enabled" {
  command = plan

  variables {
    name               = "test-app"
    environment        = "test"
    ami_id             = "ami-0123456789abcdef0"
    subnet_ids         = ["subnet-aaaaaaaa"]
    security_group_ids = ["sg-11111111"]
  }

  assert {
    condition     = aws_launch_template.this.monitoring[0].enabled == true
    error_message = "Detailed EC2 monitoring must always be enabled."
  }
}

# ── Test: instances never get public IPs ─────────────────────────────────────

run "no_public_ip_assigned" {
  command = plan

  variables {
    name               = "test-app"
    environment        = "test"
    ami_id             = "ami-0123456789abcdef0"
    subnet_ids         = ["subnet-aaaaaaaa"]
    security_group_ids = ["sg-11111111"]
  }

  assert {
    condition     = aws_launch_template.this.network_interfaces[0].associate_public_ip_address == "false"
    error_message = "Instances must not receive public IP addresses — they should be in private subnets behind an ALB."
  }
}

# ── Test: ELB health checks used when target groups are provided ──────────────

run "elb_health_check_when_target_groups_set" {
  command = plan

  variables {
    name               = "test-app"
    environment        = "test"
    ami_id             = "ami-0123456789abcdef0"
    subnet_ids         = ["subnet-aaaaaaaa"]
    security_group_ids = ["sg-11111111"]
    target_group_arns  = ["arn:aws:elasticloadbalancing:us-west-2:123456789012:targetgroup/test/abc123"]
  }

  assert {
    condition     = aws_autoscaling_group.this.health_check_type == "ELB"
    error_message = "Health check type must be ELB when target groups are provided."
  }
}

# ── Test: EC2 health checks used when no target groups provided ───────────────

run "ec2_health_check_without_target_groups" {
  command = plan

  variables {
    name               = "test-app"
    environment        = "test"
    ami_id             = "ami-0123456789abcdef0"
    subnet_ids         = ["subnet-aaaaaaaa"]
    security_group_ids = ["sg-11111111"]
    target_group_arns  = []
  }

  assert {
    condition     = aws_autoscaling_group.this.health_check_type == "EC2"
    error_message = "Health check type must be EC2 when no target groups are provided."
  }
}

# ── Test: ASG min/max/desired defaults ───────────────────────────────────────

run "asg_size_defaults" {
  command = plan

  variables {
    name               = "test-app"
    environment        = "test"
    ami_id             = "ami-0123456789abcdef0"
    subnet_ids         = ["subnet-aaaaaaaa"]
    security_group_ids = ["sg-11111111"]
  }

  assert {
    condition     = aws_autoscaling_group.this.min_size == 1
    error_message = "Default min_size must be 1."
  }

  assert {
    condition     = aws_autoscaling_group.this.max_size == 3
    error_message = "Default max_size must be 3."
  }

  assert {
    condition     = aws_autoscaling_group.this.desired_capacity == 1
    error_message = "Default desired_capacity must be 1."
  }
}
