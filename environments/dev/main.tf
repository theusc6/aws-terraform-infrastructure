locals {
  environment = "dev"

  vpc_cidr             = "10.0.0.0/16"
  azs                  = ["${var.region}a", "${var.region}b"]
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]

  tags = {
    Project     = "demo"
    Environment = local.environment
    Owner       = "platform-team"
  }
}

# Resolve the latest Amazon Linux 2023 AMI for the target region at plan time.
# This avoids hardcoded AMI IDs that are region-specific and quickly become stale.
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# ── KMS ───────────────────────────────────────────────────────────────────────
# A single customer-managed key covers all encryption in this environment
# (S3 objects, EBS volumes). Using one key per environment keeps IAM policies
# simple while still giving us full audit control via CloudTrail.

module "kms" {
  source = "../../modules/kms"

  alias_name   = "${local.environment}-app"
  description  = "Customer-managed key for ${local.environment} S3 and EBS encryption"
  environment  = local.environment
  tags         = local.tags
}

# ── Networking ────────────────────────────────────────────────────────────────

module "vpc" {
  source = "../../modules/networking/vpc-module"

  environment          = local.environment
  vpc_cidr             = local.vpc_cidr
  azs                  = local.azs
  public_subnet_cidrs  = local.public_subnet_cidrs
  private_subnet_cidrs = local.private_subnet_cidrs
  enable_nat_gateway   = true
  single_nat_gateway   = true  # Single NAT GW keeps dev costs low; not HA
  enable_flow_logs     = true
  tags                 = local.tags
}

# ALB security group — allows inbound HTTP from anywhere.
# No HTTPS in dev (no ACM certificate required), so only port 80 is opened.
module "alb_sg" {
  source = "../../modules/networking/security-group-module"

  name        = "${local.environment}-alb-sg"
  description = "Security group for the ${local.environment} Application Load Balancer"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTP from the internet"
    },
  ]

  tags = local.tags
}

# Application security group — only allows traffic from the ALB.
# No direct internet access to the instances, even on port 80.
# This uses the ingress_sg_rules variable (added in the last hardening pass)
# to reference the ALB SG as the source rather than a CIDR range.
module "app_sg" {
  source = "../../modules/networking/security-group-module"

  name        = "${local.environment}-app-sg"
  description = "Security group for ${local.environment} application servers"
  vpc_id      = module.vpc.vpc_id

  ingress_sg_rules = [
    {
      from_port                = 80
      to_port                  = 80
      protocol                 = "tcp"
      source_security_group_id = module.alb_sg.security_group_id
      description              = "HTTP from the ALB only"
    },
  ]

  tags = local.tags
}

# S3 VPC Gateway Endpoint — routes S3 traffic over the AWS backbone instead of
# through the NAT gateway. This eliminates NAT processing charges for S3 traffic,
# which can be significant in data-heavy workloads.
module "vpc_endpoint_s3" {
  source = "../../modules/networking/vpc-endpoint-module"

  vpc_id          = module.vpc.vpc_id
  service_name    = "com.amazonaws.${var.region}.s3"
  endpoint_type   = "Gateway"
  route_table_ids = module.vpc.private_route_table_ids
  tags            = local.tags
}

# ── Load Balancing ────────────────────────────────────────────────────────────

module "alb" {
  source = "../../modules/alb"

  name        = "${local.environment}-app"
  environment = local.environment
  vpc_id      = module.vpc.vpc_id

  # ALB must be in public subnets to receive internet traffic.
  subnet_ids         = module.vpc.public_subnet_ids
  security_group_ids = [module.alb_sg.security_group_id]

  # No ACM certificate in dev — HTTP only.
  # Set certificate_arn to enable HTTPS + automatic HTTP→HTTPS redirect.
  certificate_arn = null

  health_check_path          = "/health"
  enable_deletion_protection = false  # Allow terraform destroy in dev

  tags = local.tags
}

# ── IAM ──────────────────────────────────────────────────────────────────────

module "ec2_role" {
  source = "../../modules/iam"

  role_name   = "${local.environment}-ec2-role"
  description = "IAM role for ${local.environment} EC2 instances"

  trust_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  policy_arns = [
    # SSM Session Manager — allows shell access without a bastion host or open SSH port
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    # CloudWatch agent — enables detailed memory, disk, and custom metrics
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
  ]

  create_instance_profile = true
  tags                    = local.tags
}

# ── Storage ───────────────────────────────────────────────────────────────────

# Dedicated bucket for S3 server access logs.
# Using a separate bucket prevents recursive logging and keeps log data isolated.
module "access_logs_bucket" {
  source = "../../modules/storage"

  bucket_name        = "${local.environment}-access-logs-${var.account_id}"
  environment        = local.environment
  versioning_enabled = false  # Access logs grow large; versioning is not needed here
  kms_key_arn        = module.kms.key_arn

  lifecycle_rules = [
    {
      id      = "expire-logs"
      enabled = true
      expiration_days = 30  # Keep 30 days of access logs in dev
    }
  ]

  tags = local.tags
}

module "app_storage" {
  source = "../../modules/storage"

  bucket_name        = "${local.environment}-app-storage-${var.account_id}"
  environment        = local.environment
  versioning_enabled = true
  kms_key_arn        = module.kms.key_arn
  logging_bucket_id  = module.access_logs_bucket.bucket_id

  lifecycle_rules = [
    {
      id      = "expire-old-noncurrent-versions"
      enabled = true
      noncurrent_version_expiration_days = 30
    }
  ]

  tags = local.tags
}

# ── Compute ───────────────────────────────────────────────────────────────────

module "app_compute" {
  source = "../../modules/compute"

  name        = "${local.environment}-app"
  environment = local.environment

  ami_id                    = data.aws_ami.amazon_linux_2023.id
  instance_type             = "t3.micro"
  kms_key_arn               = module.kms.key_arn
  subnet_ids                = module.vpc.private_subnet_ids
  security_group_ids        = [module.app_sg.security_group_id]
  iam_instance_profile      = module.ec2_role.instance_profile_name
  target_group_arns         = [module.alb.target_group_arn]
  health_check_grace_period = 120

  min_size         = 1
  max_size         = 2
  desired_capacity = 1

  tags = local.tags
}

# ── Monitoring ────────────────────────────────────────────────────────────────

module "monitoring" {
  source = "../../modules/monitoring"

  name                    = "${local.environment}-app"
  environment             = local.environment
  autoscaling_group_name  = module.app_compute.autoscaling_group_name
  alb_arn_suffix          = module.alb.alb_arn_suffix
  target_group_arn_suffix = module.alb.target_group_arn_suffix

  # Set alarm_email to receive notifications. In production, consider routing
  # to PagerDuty or Opsgenie via an SNS→Lambda integration instead.
  alarm_email = null

  tags = local.tags
}
