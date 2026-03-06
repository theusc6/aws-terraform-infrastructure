output "role_arn" {
  description = "The ARN of the IAM role"
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "The name of the IAM role"
  value       = aws_iam_role.this.name
}

output "role_id" {
  description = "The stable and unique string identifying the role"
  value       = aws_iam_role.this.id
}

output "instance_profile_arn" {
  description = "The ARN of the instance profile (null if not created)"
  value       = var.create_instance_profile ? aws_iam_instance_profile.this[0].arn : null
}

output "instance_profile_name" {
  description = "The name of the instance profile (null if not created)"
  value       = var.create_instance_profile ? aws_iam_instance_profile.this[0].name : null
}
