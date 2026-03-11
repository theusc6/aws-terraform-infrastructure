# Unit tests for modules/kms
# Run with: terraform -chdir=modules/kms test
#
# These tests use mock providers so no AWS credentials or live resources are needed.
# They validate variable constraints, resource configuration, and output wiring.

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:user/test-deployer"
      user_id    = "AIDAEXAMPLEUSERID"
    }
  }
}

# ── Test: default configuration ───────────────────────────────────────────────

run "creates_key_with_defaults" {
  command = plan

  variables {
    alias_name  = "test-app"
    description = "Test KMS key"
    environment = "test"
  }

  assert {
    condition     = aws_kms_key.this.enable_key_rotation == true
    error_message = "Key rotation must be enabled by default."
  }

  assert {
    condition     = aws_kms_key.this.deletion_window_in_days == 30
    error_message = "Default deletion window should be 30 days."
  }

  assert {
    condition     = aws_kms_key.this.multi_region == false
    error_message = "Multi-region should be disabled by default."
  }

  assert {
    condition     = aws_kms_alias.this.name == "alias/test-app"
    error_message = "Alias must be prefixed with 'alias/'."
  }
}

# ── Test: output wiring ───────────────────────────────────────────────────────

run "outputs_are_wired_correctly" {
  command = plan

  variables {
    alias_name  = "prod-app"
    description = "Production application key"
    environment = "prod"
  }

  assert {
    condition     = output.alias_name == "alias/prod-app"
    error_message = "alias_name output should include the 'alias/' prefix."
  }
}

# ── Test: deletion window validation ─────────────────────────────────────────

run "rejects_deletion_window_below_7" {
  command = plan

  variables {
    alias_name              = "test-app"
    description             = "Test key"
    environment             = "test"
    deletion_window_in_days = 6
  }

  expect_failures = [var.deletion_window_in_days]
}

run "rejects_deletion_window_above_30" {
  command = plan

  variables {
    alias_name              = "test-app"
    description             = "Test key"
    environment             = "test"
    deletion_window_in_days = 31
  }

  expect_failures = [var.deletion_window_in_days]
}

run "accepts_minimum_deletion_window" {
  command = plan

  variables {
    alias_name              = "dev-app"
    description             = "Dev key with minimum window"
    environment             = "dev"
    deletion_window_in_days = 7
  }

  assert {
    condition     = aws_kms_key.this.deletion_window_in_days == 7
    error_message = "Should accept deletion window of 7 days."
  }
}

# ── Test: custom key policy ───────────────────────────────────────────────────

run "accepts_custom_key_policy" {
  command = plan

  variables {
    alias_name  = "custom-policy-key"
    description = "Key with custom policy"
    environment = "prod"
    key_policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Sid       = "AllowRoot"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::123456789012:root" }
        Action    = "kms:*"
        Resource  = "*"
      }]
    })
  }

  assert {
    condition     = aws_kms_key.this.enable_key_rotation == true
    error_message = "Key rotation must be enabled even when using a custom policy."
  }
}

# ── Test: tagging ─────────────────────────────────────────────────────────────

run "applies_environment_tag" {
  command = plan

  variables {
    alias_name  = "tagged-key"
    description = "Key with environment tag"
    environment = "staging"
  }

  assert {
    condition     = aws_kms_key.this.tags["Environment"] == "staging"
    error_message = "Environment tag must match the environment variable."
  }

  assert {
    condition     = aws_kms_key.this.tags["ManagedBy"] == "Terraform"
    error_message = "ManagedBy tag must be set to 'Terraform'."
  }
}
