# ── ACM Certificate ───────────────────────────────────────────────────────────
# Request a public certificate using DNS validation.
# DNS validation is preferred over email validation because it is fully automatable:
# Terraform creates the required CNAME records in Route 53 and ACM polls them to
# confirm domain ownership before issuing the certificate.

resource "aws_acm_certificate" "this" {
  domain_name               = var.domain_name
  subject_alternative_names = var.subject_alternative_names
  validation_method         = "DNS"

  tags = merge(
    {
      Name        = var.domain_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )

  # Issue a new certificate before destroying the old one when the domain name
  # changes. Without this, Terraform would destroy the cert while it is still
  # attached to an ALB listener, causing a brief outage.
  lifecycle {
    create_before_destroy = true
  }
}

# ── DNS Validation Records ────────────────────────────────────────────────────
# ACM provides the exact CNAME name and value it needs to see in DNS.
# We write those records into Route 53 on ACM's behalf.
#
# for_each keys are derived from input variables (known at plan time).
# Terraform requires that for_each keys be statically determinable during
# plan — using domain_validation_options as keys fails because that attribute
# is only populated after ACM processes the certificate request. The record
# name/value/type (the map values) may be unknown at plan time, which is fine.

locals {
  # All domains this certificate covers. ACM always returns one
  # domain_validation_options entry per domain, so this set is a safe key source.
  validation_domains = toset(concat([var.domain_name], var.subject_alternative_names))

  # Index validation options by domain name for clean lookup in the resource below.
  validation_options_by_domain = {
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => dvo
  }
}

resource "aws_route53_record" "validation" {
  for_each = local.validation_domains

  zone_id = var.hosted_zone_id
  name    = local.validation_options_by_domain[each.value].resource_record_name
  type    = local.validation_options_by_domain[each.value].resource_record_type
  records = [local.validation_options_by_domain[each.value].resource_record_value]

  # 60-second TTL keeps propagation fast while ACM waits for validation.
  # This record is permanent for the life of the certificate — a low TTL
  # does not meaningfully affect query load for a rarely-queried validation record.
  ttl = 60
}

# ── Certificate Validation ────────────────────────────────────────────────────
# This resource blocks apply until ACM confirms the DNS records are correct
# and transitions the certificate to ISSUED status.
# Always reference output.certificate_arn (which comes from this resource) rather
# than aws_acm_certificate.this.arn — the latter is available immediately but the
# cert may still be in PENDING_VALIDATION, which would cause an ALB listener error.

resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for domain in local.validation_domains : aws_route53_record.validation[domain].fqdn]
}
