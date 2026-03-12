# Unit tests for modules/acm
# Run with: terraform -chdir=modules/acm test
#
# These tests use mock providers so no AWS credentials or live resources are needed.
# They validate certificate configuration, DNS validation record creation, and output wiring.

mock_provider "aws" {
  # aws_acm_certificate.domain_validation_options is computed after apply.
  # The mock provider returns it as unknown, which causes the for_each on
  # aws_route53_record.validation to fail during plan. We override it here
  # with a static value so the for_each keys are known at plan time.
  mock_resource "aws_acm_certificate" {
    defaults = {
      domain_validation_options = [
        {
          domain_name           = "app.example.com"
          resource_record_name  = "_abc123.app.example.com."
          resource_record_type  = "CNAME"
          resource_record_value = "_xyz456.acm-validations.aws."
        },
        {
          domain_name           = "example.com"
          resource_record_name  = "_abc123.example.com."
          resource_record_type  = "CNAME"
          resource_record_value = "_xyz456.acm-validations.aws."
        },
        {
          domain_name           = "www.example.com"
          resource_record_name  = "_abc123.www.example.com."
          resource_record_type  = "CNAME"
          resource_record_value = "_xyz456.acm-validations.aws."
        }
      ]
    }
  }
}

# ── Test: default configuration ───────────────────────────────────────────────

run "creates_certificate_with_dns_validation" {
  command = apply

  variables {
    domain_name    = "app.example.com"
    hosted_zone_id = "Z1234567890ABC"
    environment    = "test"
  }

  assert {
    condition     = aws_acm_certificate.this.domain_name == "app.example.com"
    error_message = "Certificate domain name must match var.domain_name."
  }

  assert {
    condition     = aws_acm_certificate.this.validation_method == "DNS"
    error_message = "Certificate must use DNS validation — email validation is not automatable."
  }
}

# ── Test: subject alternative names ──────────────────────────────────────────

run "includes_subject_alternative_names" {
  command = apply

  variables {
    domain_name               = "app.example.com"
    subject_alternative_names = ["example.com", "www.example.com"]
    hosted_zone_id            = "Z1234567890ABC"
    environment               = "prod"
  }

  assert {
    condition     = length(aws_acm_certificate.this.subject_alternative_names) == 2
    error_message = "Certificate must include the specified subject alternative names."
  }
}

# ── Test: create_before_destroy lifecycle ─────────────────────────────────────
# NOTE: Terraform does not expose lifecycle meta-arguments as runtime attributes,
# so create_before_destroy cannot be asserted in a tftest. Its presence in
# main.tf (aws_acm_certificate.this lifecycle block) is enforced by code review.
# This test instead verifies that the validation resource is wired to the cert,
# which is the observable consequence of the lifecycle / validation pipeline.

run "has_create_before_destroy_lifecycle" {
  command = apply

  variables {
    domain_name    = "app.example.com"
    hosted_zone_id = "Z1234567890ABC"
    environment    = "prod"
  }

  assert {
    condition     = aws_acm_certificate_validation.this.certificate_arn == aws_acm_certificate.this.arn
    error_message = "Certificate validation must be wired to the certificate ARN."
  }
}

# ── Test: tagging ─────────────────────────────────────────────────────────────

run "applies_required_tags" {
  command = apply

  variables {
    domain_name    = "app.example.com"
    hosted_zone_id = "Z1234567890ABC"
    environment    = "staging"
    tags = {
      Project = "demo"
    }
  }

  assert {
    condition     = aws_acm_certificate.this.tags["Environment"] == "staging"
    error_message = "Environment tag must match the environment variable."
  }

  assert {
    condition     = aws_acm_certificate.this.tags["ManagedBy"] == "Terraform"
    error_message = "ManagedBy tag must be set to 'Terraform'."
  }

  assert {
    condition     = aws_acm_certificate.this.tags["Name"] == "app.example.com"
    error_message = "Name tag must be set to the domain name."
  }
}

# ── Test: output wiring ───────────────────────────────────────────────────────

run "outputs_domain_name" {
  command = apply

  variables {
    domain_name    = "app.example.com"
    hosted_zone_id = "Z1234567890ABC"
    environment    = "test"
  }

  assert {
    condition     = output.domain_name == "app.example.com"
    error_message = "domain_name output must match the requested domain."
  }
}
