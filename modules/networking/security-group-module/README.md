# modules/networking/security-group-module

Creates an **EC2 Security Group** with fully dynamic ingress and egress rules. Supports both CIDR-based rules and security-group-sourced rules in separate variable lists.

The module uses `create_before_destroy = true` on the security group so that Terraform can replace security groups (e.g. when the name or VPC changes) without first destroying the old one and leaving resources temporarily without a security group.

---

## Usage

### ALB security group (internet-facing)

```hcl
module "alb_sg" {
  source = "../../modules/networking/security-group-module"

  name        = "my-app-dev-alb"
  description = "ALB — allow inbound HTTP and HTTPS from the internet"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTP from internet"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTPS from internet"
    }
  ]
}
```

### EC2 application security group (ALB-only ingress)

```hcl
module "app_sg" {
  source = "../../modules/networking/security-group-module"

  name        = "my-app-dev-ec2"
  description = "EC2 instances — allow inbound from ALB only"
  vpc_id      = module.vpc.vpc_id

  # No CIDR-based ingress — instances are not directly accessible
  ingress_sg_rules = [
    {
      from_port                = 8080
      to_port                  = 8080
      protocol                 = "tcp"
      source_security_group_id = module.alb_sg.security_group_id
      description              = "Application port from ALB"
    }
  ]
}
```

### Mixed CIDR and SG-source ingress

```hcl
module "db_sg" {
  source = "../../modules/networking/security-group-module"

  name        = "my-app-dev-db"
  description = "Database — allow from app tier and VPN CIDR"
  vpc_id      = module.vpc.vpc_id

  ingress_sg_rules = [
    {
      from_port                = 5432
      to_port                  = 5432
      protocol                 = "tcp"
      source_security_group_id = module.app_sg.security_group_id
      description              = "PostgreSQL from app tier"
    }
  ]

  ingress_rules = [
    {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      cidr_blocks = ["10.100.0.0/16"]   # VPN CIDR
      description = "PostgreSQL from VPN"
    }
  ]

  # Restrict egress to VPC only (override the default allow-all)
  egress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["10.0.0.0/8"]
      description = "All traffic to internal networks only"
    }
  ]
}
```

---

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.3.0 |
| aws | ~> 5.0 |

---

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `name` | Name of the security group. Must be unique within the VPC. | `string` | — | yes |
| `vpc_id` | VPC ID where the security group will be created. | `string` | — | yes |
| `description` | Description of the security group's purpose. | `string` | `"Managed by Terraform"` | no |
| `ingress_rules` | CIDR-based ingress rules. Use this for rules where the source is an IP range. | `list(object)` | `[]` | no |
| `ingress_sg_rules` | Security-group-sourced ingress rules. Use this when the source is another security group. | `list(object)` | `[]` | no |
| `egress_rules` | CIDR-based egress rules. Defaults to allow-all outbound (common for EC2). Restrict this in high-security environments. | `list(object)` | allow-all | no |
| `tags` | Additional tags applied to the security group. | `map(string)` | `{}` | no |

### `ingress_rules` object schema

```hcl
{
  from_port   = number          # Start of port range (or 0 for all)
  to_port     = number          # End of port range (or 0 for all)
  protocol    = string          # "tcp", "udp", "icmp", or "-1" for all
  cidr_blocks = list(string)    # Source CIDR blocks
  description = string          # Human-readable description
}
```

### `ingress_sg_rules` object schema

```hcl
{
  from_port                = number  # Start of port range
  to_port                  = number  # End of port range
  protocol                 = string  # "tcp", "udp", "icmp", or "-1"
  source_security_group_id = string  # ID of the source security group
  description              = string  # Human-readable description
}
```

### `egress_rules` object schema

Same as `ingress_rules`.

---

## Outputs

| Name | Description |
|------|-------------|
| `security_group_id` | The ID of the security group. Pass to `alb` and `compute` modules. |
| `security_group_arn` | The ARN of the security group. |
| `security_group_name` | The name of the security group. |

---

## Notes

### CIDR vs SG-source rules

AWS differentiates between CIDR-source and SG-source ingress rules. In the Terraform AWS provider, these cannot be mixed in the same `ingress` block. This module handles the split by providing two separate variables (`ingress_rules` for CIDR-based, `ingress_sg_rules` for SG-sourced), which are rendered as separate `dynamic ingress` blocks in the underlying resource.

### Egress default

The default egress rule allows all outbound traffic (`0.0.0.0/0`, all ports, all protocols). This is the standard for application servers — they need to reach package repositories, AWS APIs, and other services. For databases and other sensitive resources, restrict egress to specific CIDRs and ports.

### Security group chaining

The typical three-tier pattern is:

```
Internet → [ALB SG] → ALB → [App SG, source=ALB SG] → EC2 → [DB SG, source=App SG] → RDS
```

This ensures:
- No direct internet access to EC2 instances or databases.
- The ALB is the only ingress point.
- Databases only accept connections from the application tier.

### Naming conventions

Use descriptive names that indicate the resource and environment:

```
my-app-prod-alb     # ALB security group
my-app-prod-ec2     # Application EC2 security group
my-app-prod-db      # Database security group
```
