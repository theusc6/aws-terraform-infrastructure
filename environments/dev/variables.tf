variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-west-2"
}

variable "account_id" {
  description = "AWS account ID — used to ensure globally unique S3 bucket names"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for EC2 instances (Amazon Linux 2023 in us-west-2)"
  type        = string
  # Amazon Linux 2023 — update this for your target region
  default = "ami-0c55b159cbfafe1f0"
}
