# Unit tests for modules/networking/vpc-module
# Run with: terraform -chdir=modules/networking/vpc-module test

mock_provider "aws" {}

# ── Test: DNS settings ────────────────────────────────────────────────────────

run "dns_enabled_by_default" {
  command = plan

  variables {
    environment          = "test"
    azs                  = ["us-west-2a", "us-west-2b"]
    public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
    private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
  }

  assert {
    condition     = aws_vpc.this.enable_dns_hostnames == true
    error_message = "DNS hostnames must be enabled by default."
  }

  assert {
    condition     = aws_vpc.this.enable_dns_support == true
    error_message = "DNS support must be enabled by default."
  }
}

# ── Test: subnet count matches AZ count ──────────────────────────────────────

run "creates_correct_subnet_count" {
  command = plan

  variables {
    environment          = "test"
    azs                  = ["us-west-2a", "us-west-2b", "us-west-2c"]
    public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
    private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
  }

  assert {
    condition     = length(aws_subnet.public) == 3
    error_message = "Number of public subnets must match number of AZs."
  }

  assert {
    condition     = length(aws_subnet.private) == 3
    error_message = "Number of private subnets must match number of AZs."
  }
}

# ── Test: single NAT gateway mode ─────────────────────────────────────────────

run "single_nat_gateway_creates_one_gateway" {
  command = plan

  variables {
    environment          = "dev"
    azs                  = ["us-west-2a", "us-west-2b"]
    public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
    private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
    enable_nat_gateway   = true
    single_nat_gateway   = true
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 1
    error_message = "single_nat_gateway = true must create exactly one NAT gateway."
  }

  assert {
    condition     = length(aws_eip.nat) == 1
    error_message = "single_nat_gateway = true must create exactly one Elastic IP."
  }
}

# ── Test: HA NAT gateway mode ─────────────────────────────────────────────────

run "ha_nat_gateway_creates_one_per_az" {
  command = plan

  variables {
    environment          = "prod"
    azs                  = ["us-west-2a", "us-west-2b", "us-west-2c"]
    public_subnet_cidrs  = ["10.2.1.0/24", "10.2.2.0/24", "10.2.3.0/24"]
    private_subnet_cidrs = ["10.2.11.0/24", "10.2.12.0/24", "10.2.13.0/24"]
    enable_nat_gateway   = true
    single_nat_gateway   = false
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 3
    error_message = "HA mode must create one NAT gateway per AZ (3 AZs = 3 gateways)."
  }
}

# ── Test: no NAT gateway when disabled ───────────────────────────────────────

run "no_nat_gateway_when_disabled" {
  command = plan

  variables {
    environment          = "test"
    azs                  = ["us-west-2a", "us-west-2b"]
    public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
    private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
    enable_nat_gateway   = false
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 0
    error_message = "No NAT gateways should be created when enable_nat_gateway = false."
  }
}

# ── Test: public subnets map public IPs ───────────────────────────────────────

run "public_subnets_assign_public_ips" {
  command = plan

  variables {
    environment         = "test"
    azs                 = ["us-west-2a"]
    public_subnet_cidrs = ["10.0.1.0/24"]
  }

  assert {
    condition     = aws_subnet.public[0].map_public_ip_on_launch == true
    error_message = "Public subnets must map public IPs on launch."
  }
}

# ── Test: flow logs default ───────────────────────────────────────────────────

run "flow_logs_enabled_by_default" {
  command = plan

  variables {
    environment         = "test"
    azs                 = ["us-west-2a"]
    public_subnet_cidrs = ["10.0.1.0/24"]
  }

  assert {
    condition     = length(aws_cloudwatch_log_group.flow_logs) == 1
    error_message = "VPC flow logs should be enabled by default."
  }
}

run "flow_logs_can_be_disabled" {
  command = plan

  variables {
    environment         = "test"
    azs                 = ["us-west-2a"]
    public_subnet_cidrs = ["10.0.1.0/24"]
    enable_flow_logs    = false
  }

  assert {
    condition     = length(aws_cloudwatch_log_group.flow_logs) == 0
    error_message = "Flow logs log group should not be created when disabled."
  }
}
