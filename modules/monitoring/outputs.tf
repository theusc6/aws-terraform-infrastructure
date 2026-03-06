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
