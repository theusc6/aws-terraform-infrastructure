# Unit tests for modules/networking/vpc-endpoint-module
# Run with: terraform -chdir=modules/networking/vpc-endpoint-module test

mock_provider "aws" {}

# ── Test: Interface endpoint wires security groups and subnets ────────────────

run "interface_endpoint_uses_sg_and_subnets" {
  command = plan

  variables {
    vpc_id        = "vpc-12345678"
    service_name  = "com.amazonaws.us-west-2.ssm"
    endpoint_type = "Interface"
    security_group_ids = ["sg-11111111"]
    subnet_ids         = ["subnet-aaaaaaaa", "subnet-bbbbbbbb"]
  }

  assert {
    condition     = aws_vpc_endpoint.this.vpc_endpoint_type == "Interface"
    error_message = "Endpoint type must be Interface."
  }

  assert {
    condition     = length(aws_vpc_endpoint.this.security_group_ids) == 1
    error_message = "Interface endpoint must attach the supplied security group IDs."
  }

  assert {
    condition     = length(aws_vpc_endpoint.this.subnet_ids) == 2
    error_message = "Interface endpoint must attach the supplied subnet IDs."
  }

  assert {
    condition     = length(aws_vpc_endpoint.this.route_table_ids) == 0
    error_message = "Interface endpoint must not have route_table_ids."
  }
}

# ── Test: Gateway endpoint wires route tables, not SGs or subnets ─────────────

run "gateway_endpoint_uses_route_tables" {
  command = plan

  variables {
    vpc_id          = "vpc-12345678"
    service_name    = "com.amazonaws.us-west-2.s3"
    endpoint_type   = "Gateway"
    route_table_ids = ["rtb-11111111", "rtb-22222222"]
  }

  assert {
    condition     = aws_vpc_endpoint.this.vpc_endpoint_type == "Gateway"
    error_message = "Endpoint type must be Gateway."
  }

  assert {
    condition     = length(aws_vpc_endpoint.this.route_table_ids) == 2
    error_message = "Gateway endpoint must attach the supplied route table IDs."
  }

  assert {
    condition     = length(aws_vpc_endpoint.this.security_group_ids) == 0
    error_message = "Gateway endpoint must not have security_group_ids."
  }

  assert {
    condition     = length(aws_vpc_endpoint.this.subnet_ids) == 0
    error_message = "Gateway endpoint must not have subnet_ids."
  }
}

# ── Test: invalid endpoint_type is rejected ───────────────────────────────────

run "rejects_invalid_endpoint_type" {
  command = plan

  variables {
    vpc_id        = "vpc-12345678"
    service_name  = "com.amazonaws.us-west-2.s3"
    endpoint_type = "GatewayLoadBalancer"
  }

  expect_failures = [var.endpoint_type]
}

# ── Test: ManagedBy tag is always applied ─────────────────────────────────────

run "managed_by_tag_always_present" {
  command = plan

  variables {
    vpc_id       = "vpc-12345678"
    service_name = "com.amazonaws.us-west-2.ssm"
  }

  assert {
    condition     = aws_vpc_endpoint.this.tags["ManagedBy"] == "Terraform"
    error_message = "ManagedBy=Terraform tag must always be applied."
  }
}
