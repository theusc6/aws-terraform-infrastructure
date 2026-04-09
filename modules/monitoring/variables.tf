variable "name" {
  description = "Name prefix for all monitoring resources (SNS topic, alarms)."
  type        = string
}

variable "environment" {
  description = "Environment name (e.g. dev, staging, prod)."
  type        = string
}

variable "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group to monitor. Used as a CloudWatch dimension."
  type        = string
}

variable "alarm_email" {
  description = "Email address to receive alarm notifications. A subscription confirmation email will be sent. Set to null to skip email subscription."
  type        = string
  default     = null
}

variable "cpu_warning_threshold" {
  description = "CPU utilisation percentage that triggers the warning alarm."
  type        = number
  default     = 70
}

variable "cpu_critical_threshold" {
  description = "CPU utilisation percentage that triggers the critical alarm."
  type        = number
  default     = 90
}

variable "alb_arn_suffix" {
  description = "ARN suffix of the Application Load Balancer (from the ALB module's alb_arn_suffix output). ALB alarms are skipped when this is null."
  type        = string
  default     = null
}

variable "target_group_arn_suffix" {
  description = "ARN suffix of the ALB target group (from the ALB module's target_group_arn_suffix output). Required for the unhealthy host alarm."
  type        = string
  default     = null
}

variable "alb_5xx_threshold" {
  description = "Number of ALB 5XX responses per minute that triggers the error alarm."
  type        = number
  default     = 10
}

variable "alb_response_time_threshold" {
  description = "ALB p99 target response time in seconds that triggers the latency alarm."
  type        = number
  default     = 3
}

variable "tags" {
  description = "Additional tags to apply to all monitoring resources."
  type        = map(string)
  default     = {}
}
