variable "role_name" {
  description = "Name of the IAM role"
  type        = string
}

variable "description" {
  description = "Description of the IAM role"
  type        = string
  default     = "Managed by Terraform"
}

variable "trust_policy" {
  description = "JSON trust policy document (who can assume this role)"
  type        = string
}

variable "policy_arns" {
  description = "List of managed IAM policy ARNs to attach to the role"
  type        = list(string)
  default     = []
}

variable "inline_policies" {
  description = "Map of inline policy name => JSON policy document"
  type        = map(string)
  default     = {}
}

variable "create_instance_profile" {
  description = "Whether to create an EC2 instance profile for this role"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags to apply to the role"
  type        = map(string)
  default     = {}
}
