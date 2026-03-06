output "alb_id" {
  description = "The ID of the Application Load Balancer."
  value       = aws_lb.this.id
}

output "alb_arn" {
  description = "The ARN of the Application Load Balancer."
  value       = aws_lb.this.arn
}

output "alb_arn_suffix" {
  description = "The ARN suffix of the ALB. Used as a dimension in CloudWatch metrics."
  value       = aws_lb.this.arn_suffix
}

output "alb_dns_name" {
  description = "The DNS name of the ALB. Point your domain's CNAME or alias record to this value."
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "The canonical hosted zone ID of the ALB. Required when creating Route 53 alias records."
  value       = aws_lb.this.zone_id
}

output "target_group_arn" {
  description = "The ARN of the ALB target group. Pass this to the compute module's target_group_arns variable."
  value       = aws_lb_target_group.this.arn
}

output "target_group_arn_suffix" {
  description = "The ARN suffix of the target group. Used as a dimension in CloudWatch metrics."
  value       = aws_lb_target_group.this.arn_suffix
}

output "http_listener_arn" {
  description = "The ARN of the HTTP (port 80) listener."
  value       = aws_lb_listener.http.arn
}

output "https_listener_arn" {
  description = "The ARN of the HTTPS (port 443) listener. Empty string if no certificate was provided."
  value       = length(aws_lb_listener.https) > 0 ? aws_lb_listener.https[0].arn : ""
}
