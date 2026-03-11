# Unit tests for modules/alb
# Run with: terraform -chdir=modules/alb test

mock_provider "aws" {}

# ── Test: HTTP-only (no certificate) ─────────────────────────────────────────

run "http_only_when_no_certificate" {
  command = plan

  variables {
    name               = "test-app"
    environment        = "dev"
    vpc_id             = "vpc-12345678"
    subnet_ids         = ["subnet-aaa", "subnet-bbb"]
    security_group_ids = ["sg-12345678"]
  }

  assert {
    condition     = length(aws_lb_listener.https) == 0
    error_message = "No HTTPS listener should be created when certificate_arn is null."
  }
}

# ── Test: HTTPS listener created when certificate is provided ─────────────────

run "https_listener_created_with_certificate" {
  command = plan

  variables {
    name               = "test-app"
    environment        = "prod"
    vpc_id             = "vpc-12345678"
    subnet_ids         = ["subnet-aaa", "subnet-bbb"]
    security_group_ids = ["sg-12345678"]
    certificate_arn    = "arn:aws:acm:us-west-2:123456789012:certificate/fake-cert-id"
  }

  assert {
    condition     = length(aws_lb_listener.https) == 1
    error_message = "HTTPS listener must be created when certificate_arn is provided."
  }

  assert {
    condition     = aws_lb_listener.https[0].port == 443
    error_message = "HTTPS listener must be on port 443."
  }

  assert {
    condition     = aws_lb_listener.https[0].protocol == "HTTPS"
    error_message = "HTTPS listener protocol must be HTTPS."
  }
}

# ── Test: SSL policy ──────────────────────────────────────────────────────────

run "default_ssl_policy_is_tls13" {
  command = plan

  variables {
    name               = "test-app"
    environment        = "prod"
    vpc_id             = "vpc-12345678"
    subnet_ids         = ["subnet-aaa", "subnet-bbb"]
    security_group_ids = ["sg-12345678"]
    certificate_arn    = "arn:aws:acm:us-west-2:123456789012:certificate/fake-cert-id"
  }

  assert {
    condition     = aws_lb_listener.https[0].ssl_policy == "ELBSecurityPolicy-TLS13-1-2-2021-06"
    error_message = "Default SSL policy must enforce TLS 1.2+ with TLS 1.3 preference."
  }
}

# ── Test: deletion protection default ────────────────────────────────────────

run "deletion_protection_off_by_default" {
  command = plan

  variables {
    name               = "test-app"
    environment        = "dev"
    vpc_id             = "vpc-12345678"
    subnet_ids         = ["subnet-aaa", "subnet-bbb"]
    security_group_ids = ["sg-12345678"]
  }

  assert {
    condition     = aws_lb.this.enable_deletion_protection == false
    error_message = "Deletion protection should be off by default (callers enable it for prod)."
  }
}

run "deletion_protection_can_be_enabled" {
  command = plan

  variables {
    name                       = "test-app"
    environment                = "prod"
    vpc_id                     = "vpc-12345678"
    subnet_ids                 = ["subnet-aaa", "subnet-bbb"]
    security_group_ids         = ["sg-12345678"]
    enable_deletion_protection = true
  }

  assert {
    condition     = aws_lb.this.enable_deletion_protection == true
    error_message = "Deletion protection should be enabled when set to true."
  }
}

# ── Test: target group is internet-facing (instance type) ────────────────────

run "target_group_is_instance_type" {
  command = plan

  variables {
    name               = "test-app"
    environment        = "dev"
    vpc_id             = "vpc-12345678"
    subnet_ids         = ["subnet-aaa", "subnet-bbb"]
    security_group_ids = ["sg-12345678"]
  }

  assert {
    condition     = aws_lb_target_group.this.target_type == "instance"
    error_message = "Target group must use instance target type for ASG integration."
  }
}

# ── Test: internal flag ───────────────────────────────────────────────────────

run "alb_is_internet_facing_by_default" {
  command = plan

  variables {
    name               = "test-app"
    environment        = "dev"
    vpc_id             = "vpc-12345678"
    subnet_ids         = ["subnet-aaa", "subnet-bbb"]
    security_group_ids = ["sg-12345678"]
  }

  assert {
    condition     = aws_lb.this.internal == false
    error_message = "ALB should be internet-facing by default."
  }
}
