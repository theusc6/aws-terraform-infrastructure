output "key_id" {
  description = "The globally unique KMS key ID (UUID format)."
  value       = aws_kms_key.this.key_id
}

output "key_arn" {
  description = "The ARN of the KMS key. Use this when referencing the key in IAM policies or resource encryption configurations."
  value       = aws_kms_key.this.arn
}

output "alias_arn" {
  description = "The ARN of the KMS alias."
  value       = aws_kms_alias.this.arn
}

output "alias_name" {
  description = "The full alias name including the 'alias/' prefix (e.g. alias/prod-app)."
  value       = aws_kms_alias.this.name
}
