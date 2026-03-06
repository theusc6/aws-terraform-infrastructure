output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

output "app_security_group_id" {
  description = "Security group ID for the application layer"
  value       = module.app_sg.security_group_id
}

output "app_storage_bucket" {
  description = "Application S3 bucket name"
  value       = module.app_storage.bucket_id
}

output "app_storage_bucket_arn" {
  description = "Application S3 bucket ARN"
  value       = module.app_storage.bucket_arn
}

output "ec2_role_arn" {
  description = "IAM role ARN for EC2 instances"
  value       = module.ec2_role.role_arn
}

output "autoscaling_group_name" {
  description = "Name of the application Auto Scaling Group"
  value       = module.app_compute.autoscaling_group_name
}

output "vpc_endpoint_s3_id" {
  description = "ID of the S3 VPC Gateway Endpoint"
  value       = module.vpc_endpoint_s3.vpc_endpoint_id
}
