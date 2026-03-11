# Unit tests for modules/monitoring
# Run with: terraform -chdir=modules/monitoring test

mock_provider "aws" {}

# ── Test: SNS topic is always created ────────────────────────────────────────

run "sns_topic_always_created" {
  command = plan

  variables {
    name                   = "test-app"
    environment            = "test"
    autoscaling_group_name = "test-app-asg"
  }

  assert {
    condition     = aws_sns_topic.alarms != null
    error_message = "SNS alarms topic must always be created."
  }
}

# ── Test: email subscription skipped when alarm_email is null ─────────────────

run "no_email_subscription_when_null" {
  command = plan

  variables {
    name                   = "test-app"
    environment            = "test"
    autoscaling_group_name = "test-app-asg"
    alarm_email            = null
  }

  assert {
    condition     = length(aws_sns_topic_subscription.email) == 0
    error_message = "No email subscription should be created when alarm_email is null."
  }
}

# ── Test: CPU warning threshold defaults to 70% ───────────────────────────────

run "cpu_warning_threshold_default" {
  command = plan

  variables {
    name                   = "test-app"
    environment            = "test"
    autoscaling_group_name = "test-app-asg"
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.cpu_high_warning.threshold == 70
    error_message = "CPU warning threshold must default to 70."
  }
}

# ── Test: CPU critical threshold defaults to 90% ─────────────────────────────

run "cpu_critical_threshold_default" {
  command = plan

  variables {
    name                   = "test-app"
    environment            = "test"
    autoscaling_group_name = "test-app-asg"
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.cpu_high_critical.threshold == 90
    error_message = "CPU critical threshold must default to 90."
  }
}

# ── Test: warning threshold must be lower than critical ───────────────────────

run "warning_threshold_lower_than_critical" {
  command = plan

  variables {
    name                   = "test-app"
    environment            = "test"
    autoscaling_group_name = "test-app-asg"
    cpu_warning_threshold  = 70
    cpu_critical_threshold = 90
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.cpu_high_warning.threshold < aws_cloudwatch_metric_alarm.cpu_high_critical.threshold
    error_message = "CPU warning threshold must be lower than the critical threshold."
  }
}

# ── Test: ALB alarms not created when alb_arn_suffix is null ──────────────────

run "alb_alarms_skipped_without_alb" {
  command = plan

  variables {
    name                   = "test-app"
    environment            = "test"
    autoscaling_group_name = "test-app-asg"
    alb_arn_suffix         = null
    target_group_arn_suffix = null
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.alb_5xx_errors) == 0
    error_message = "ALB 5xx alarm must not be created when alb_arn_suffix is null."
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.alb_unhealthy_hosts) == 0
    error_message = "Unhealthy hosts alarm must not be created when alb_arn_suffix is null."
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.alb_response_time) == 0
    error_message = "Response time alarm must not be created when alb_arn_suffix is null."
  }
}

# ── Test: ALB alarms are created when alb_arn_suffix is provided ──────────────

run "alb_alarms_created_with_alb" {
  command = plan

  variables {
    name                    = "test-app"
    environment             = "test"
    autoscaling_group_name  = "test-app-asg"
    alb_arn_suffix          = "app/test-app/abc123"
    target_group_arn_suffix = "targetgroup/test-app/def456"
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.alb_5xx_errors) == 1
    error_message = "ALB 5xx alarm must be created when alb_arn_suffix is provided."
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.alb_unhealthy_hosts) == 1
    error_message = "Unhealthy hosts alarm must be created when both ALB and target group suffixes are provided."
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.alb_response_time) == 1
    error_message = "Response time alarm must be created when alb_arn_suffix is provided."
  }
}
