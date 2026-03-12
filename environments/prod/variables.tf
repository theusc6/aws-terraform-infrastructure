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

variable "domain_name" {
  description = "Root domain name for the Route 53 hosted zone and ACM certificate (e.g. example.com). The ALB will be reachable at app.<domain_name>."
  type        = string
}

variable "alarm_email" {
  description = "Email address to receive CloudWatch alarm notifications. A confirmation email will be sent to this address."
  type        = string
  default     = null
}
