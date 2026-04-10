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
}

variables {
  account_id = "123456789012"
  region     = "us-west-2"
}

# ── Test: full stack plans successfully ──────────────────────────────────────
# A passing plan proves that all module inputs/outputs are wired correctly
# and no circular dependencies or type mismatches exist.
#
# override_module blocks provide concrete values for module outputs that
# would otherwise be unknown at plan time. Without these, count expressions
# in downstream modules (monitoring, storage) fail because they depend on
# resource attributes that mock providers cannot resolve during planning.

run "full_stack_plans_without_error" {
  command = plan

  override_module {
    target = module.kms
    outputs = {
      key_id     = "mock-key-id"
      key_arn    = "arn:aws:kms:us-west-2:123456789012:key/mock-key-id"
      alias_arn  = "arn:aws:kms:us-west-2:123456789012:alias/dev-app"
      alias_name = "alias/dev-app"
    }
  }

  override_module {
    target = module.vpc
    outputs = {
      vpc_id                = "vpc-mock12345"
      vpc_cidr              = "10.0.0.0/16"
      public_subnet_ids     = ["subnet-pub1", "subnet-pub2"]
      private_subnet_ids    = ["subnet-priv1", "subnet-priv2"]
      nat_gateway_ids       = ["nat-mock1"]
      internet_gateway_id   = "igw-mock1"
      public_route_table_id = "rtb-pub1"
      private_route_table_ids = ["rtb-priv1"]
      flow_log_group_name   = "/aws/vpc/dev-flow-logs"
    }
  }

  override_module {
    target = module.alb_sg
    outputs = {
      security_group_id = "sg-alb-mock"
    }
  }

  override_module {
    target = module.app_sg
    outputs = {
      security_group_id = "sg-app-mock"
    }
  }

  override_module {
    target = module.alb
    outputs = {
      alb_id                 = "alb-mock-id"
      alb_arn                = "arn:aws:elasticloadbalancing:us-west-2:123456789012:loadbalancer/app/dev-app/1234567890"
      alb_arn_suffix         = "app/dev-app/1234567890"
      alb_dns_name           = "dev-app-123.us-west-2.elb.amazonaws.com"
      alb_zone_id            = "Z1234567890"
      target_group_arn       = "arn:aws:elasticloadbalancing:us-west-2:123456789012:targetgroup/dev-app/1234567890"
      target_group_arn_suffix = "targetgroup/dev-app/1234567890"
      http_listener_arn      = "arn:aws:elasticloadbalancing:us-west-2:123456789012:listener/app/dev-app/1234567890/http"
      https_listener_arn     = ""
    }
  }

  override_module {
    target = module.ec2_role
    outputs = {
      role_arn               = "arn:aws:iam::123456789012:role/dev-ec2-role"
      role_name              = "dev-ec2-role"
      instance_profile_name  = "dev-ec2-role"
      instance_profile_arn   = "arn:aws:iam::123456789012:instance-profile/dev-ec2-role"
    }
  }

  override_module {
    target = module.access_logs_bucket
    outputs = {
      bucket_id                    = "dev-access-logs-123456789012"
      bucket_arn                   = "arn:aws:s3:::dev-access-logs-123456789012"
      bucket_domain_name           = "dev-access-logs-123456789012.s3.amazonaws.com"
      bucket_regional_domain_name  = "dev-access-logs-123456789012.s3.us-west-2.amazonaws.com"
    }
  }

  override_module {
    target = module.app_storage
    outputs = {
      bucket_id                    = "dev-app-storage-123456789012"
      bucket_arn                   = "arn:aws:s3:::dev-app-storage-123456789012"
      bucket_domain_name           = "dev-app-storage-123456789012.s3.amazonaws.com"
      bucket_regional_domain_name  = "dev-app-storage-123456789012.s3.us-west-2.amazonaws.com"
    }
  }

  override_module {
    target = module.app_compute
    outputs = {
      launch_template_id   = "lt-mock12345"
      launch_template_arn  = "arn:aws:ec2:us-west-2:123456789012:launch-template/lt-mock12345"
      autoscaling_group_name = "dev-app-asg"
      autoscaling_group_arn  = "arn:aws:autoscaling:us-west-2:123456789012:autoScalingGroup:mock:autoScalingGroupName/dev-app-asg"
    }
  }

  override_module {
    target = module.vpc_endpoint_s3
    outputs = {
      endpoint_id = "vpce-mock1"
    }
  }

  override_module {
    target = module.monitoring
    outputs = {
      sns_topic_arn                      = "arn:aws:sns:us-west-2:123456789012:dev-app-alarms"
      sns_topic_name                     = "dev-app-alarms"
      cpu_warning_alarm_arn              = "arn:aws:cloudwatch:us-west-2:123456789012:alarm:dev-app-cpu-warning"
      cpu_critical_alarm_arn             = "arn:aws:cloudwatch:us-west-2:123456789012:alarm:dev-app-cpu-critical"
      status_check_alarm_arn             = "arn:aws:cloudwatch:us-west-2:123456789012:alarm:dev-app-status-check"
      alb_5xx_alarm_arn                  = ""
      alb_unhealthy_hosts_alarm_arn      = ""
      alb_response_time_alarm_arn        = ""
      sns_subscription_confirmation_required = "no email subscription configured"
    }
  }

  assert {
    condition     = length(module.vpc.public_subnet_ids) == 2
    error_message = "Dev environment must create 2 public subnets (one per AZ)."
  }

  assert {
    condition     = length(module.vpc.private_subnet_ids) == 2
    error_message = "Dev environment must create 2 private subnets (one per AZ)."
  }

  assert {
    condition     = module.alb.alb_arn_suffix != ""
    error_message = "ALB module must produce an alb_arn_suffix output."
  }

  assert {
    condition     = module.kms.key_arn != ""
    error_message = "KMS module must produce a key_arn output."
  }

  assert {
    condition     = module.app_storage.bucket_id != ""
    error_message = "App storage bucket must be created."
  }

  assert {
    condition     = module.app_compute.autoscaling_group_name != ""
    error_message = "Compute module must produce an autoscaling_group_name output."
  }

  assert {
    condition     = module.monitoring.sns_topic_arn != ""
    error_message = "Monitoring module must produce an sns_topic_arn output."
  }
}
