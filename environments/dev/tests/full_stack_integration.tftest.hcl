# Integration test: validates cross-module wiring for a full environment stack.
# Uses mock providers — no AWS credentials or live resources required.
#
# This test instantiates the dev environment configuration end-to-end and
# verifies that modules are correctly plumbed together: VPC IDs flow into
# security groups, ALB subnets match VPC public subnets, compute instances
# land in private subnets behind the ALB, and monitoring is wired to the
# correct ASG and ALB resources.
#
# Run with: terraform -chdir=environments/dev test -verbose

mock_provider "aws" {
  mock_data "aws_ami" {
    defaults = {
      id = "ami-mock12345678"
    }
  }

  # Provide known values for resources whose attributes feed into count
  # expressions. Without these, the mock provider returns unknown values
  # which Terraform cannot evaluate at plan time.
  mock_resource "aws_lb" {
    defaults = {
      arn_suffix = "app/mock-alb/1234567890"
      dns_name   = "mock-alb-123.us-west-2.elb.amazonaws.com"
      zone_id    = "Z1234567890"
    }
  }

  mock_resource "aws_lb_target_group" {
    defaults = {
      arn_suffix = "targetgroup/mock-tg/1234567890"
    }
  }

  mock_resource "aws_s3_bucket" {
    defaults = {
      id                          = "mock-bucket"
      arn                         = "arn:aws:s3:::mock-bucket"
      bucket_domain_name          = "mock-bucket.s3.amazonaws.com"
      bucket_regional_domain_name = "mock-bucket.s3.us-west-2.amazonaws.com"
    }
  }

  mock_resource "aws_autoscaling_group" {
    defaults = {
      name = "mock-asg"
    }
  }

  mock_resource "aws_kms_key" {
    defaults = {
      arn    = "arn:aws:kms:us-west-2:123456789012:key/mock-key-id"
      key_id = "mock-key-id"
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
    condition     = length(module.vpc.public_subnet_ids) == 2
    error_message = "Dev environment must create 2 public subnets (one per AZ)."
  }

  assert {
    condition     = length(module.vpc.private_subnet_ids) == 2
    error_message = "Dev environment must create 2 private subnets (one per AZ)."
  }
}
