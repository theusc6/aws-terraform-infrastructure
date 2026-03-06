variable "name" {
  description = "Name prefix for all compute resources (launch template, ASG)."
  type        = string
}

variable "environment" {
  description = "Environment name (e.g. dev, staging, prod)."
  type        = string
}

variable "ami_id" {
  description = "AMI ID for EC2 instances. Use the aws_ami data source to resolve dynamically rather than hardcoding."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type (e.g. t3.micro, t3.small, t3.medium)."
  type        = string
  default     = "t3.micro"
}

variable "subnet_ids" {
  description = "List of private subnet IDs the ASG distributes instances across. Should span multiple AZs."
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs to attach to EC2 instances."
  type        = list(string)
}

variable "iam_instance_profile" {
  description = "Name of the IAM instance profile to attach to instances. Required for SSM access and CloudWatch agent."
  type        = string
  default     = null
}

variable "min_size" {
  description = "Minimum number of instances the ASG will maintain."
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of instances the ASG can scale to."
  type        = number
  default     = 3
}

variable "desired_capacity" {
  description = "Initial desired instance count. Terraform ignores drift after initial creation to allow autoscaling policies to manage this value."
  type        = number
  default     = 1
}

variable "health_check_grace_period" {
  description = "Seconds after instance launch before health checks begin. Increase this if your user_data script or application startup takes longer than the default."
  type        = number
  default     = 300
}

variable "target_group_arns" {
  description = "List of ALB/NLB target group ARNs to associate with the ASG. When non-empty, health_check_type is automatically set to ELB."
  type        = list(string)
  default     = []
}

variable "kms_key_arn" {
  description = "ARN of the customer-managed KMS key used to encrypt EBS root volumes. When null, AWS uses an AWS-managed key (aws/ebs). Providing a CMK is strongly recommended for production."
  type        = string
  default     = null
}

variable "key_name" {
  description = "EC2 key pair name for SSH access. Prefer SSM Session Manager over SSH where possible — no key or open port 22 required."
  type        = string
  default     = null
}

variable "user_data" {
  description = "Base64-encoded user data script executed on first boot. Use this for bootstrapping (install agents, configure app, etc.)."
  type        = string
  default     = null
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB."
  type        = number
  default     = 20
}

variable "tags" {
  description = "Additional tags applied to all resources, including instance and volume tag specifications."
  type        = map(string)
  default     = {}
}
