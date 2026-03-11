locals {
  environment = "staging"

  vpc_cidr             = "10.1.0.0/16"
  azs                  = ["${var.region}a", "${var.region}b"]
  public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24"]
  private_subnet_cidrs = ["10.1.11.0/24", "10.1.12.0/24"]

  tags = {
    Project     = "demo"
    Environment = local.environment
    Owner       = "platform-team"
  }
}

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

module "kms" {
  source = "../../modules/kms"

  alias_name  = "${local.environment}-app"
  description = "Customer-managed key for ${local.environment} S3 and EBS encryption"
  environment = local.environment
  tags        = local.tags
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
  single_nat_gateway   = true  # Single NAT is acceptable for staging (non-HA)
  enable_flow_logs     = true
  tags                 = local.tags
}

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
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTPS from the internet"
    },
  ]

  tags = local.tags
}

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

  subnet_ids         = module.vpc.public_subnet_ids
  security_group_ids = [module.alb_sg.security_group_id]

  # Provide an ACM certificate ARN via var.certificate_arn to enable HTTPS.
  # When set, HTTP traffic is automatically redirected to HTTPS (301).
  certificate_arn = var.certificate_arn

  health_check_path          = "/health"
  enable_deletion_protection = false

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
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
  ]

  create_instance_profile = true
  tags                    = local.tags
}

# ── Storage ───────────────────────────────────────────────────────────────────

module "access_logs_bucket" {
  source = "../../modules/storage"

  bucket_name        = "${local.environment}-access-logs-${var.account_id}"
  environment        = local.environment
  versioning_enabled = false
  kms_key_arn        = module.kms.key_arn

  lifecycle_rules = [
    {
      id              = "expire-logs"
      enabled         = true
      expiration_days = 30
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
      id      = "transition-to-ia"
      enabled = true
      transition = [
        {
          days          = 30
          storage_class = "STANDARD_IA"
        }
      ]
      noncurrent_version_expiration_days = 60
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
  instance_type             = "t3.small"
  kms_key_arn               = module.kms.key_arn
  subnet_ids                = module.vpc.private_subnet_ids
  security_group_ids        = [module.app_sg.security_group_id]
  iam_instance_profile      = module.ec2_role.instance_profile_name
  target_group_arns         = [module.alb.target_group_arn]
  health_check_grace_period = 180

  min_size         = 1
  max_size         = 4
  desired_capacity = 2

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
  alarm_email             = var.alarm_email

  tags = local.tags
}
