output "certificate_arn" {
  description = "ARN of the validated ACM certificate. Use this output (not aws_acm_certificate.arn) to ensure the certificate is fully ISSUED before it is attached to an ALB listener."
  value       = aws_acm_certificate_validation.this.certificate_arn
}

output "domain_name" {
  description = "Primary domain name the certificate was issued for."
  value       = aws_acm_certificate.this.domain_name
}

output "domain_validation_options" {
  description = "DNS validation records that ACM requires. Exposed here for reference — they are already created by this module in the provided hosted zone."
  value       = aws_acm_certificate.this.domain_validation_options
}
