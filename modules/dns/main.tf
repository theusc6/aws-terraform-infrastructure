locals {
  common_tags = merge(
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# ── Hosted Zone ───────────────────────────────────────────────────────────────
# The public hosted zone is the authoritative DNS namespace for the domain.
# After creation, update your domain registrar's name server (NS) records to
# point to the four name servers listed in the name_servers output. Until the
# registrar is updated, DNS queries will not resolve through this zone.
#
# Note: The ALB alias record (A record → ALB DNS name) is intentionally created
# at the environment level rather than inside this module. This avoids a circular
# dependency: the alias record needs the ALB DNS name, the ALB needs an ACM cert
# ARN, and the ACM module needs this zone's ID. Terraform cannot resolve that
# cycle within module boundaries — creating the alias record as a direct resource
# in the environment root module breaks the chain cleanly.

resource "aws_route53_zone" "this" {
  name    = var.domain_name
  comment = "Managed by Terraform — ${var.environment} environment"

  tags = merge(local.common_tags, {
    Name = var.domain_name
  })
}
