variable "name" {
  description = "Name prefix for all compute resources"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g. dev, staging, prod)"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for EC2 instances"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "subnet_ids" {
  description = "List of subnet IDs for the Auto Scaling Group"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs to attach to instances"
  type        = list(string)
}

variable "iam_instance_profile" {
  description = "Name of the IAM instance profile to attach to instances"
  type        = string
  default     = null
}

variable "min_size" {
  description = "Minimum number of instances in the ASG"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of instances in the ASG"
  type        = number
  default     = 3
}

variable "desired_capacity" {
  description = "Desired number of instances in the ASG"
  type        = number
  default     = 1
}

variable "key_name" {
  description = "EC2 key pair name for SSH access"
  type        = string
  default     = null
}

variable "user_data" {
  description = "Base64-encoded user data script to run on instance launch"
  type        = string
  default     = null
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 20
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
