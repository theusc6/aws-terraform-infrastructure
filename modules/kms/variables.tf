variable "alias_name" {
  description = "KMS key alias (without the 'alias/' prefix). Used in logs and the AWS Console. Example: prod-app."
  type        = string
}

variable "description" {
  description = "Human-readable description of the key's purpose."
  type        = string
}

variable "environment" {
  description = "Environment name (e.g. dev, staging, prod). Used as a tag."
  type        = string
}

variable "deletion_window_in_days" {
  description = "Waiting period before key deletion takes effect (7–30 days). AWS will not immediately delete the key when destroy is run."
  type        = number
  default     = 30

  validation {
    condition     = var.deletion_window_in_days >= 7 && var.deletion_window_in_days <= 30
    error_message = "deletion_window_in_days must be between 7 and 30."
  }
}

variable "multi_region" {
  description = "Create a multi-region primary key. Required for cross-region replication use cases. Defaults to false."
  type        = bool
  default     = false
}

variable "key_policy" {
  description = "Custom IAM key policy document (JSON string). If null, a sensible default policy granting root and caller identity access is applied."
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags to apply to the key and alias."
  type        = map(string)
  default     = {}
}
