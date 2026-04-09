variable "bucket_name" {
  description = "Name of the S3 bucket. Must be globally unique across all AWS accounts and regions."
  type        = string
}

variable "environment" {
  description = "Environment name (e.g. dev, staging, prod)."
  type        = string
}

variable "versioning_enabled" {
  description = "Enable object versioning. Required to enable MFA delete and recommended for all buckets containing important data."
  type        = bool
  default     = true
}

variable "force_destroy" {
  description = "Allow the bucket to be destroyed even when it contains objects. Set to false in production to prevent accidental data loss."
  type        = bool
  default     = false
}

variable "kms_key_arn" {
  description = "ARN of the customer-managed KMS key to use for server-side encryption. When null, an AWS-managed key (aws/s3) is used. Providing a CMK is strongly recommended for production — it enables key usage auditing and instant access revocation."
  type        = string
  default     = null
}

variable "logging_bucket_id" {
  description = "ID (name) of an S3 bucket to receive server access logs. When set, all requests to this bucket are logged to the target bucket under a prefix matching this bucket's name. Leave null to skip access logging."
  type        = string
  default     = null
}

variable "lifecycle_rules" {
  description = "List of lifecycle rules to automatically transition or expire objects."
  type = list(object({
    id                                 = string
    enabled                            = bool
    expiration_days                    = optional(number)
    noncurrent_version_expiration_days = optional(number)
    transition = optional(list(object({
      days          = number
      storage_class = string
    })))
  }))
  default = []
}

variable "tags" {
  description = "Additional tags to apply to the bucket."
  type        = map(string)
  default     = {}
}
