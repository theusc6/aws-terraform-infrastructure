locals {
  environment = "dev"

  vpc_cidr             = "10.0.0.0/16"
  azs                  = ["${var.region}a", "${var.region}b"]
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]

  tags = {
    Project = "demo"
    Owner   = "platform-team"
  }
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
  single_nat_gateway   = true # Single NAT GW keeps dev costs low
  tags                 = local.tags
}

module "app_sg" {
  source = "../../modules/networking/security-group-module"

  name        = "${local.environment}-app-sg"
  description = "Security group for ${local.environment} application servers"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = [local.vpc_cidr]
      description = "HTTP from within the VPC"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = [local.vpc_cidr]
      description = "HTTPS from within the VPC"
    }
  ]

  tags = local.tags
}

# VPC Endpoint for S3 — avoids NAT gateway charges for S3 traffic
module "vpc_endpoint_s3" {
  source = "../../modules/networking/vpc-endpoint-module"

  vpc_id        = module.vpc.vpc_id
  service_name  = "com.amazonaws.${var.region}.s3"
  endpoint_type = "Gateway"
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

module "app_storage" {
  source = "../../modules/storage"

  bucket_name        = "${local.environment}-app-storage-${var.account_id}"
  environment        = local.environment
  versioning_enabled = true

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

  ami_id               = var.ami_id
  instance_type        = "t3.micro"
  subnet_ids           = module.vpc.private_subnet_ids
  security_group_ids   = [module.app_sg.security_group_id]
  iam_instance_profile = module.ec2_role.instance_profile_name

  min_size         = 1
  max_size         = 2
  desired_capacity = 1

  tags = local.tags
}
