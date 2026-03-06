variable "vpc_id" {
  description = "The VPC ID where the endpoint will be created."
  type        = string
}

variable "service_name" {
  description = "The AWS service name for the VPC endpoint (e.g. com.amazonaws.us-west-2.s3)."
  type        = string
}

variable "endpoint_type" {
  description = "The type of endpoint. Must be 'Interface' or 'Gateway'."
  type        = string
  default     = "Interface"

  validation {
    condition     = contains(["Interface", "Gateway"], var.endpoint_type)
    error_message = "endpoint_type must be 'Interface' or 'Gateway'."
  }
}

variable "security_group_ids" {
  description = "Security group IDs for the endpoint. Only applies to Interface endpoints."
  type        = list(string)
  default     = []
}

variable "subnet_ids" {
  description = "Subnet IDs for the endpoint. Required for Interface endpoints."
  type        = list(string)
  default     = []
}

variable "route_table_ids" {
  description = "Route table IDs to associate with the endpoint. Required for Gateway endpoints."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional tags to apply to the endpoint."
  type        = map(string)
  default     = {}
}
