variable "vpc_id" {
  description = "The VPC ID where the endpoint will be created."
  type        = string
}

variable "service_name" {
  description = "The service name for the VPC endpoint."
  type        = string
}

variable "endpoint_type" {
  description = "The type of endpoint: Interface or Gateway."
  default     = "Interface"
  type        = string
}

variable "security_group_ids" {
  description = "List of security group IDs to be associated with the endpoint."
  type        = list(string)
  default     = []
}

variable "subnet_ids" {
  description = "List of subnet IDs for the endpoint. Required for Interface type."
  type        = list(string)
  default     = []
}

