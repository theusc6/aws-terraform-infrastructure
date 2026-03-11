output "sns_topic_arn" {
  description = "The ARN of the SNS alarm topic. Use this to add additional subscriptions (e.g. PagerDuty, Slack Lambda)."
  value       = aws_sns_topic.alarms.arn
}

output "sns_topic_name" {
  description = "The name of the SNS alarm topic."
  value       = aws_sns_topic.alarms.name
}

output "cpu_warning_alarm_arn" {
  description = "ARN of the CPU warning CloudWatch alarm."
  value       = aws_cloudwatch_metric_alarm.cpu_high_warning.arn
}

output "cpu_critical_alarm_arn" {
  description = "ARN of the CPU critical CloudWatch alarm."
  value       = aws_cloudwatch_metric_alarm.cpu_high_critical.arn
}

output "status_check_alarm_arn" {
  description = "ARN of the EC2 status check CloudWatch alarm."
  value       = aws_cloudwatch_metric_alarm.instance_status_check.arn
}

output "alb_5xx_alarm_arn" {
  description = "ARN of the ALB 5xx error CloudWatch alarm. Empty string when no ALB is configured."
  value       = length(aws_cloudwatch_metric_alarm.alb_5xx_errors) > 0 ? aws_cloudwatch_metric_alarm.alb_5xx_errors[0].arn : ""
}

output "alb_unhealthy_hosts_alarm_arn" {
  description = "ARN of the ALB unhealthy hosts CloudWatch alarm. Empty string when no ALB/target group is configured."
  value       = length(aws_cloudwatch_metric_alarm.alb_unhealthy_hosts) > 0 ? aws_cloudwatch_metric_alarm.alb_unhealthy_hosts[0].arn : ""
}

output "alb_response_time_alarm_arn" {
  description = "ARN of the ALB p99 response time CloudWatch alarm. Empty string when no ALB is configured."
  value       = length(aws_cloudwatch_metric_alarm.alb_response_time) > 0 ? aws_cloudwatch_metric_alarm.alb_response_time[0].arn : ""
}

output "sns_subscription_confirmation_required" {
  description = "Reminder: if alarm_email was set, the SNS email subscription requires manual confirmation. Check the inbox for the address provided and confirm before alarms become active."
  value       = var.alarm_email != null ? "ACTION REQUIRED: confirm SNS subscription sent to ${var.alarm_email}" : "no email subscription configured"
}
