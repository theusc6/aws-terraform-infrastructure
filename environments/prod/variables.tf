variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-west-2"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.region))
    error_message = "region must be a valid AWS region identifier, e.g. us-west-2."
  }
}

variable "account_id" {
  description = "AWS account ID — used to ensure globally unique S3 bucket names."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id must be a 12-digit AWS account ID."
  }
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS. Required for production — the ALB will redirect HTTP to HTTPS. Provision via aws_acm_certificate or import an existing cert."
  type        = string

  validation {
    condition     = can(regex("^arn:aws:acm:[a-z0-9-]+:[0-9]{12}:certificate/[a-f0-9-]+$", var.certificate_arn))
    error_message = "certificate_arn must be a valid ACM certificate ARN (arn:aws:acm:<region>:<account>:certificate/<id>). HTTPS is required in production."
  }
}

variable "alarm_email" {
  description = "Email address to receive CloudWatch alarm notifications. A confirmation email will be sent to this address."
  type        = string
  default     = null
}
