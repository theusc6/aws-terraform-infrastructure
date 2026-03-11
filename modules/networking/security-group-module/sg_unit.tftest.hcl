# Unit tests for modules/networking/security-group-module
# Run with: terraform -chdir=modules/networking/security-group-module test

mock_provider "aws" {}

# ── Test: SG name matches variable ────────────────────────────────────────────

run "name_is_set" {
  command = plan

  variables {
    name   = "test-sg"
    vpc_id = "vpc-12345678"
  }

  assert {
    condition     = aws_security_group.this.name == "test-sg"
    error_message = "Security group name must match the name variable."
  }
}

# ── Test: ManagedBy tag is always applied ─────────────────────────────────────

run "managed_by_tag_always_present" {
  command = plan

  variables {
    name   = "test-sg"
    vpc_id = "vpc-12345678"
  }

  assert {
    condition     = aws_security_group.this.tags["ManagedBy"] == "Terraform"
    error_message = "ManagedBy=Terraform tag must always be applied."
  }
}

# ── Test: no ingress rules by default ─────────────────────────────────────────

run "no_ingress_rules_by_default" {
  command = plan

  variables {
    name   = "test-sg"
    vpc_id = "vpc-12345678"
  }

  assert {
    condition     = length(aws_security_group.this.ingress) == 0
    error_message = "No ingress rules should be created when ingress_rules and ingress_sg_rules are empty."
  }
}

# ── Test: default egress allows all outbound ──────────────────────────────────

run "default_egress_allows_all" {
  command = plan

  variables {
    name   = "test-sg"
    vpc_id = "vpc-12345678"
  }

  assert {
    condition     = length(aws_security_group.this.egress) == 1
    error_message = "Default egress rules should create exactly one rule."
  }

  assert {
    condition     = tolist(aws_security_group.this.egress)[0].protocol == "-1"
    error_message = "Default egress rule must use protocol -1 (all traffic)."
  }

  assert {
    condition     = contains(tolist(aws_security_group.this.egress)[0].cidr_blocks, "0.0.0.0/0")
    error_message = "Default egress rule must allow 0.0.0.0/0."
  }
}

# ── Test: CIDR-based ingress rules are counted correctly ──────────────────────

run "ingress_cidr_rules_counted" {
  command = plan

  variables {
    name   = "test-sg"
    vpc_id = "vpc-12345678"
    ingress_rules = [
      {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        description = "Allow HTTP"
      },
      {
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        description = "Allow HTTPS"
      },
    ]
  }

  assert {
    condition     = length(aws_security_group.this.ingress) == 2
    error_message = "One ingress rule must be created per entry in ingress_rules."
  }
}

# ── Test: SG-source ingress rules are counted correctly ───────────────────────

run "ingress_sg_rules_counted" {
  command = plan

  variables {
    name   = "test-sg"
    vpc_id = "vpc-12345678"
    ingress_sg_rules = [
      {
        from_port                = 8080
        to_port                  = 8080
        protocol                 = "tcp"
        source_security_group_id = "sg-aabbccdd"
        description              = "Allow traffic from ALB"
      },
    ]
  }

  assert {
    condition     = length(aws_security_group.this.ingress) == 1
    error_message = "One ingress rule must be created per entry in ingress_sg_rules."
  }
}
