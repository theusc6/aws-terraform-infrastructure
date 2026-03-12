# ── DNS Outputs ───────────────────────────────────────────────────────────────

output "name_servers" {
  description = "Route 53 name servers for the hosted zone. Update your domain registrar's NS records to these values to activate DNS resolution."
  value       = module.dns.name_servers
}

output "app_fqdn" {
  description = "Fully qualified domain name of the application (e.g. app.example.com). This is the public URL that resolves to the load balancer."
  value       = aws_route53_record.alb_alias.fqdn
}

output "certificate_arn" {
  description = "ARN of the ACM certificate attached to the ALB HTTPS listener."
  value       = module.acm.certificate_arn
}

# ── Network Outputs ───────────────────────────────────────────────────────────

output "vpc_id" {
  description = "The ID of the VPC."
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets (ALB, NAT gateways)."
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets (EC2 instances)."
  value       = module.vpc.private_subnet_ids
}

output "flow_log_group_name" {
  description = "CloudWatch Log Group name for VPC Flow Logs."
  value       = module.vpc.flow_log_group_name
}

# ── Security Group Outputs ────────────────────────────────────────────────────

output "alb_security_group_id" {
  description = "Security group ID attached to the Application Load Balancer."
  value       = module.alb_sg.security_group_id
}

output "app_security_group_id" {
  description = "Security group ID for the application EC2 instances."
  value       = module.app_sg.security_group_id
}

# ── Load Balancer Outputs ─────────────────────────────────────────────────────

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer. Point your domain's CNAME to this value."
  value       = module.alb.alb_dns_name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer."
  value       = module.alb.alb_arn
}

output "target_group_arn" {
  description = "ARN of the ALB target group."
  value       = module.alb.target_group_arn
}

# ── Storage Outputs ───────────────────────────────────────────────────────────

output "app_storage_bucket" {
  description = "Name of the application S3 bucket."
  value       = module.app_storage.bucket_id
}

output "app_storage_bucket_arn" {
  description = "ARN of the application S3 bucket."
  value       = module.app_storage.bucket_arn
}

output "access_logs_bucket" {
  description = "Name of the S3 access logs bucket."
  value       = module.access_logs_bucket.bucket_id
}

# ── Encryption Outputs ────────────────────────────────────────────────────────

output "kms_key_arn" {
  description = "ARN of the customer-managed KMS key used for S3 and EBS encryption."
  value       = module.kms.key_arn
}

output "kms_key_alias" {
  description = "Alias of the KMS key (e.g. alias/dev-app)."
  value       = module.kms.alias_name
}

# ── Compute Outputs ───────────────────────────────────────────────────────────

output "autoscaling_group_name" {
  description = "Name of the application Auto Scaling Group."
  value       = module.app_compute.autoscaling_group_name
}

output "launch_template_id" {
  description = "ID of the EC2 launch template."
  value       = module.app_compute.launch_template_id
}

# ── IAM Outputs ───────────────────────────────────────────────────────────────

output "ec2_role_arn" {
  description = "ARN of the IAM role attached to EC2 instances."
  value       = module.ec2_role.role_arn
}

# ── Monitoring Outputs ────────────────────────────────────────────────────────

output "alarm_sns_topic_arn" {
  description = "ARN of the SNS topic that receives CloudWatch alarm notifications."
  value       = module.monitoring.sns_topic_arn
}

# ── VPC Endpoint Outputs ──────────────────────────────────────────────────────

output "vpc_endpoint_s3_id" {
  description = "ID of the S3 VPC Gateway Endpoint."
  value       = module.vpc_endpoint_s3.vpc_endpoint_id
}
