variable "bucket_name" {
  description = "Name of the S3 bucket (must be globally unique)"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g. dev, staging, prod)"
  type        = string
}

variable "versioning_enabled" {
  description = "Enable versioning on the S3 bucket"
  type        = bool
  default     = true
}

variable "force_destroy" {
  description = "Allow the bucket to be destroyed even when it contains objects"
  type        = bool
  default     = false
}

variable "lifecycle_rules" {
  description = "List of lifecycle rules for the bucket"
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
  description = "Additional tags to apply to the bucket"
  type        = map(string)
  default     = {}
}
