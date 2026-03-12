# Unit tests for modules/dns
# Run with: terraform -chdir=modules/dns test
#
# These tests use mock providers so no AWS credentials or live resources are needed.
# They validate hosted zone creation, tagging, and output wiring.

mock_provider "aws" {}

# ── Test: hosted zone creation ────────────────────────────────────────────────

run "creates_hosted_zone_for_domain" {
  command = plan

  variables {
    domain_name = "example.com"
    environment = "test"
  }

  assert {
    condition     = aws_route53_zone.this.name == "example.com"
    error_message = "Hosted zone must be created for the specified domain name."
  }
}

# ── Test: zone comment ────────────────────────────────────────────────────────

run "zone_comment_includes_environment" {
  command = plan

  variables {
    domain_name = "example.com"
    environment = "prod"
  }

  assert {
    condition     = can(regex("prod", aws_route53_zone.this.comment))
    error_message = "Zone comment must reference the environment name."
  }
}

# ── Test: tagging ─────────────────────────────────────────────────────────────

run "applies_required_tags" {
  command = plan

  variables {
    domain_name = "example.com"
    environment = "staging"
    tags = {
      Project = "demo"
    }
  }

  assert {
    condition     = aws_route53_zone.this.tags["Environment"] == "staging"
    error_message = "Environment tag must match the environment variable."
  }

  assert {
    condition     = aws_route53_zone.this.tags["ManagedBy"] == "Terraform"
    error_message = "ManagedBy tag must be set to 'Terraform'."
  }

  assert {
    condition     = aws_route53_zone.this.tags["Name"] == "example.com"
    error_message = "Name tag must be set to the domain name."
  }
}

# ── Test: output wiring ───────────────────────────────────────────────────────

run "outputs_zone_name" {
  command = plan

  variables {
    domain_name = "example.com"
    environment = "test"
  }

  assert {
    condition     = output.zone_name == "example.com"
    error_message = "zone_name output must match the domain_name variable."
  }
}
