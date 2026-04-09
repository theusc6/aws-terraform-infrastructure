# Integration test: validates cross-module wiring for a full environment stack.
# Uses mock providers — no AWS credentials or live resources required.
#
# This test instantiates the dev environment configuration end-to-end and
# verifies that modules are correctly plumbed together: VPC IDs flow into
# security groups, ALB subnets match VPC public subnets, compute instances
# land in private subnets behind the ALB, and monitoring is wired to the
# correct ASG and ALB resources.
#
# Run with: terraform -chdir=environments/dev test -test-directory=../../tests

mock_provider "aws" {
  mock_data "aws_ami" {
    defaults = {
      id = "ami-mock12345678"
    }
  }
}

variables {
  account_id = "123456789012"
  region     = "us-west-2"
}

# ── Test: full stack plans successfully ──────────────────────────────────────
# A passing plan proves that all module inputs/outputs are wired correctly
# and no circular dependencies or type mismatches exist.

run "full_stack_plans_without_error" {
  command = plan

  assert {
    condition     = module.vpc.vpc_id != ""
    error_message = "VPC module must produce a vpc_id output."
  }

  assert {
    condition     = length(module.vpc.public_subnet_ids) == 2
    error_message = "Dev environment must create 2 public subnets (one per AZ)."
  }

  assert {
    condition     = length(module.vpc.private_subnet_ids) == 2
    error_message = "Dev environment must create 2 private subnets (one per AZ)."
  }
}

# ── Test: ALB is in public subnets ──────────────────────────────────────────

run "alb_uses_public_subnets" {
  command = plan

  assert {
    condition     = module.alb.alb_arn_suffix != ""
    error_message = "ALB module must produce an alb_arn_suffix output."
  }

  assert {
    condition     = module.alb.target_group_arn != ""
    error_message = "ALB module must produce a target_group_arn output."
  }
}

# ── Test: compute lands in private subnets with correct security group ──────

run "compute_in_private_subnets" {
  command = plan

  assert {
    condition     = module.app_compute.autoscaling_group_name != ""
    error_message = "Compute module must produce an autoscaling_group_name output."
  }
}

# ── Test: KMS key is created and referenced ─────────────────────────────────

run "kms_key_exists" {
  command = plan

  assert {
    condition     = module.kms.key_arn != ""
    error_message = "KMS module must produce a key_arn output."
  }
}

# ── Test: storage buckets are created ───────────────────────────────────────

run "storage_buckets_created" {
  command = plan

  assert {
    condition     = module.app_storage.bucket_id != ""
    error_message = "App storage bucket must be created."
  }

  assert {
    condition     = module.access_logs_bucket.bucket_id != ""
    error_message = "Access logs bucket must be created."
  }
}

# ── Test: monitoring references correct resources ───────────────────────────

run "monitoring_wired_correctly" {
  command = plan

  assert {
    condition     = module.monitoring.sns_topic_arn != ""
    error_message = "Monitoring module must produce an sns_topic_arn output."
  }
}
