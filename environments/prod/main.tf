locals {
  environment = "prod"

  vpc_cidr             = "10.2.0.0/16"
  azs                  = ["${var.region}a", "${var.region}b", "${var.region}c"]
  public_subnet_cidrs  = ["10.2.1.0/24", "10.2.2.0/24", "10.2.3.0/24"]
  private_subnet_cidrs = ["10.2.11.0/24", "10.2.12.0/24", "10.2.13.0/24"]

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
# Production uses a longer deletion window (30 days vs 7) so that accidental
# key deletion can be caught and cancelled before data becomes unrecoverable.

module "kms" {
  source = "../../modules/kms"

  alias_name              = "${local.environment}-app"
  description             = "Customer-managed key for ${local.environment} S3 and EBS encryption"
  environment             = local.environment
  deletion_window_in_days = 30
  tags                    = local.tags
}

# ── Networking ────────────────────────────────────────────────────────────────
# Production runs one NAT gateway per AZ (single_nat_gateway = false).
# This ensures that if an AZ fails, private instances in remaining AZs can
# still reach the internet for software updates and AWS API calls.

module "vpc" {
  source = "../../modules/networking/vpc-module"

  environment              = local.environment
  vpc_cidr                 = local.vpc_cidr
  azs                      = local.azs
  public_subnet_cidrs      = local.public_subnet_cidrs
  private_subnet_cidrs     = local.private_subnet_cidrs
  enable_nat_gateway       = true
  single_nat_gateway       = false # One NAT GW per AZ for full AZ-level HA
  enable_flow_logs         = true
  flow_logs_retention_days = 90 # Retain 90 days of flow logs in production
  tags                     = local.tags
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
      description = "HTTP from the internet (redirected to HTTPS by the listener)"
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
      description              = "HTTP from the ALB only — no direct internet access"
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

# ── DNS ───────────────────────────────────────────────────────────────────────
# Create the public Route 53 hosted zone for the domain. After apply, update
# your domain registrar's NS records to the name servers in the dns.name_servers
# output to delegate resolution to this zone.

module "dns" {
  source = "../../modules/dns"

  domain_name = var.domain_name
  environment = local.environment
  tags        = local.tags
}

# ── TLS Certificate ───────────────────────────────────────────────────────────
# Request and validate an ACM certificate for app.<domain>. DNS validation
# records are written to the Route 53 zone automatically — no manual steps
# required. The module blocks until ACM transitions the cert to ISSUED.

module "acm" {
  source = "../../modules/acm"

  domain_name               = "app.${var.domain_name}"
  subject_alternative_names = [var.domain_name]
  hosted_zone_id            = module.dns.zone_id
  environment               = local.environment
  tags                      = local.tags
}

# ── Load Balancing ────────────────────────────────────────────────────────────
# The HTTPS listener is enabled because module.acm provides a validated cert ARN.
# The HTTP listener automatically redirects to HTTPS (301) when certificate_arn
# is set — see the ALB module for listener logic.

module "alb" {
  source = "../../modules/alb"

  name        = "${local.environment}-app"
  environment = local.environment
  vpc_id      = module.vpc.vpc_id

  subnet_ids         = module.vpc.public_subnet_ids
  security_group_ids = [module.alb_sg.security_group_id]

  certificate_arn            = module.acm.certificate_arn
  health_check_path          = "/health"
  enable_deletion_protection = true # Prevent accidental destroy of live load balancer
  idle_timeout               = 120

  tags = local.tags
}

# ── ALB Alias Record ──────────────────────────────────────────────────────────
# Created here (not inside the DNS module) to avoid a circular dependency:
#   module.dns.zone_id → module.acm → module.alb → alias record → module.dns
# Terraform cannot resolve that cycle across module boundaries. Placing the
# alias record at the environment root module breaks the chain cleanly while
# keeping the individual modules free of cross-module coupling.
#
# An Alias record is used instead of a CNAME because:
#   - No per-query cost (AWS resolves alias records internally)
#   - Works at the zone apex (example.com, not only sub.example.com)
#   - AWS automatically tracks ALB IP address changes

resource "aws_route53_record" "alb_alias" {
  zone_id = module.dns.zone_id
  name    = "app.${var.domain_name}"
  type    = "A"

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
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
  force_destroy      = false

  lifecycle_rules = [
    {
      id              = "expire-logs"
      enabled         = true
      expiration_days = 90
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
  force_destroy      = false # Safety: production data must be explicitly emptied first

  lifecycle_rules = [
    {
      id      = "transition-to-ia-then-glacier"
      enabled = true
      transition = [
        {
          days          = 30
          storage_class = "STANDARD_IA"
        },
        {
          days          = 90
          storage_class = "GLACIER"
        }
      ]
      noncurrent_version_expiration_days = 90
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
  instance_type             = "t3.medium"
  kms_key_arn               = module.kms.key_arn
  subnet_ids                = module.vpc.private_subnet_ids
  security_group_ids        = [module.app_sg.security_group_id]
  iam_instance_profile      = module.ec2_role.instance_profile_name
  target_group_arns         = [module.alb.target_group_arn]
  health_check_grace_period = 300 # Allow time for application startup

  min_size         = 2
  max_size         = 6
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

  # Tighten thresholds in production — we have less tolerance for degradation
  cpu_warning_threshold  = 60
  cpu_critical_threshold = 80

  tags = local.tags
}
