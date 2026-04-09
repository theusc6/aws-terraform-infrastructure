# Unit tests for modules/storage
# Run with: terraform -chdir=modules/storage test

mock_provider "aws" {}

# ── Test: public access is always blocked ─────────────────────────────────────

run "public_access_is_fully_blocked" {
  command = plan

  variables {
    bucket_name = "test-bucket-12345"
    environment = "test"
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.this.block_public_acls == true
    error_message = "block_public_acls must always be true."
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.this.block_public_policy == true
    error_message = "block_public_policy must always be true."
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.this.ignore_public_acls == true
    error_message = "ignore_public_acls must always be true."
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.this.restrict_public_buckets == true
    error_message = "restrict_public_buckets must always be true."
  }
}

# ── Test: HTTPS-only policy is always applied ─────────────────────────────────

run "https_only_policy_applied" {
  command = apply

  variables {
    bucket_name = "test-bucket-12345"
    environment = "test"
  }

  assert {
    condition     = jsondecode(aws_s3_bucket_policy.https_only.policy).Statement[0].Effect == "Deny"
    error_message = "HTTPS-only policy must have a Deny effect."
  }

  assert {
    condition     = jsondecode(aws_s3_bucket_policy.https_only.policy).Statement[0].Condition.Bool["aws:SecureTransport"] == "false"
    error_message = "HTTPS-only policy must deny requests where aws:SecureTransport is false."
  }
}

# ── Test: versioning defaults to enabled ──────────────────────────────────────

run "versioning_enabled_by_default" {
  command = plan

  variables {
    bucket_name = "test-bucket-12345"
    environment = "test"
  }

  assert {
    condition     = aws_s3_bucket_versioning.this.versioning_configuration[0].status == "Enabled"
    error_message = "Versioning should be Enabled by default."
  }
}

run "versioning_can_be_disabled" {
  command = plan

  variables {
    bucket_name        = "test-bucket-12345"
    environment        = "test"
    versioning_enabled = false
  }

  assert {
    condition     = aws_s3_bucket_versioning.this.versioning_configuration[0].status == "Suspended"
    error_message = "Setting versioning_enabled = false should set status to Suspended."
  }
}

# ── Test: encryption configuration ───────────────────────────────────────────

run "encryption_uses_bucket_key" {
  command = plan

  variables {
    bucket_name = "test-bucket-12345"
    environment = "test"
  }

  assert {
    condition     = one(aws_s3_bucket_server_side_encryption_configuration.this.rule).bucket_key_enabled == true
    error_message = "bucket_key_enabled must be true to reduce KMS API costs."
  }
}

run "encryption_uses_provided_kms_key" {
  command = plan

  variables {
    bucket_name = "test-bucket-12345"
    environment = "prod"
    kms_key_arn = "arn:aws:kms:us-west-2:123456789012:key/fake-key-id"
  }

  assert {
    condition     = one(aws_s3_bucket_server_side_encryption_configuration.this.rule).apply_server_side_encryption_by_default[0].kms_master_key_id == "arn:aws:kms:us-west-2:123456789012:key/fake-key-id"
    error_message = "Encryption must use the provided KMS key ARN."
  }
}

# ── Test: force_destroy defaults to false ─────────────────────────────────────

run "force_destroy_off_by_default" {
  command = plan

  variables {
    bucket_name = "prod-bucket-12345"
    environment = "prod"
  }

  assert {
    condition     = aws_s3_bucket.this.force_destroy == false
    error_message = "force_destroy must default to false to protect production data."
  }
}

# ── Test: lifecycle configuration ────────────────────────────────────────────

run "no_lifecycle_config_when_rules_empty" {
  command = plan

  variables {
    bucket_name     = "test-bucket-12345"
    environment     = "test"
    lifecycle_rules = []
  }

  assert {
    condition     = length(aws_s3_bucket_lifecycle_configuration.this) == 0
    error_message = "No lifecycle resource should be created when lifecycle_rules is empty."
  }
}

run "lifecycle_config_created_when_rules_provided" {
  command = plan

  variables {
    bucket_name = "test-bucket-12345"
    environment = "test"
    lifecycle_rules = [{
      id                                 = "test-rule"
      enabled                            = true
      expiration_days                    = 90
      noncurrent_version_expiration_days = 30
      transition                         = null
    }]
  }

  assert {
    condition     = length(aws_s3_bucket_lifecycle_configuration.this) == 1
    error_message = "Lifecycle configuration resource should be created when rules are provided."
  }
}
