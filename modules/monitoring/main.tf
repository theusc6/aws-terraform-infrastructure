locals {
  common_tags = merge(
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# ── SNS Topic ─────────────────────────────────────────────────────────────────
# All CloudWatch alarms in this module publish to a single SNS topic.
# Operators subscribe to this topic via email, PagerDuty, Slack (via Lambda), etc.

resource "aws_sns_topic" "alarms" {
  name = "${var.name}-alarms"
  tags = local.common_tags
}

resource "aws_sns_topic_subscription" "email" {
  count = var.alarm_email != null ? 1 : 0

  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# ── EC2 / ASG Alarms ──────────────────────────────────────────────────────────

# Warning: CPU above 70% for two consecutive 5-minute periods.
# This gives you advance notice before the critical threshold is breached,
# providing time to scale out or investigate.
resource "aws_cloudwatch_metric_alarm" "cpu_high_warning" {
  alarm_name          = "${var.name}-cpu-warning"
  alarm_description   = "CPU utilisation has been above ${var.cpu_warning_threshold}% for 10 minutes. Consider scaling out."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = var.cpu_warning_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    AutoScalingGroupName = var.autoscaling_group_name
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = local.common_tags
}

# Critical: CPU above 90% for two consecutive 5-minute periods.
# At this threshold the application is likely degraded and immediate action is required.
resource "aws_cloudwatch_metric_alarm" "cpu_high_critical" {
  alarm_name          = "${var.name}-cpu-critical"
  alarm_description   = "CRITICAL: CPU utilisation has been above ${var.cpu_critical_threshold}% for 10 minutes."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = var.cpu_critical_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    AutoScalingGroupName = var.autoscaling_group_name
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = local.common_tags
}

# EC2 status check failure: catches both instance-level and system-level failures.
# A single occurrence triggers the alarm — status check failures are always actionable.
resource "aws_cloudwatch_metric_alarm" "instance_status_check" {
  alarm_name          = "${var.name}-status-check-failed"
  alarm_description   = "One or more EC2 instances failed a status check. Instance may require recovery or replacement."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    AutoScalingGroupName = var.autoscaling_group_name
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = local.common_tags
}

# ── ALB Alarms ────────────────────────────────────────────────────────────────
# These alarms are only created when alb_arn_suffix and target_group_arn_suffix
# are provided (i.e. when an ALB is configured).

# 5xx error rate: application errors or backend timeouts above 1% are flagged.
# This is the most reliable leading indicator of user-facing degradation.
resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  count = var.alb_arn_suffix != null ? 1 : 0

  alarm_name          = "${var.name}-alb-5xx"
  alarm_description   = "ALB 5XX error count exceeded ${var.alb_5xx_threshold} in the last minute. Check application logs."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = var.alb_5xx_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = local.common_tags
}

# Unhealthy host count: alerts when the ALB has no healthy targets.
# This is the most critical ALB alarm — zero healthy hosts means 100% of traffic fails.
resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  count = var.alb_arn_suffix != null && var.target_group_arn_suffix != null ? 1 : 0

  alarm_name          = "${var.name}-unhealthy-hosts"
  alarm_description   = "CRITICAL: ALB target group has unhealthy hosts. Traffic may be failing."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.target_group_arn_suffix
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = local.common_tags
}

# Target response time: p99 latency above 3 seconds signals backend degradation.
resource "aws_cloudwatch_metric_alarm" "alb_response_time" {
  count = var.alb_arn_suffix != null ? 1 : 0

  alarm_name          = "${var.name}-high-response-time"
  alarm_description   = "ALB p99 target response time exceeded ${var.alb_response_time_threshold}s. Backend may be overloaded."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  extended_statistic  = "p99"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  threshold           = var.alb_response_time_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = local.common_tags
}
