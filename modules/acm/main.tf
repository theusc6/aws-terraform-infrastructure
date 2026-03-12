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
# for_each on domain_validation_options handles the apex domain plus any SANs
# automatically — one validation record per unique domain name.

resource "aws_route53_record" "validation" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id = var.hosted_zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]

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
  validation_record_fqdns = [for record in aws_route53_record.validation : record.fqdn]
}
