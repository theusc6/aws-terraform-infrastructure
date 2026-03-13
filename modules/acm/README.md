# modules/acm

Requests a public **ACM certificate** using DNS validation, writes the required CNAME records into Route 53 automatically, and blocks `terraform apply` until the certificate reaches `ISSUED` status before exposing its ARN.

Key behaviours:
- DNS validation is used exclusively — email validation is not automatable and is not supported.
- All DNS validation CNAME records (primary domain + all SANs) are created in the provided hosted zone.
- `create_before_destroy` is set on the certificate so Terraform issues a new cert before destroying the old one when the domain name changes, preventing a brief window of TLS failure on an attached ALB listener.
- Always reference `output.certificate_arn` (sourced from `aws_acm_certificate_validation`) rather than the raw certificate ARN — the raw ARN is available immediately but the cert may still be in `PENDING_VALIDATION`, which causes ALB listener errors.

---

## Usage

### Single domain

```hcl
module "acm" {
  source = "../../modules/acm"

  domain_name    = "app.example.com"
  hosted_zone_id = module.dns.zone_id
  environment    = "prod"
}
```

### Domain with subject alternative names

```hcl
module "acm" {
  source = "../../modules/acm"

  domain_name               = "app.example.com"
  subject_alternative_names = ["example.com", "www.example.com"]
  hosted_zone_id            = module.dns.zone_id
  environment               = "prod"
}
```

### Wire the certificate to the ALB

```hcl
module "alb" {
  source = "../../modules/alb"

  # ... other variables ...

  certificate_arn = module.acm.certificate_arn
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
| `domain_name` | Primary domain name for the certificate (e.g. `app.example.com`). | `string` | — | yes |
| `hosted_zone_id` | Route 53 hosted zone ID in which to create DNS validation CNAME records. The zone must be authoritative for `domain_name`. | `string` | — | yes |
| `environment` | Environment name (e.g. dev, staging, prod). Applied as a tag. | `string` | — | yes |
| `subject_alternative_names` | Additional domain names covered by this certificate (SANs). | `list(string)` | `[]` | no |
| `tags` | Additional tags applied to the ACM certificate. | `map(string)` | `{}` | no |

---

## Outputs

| Name | Description |
|------|-------------|
| `certificate_arn` | ARN of the validated ACM certificate. Use this output — not the raw certificate ARN — to ensure the cert is fully `ISSUED` before being attached to an ALB listener. |
| `domain_name` | Primary domain name the certificate was issued for. |
| `domain_validation_options` | DNS validation records ACM required. Already created in Route 53 by this module — exposed for reference only. |

---

## Notes

### Why `output.certificate_arn` and not the raw ARN

`aws_acm_certificate.this.arn` is available immediately after the certificate resource is created, but ACM may still be in `PENDING_VALIDATION`. Attaching a pending certificate to an ALB listener causes an `InvalidConfigurationRequest` error. `output.certificate_arn` is sourced from `aws_acm_certificate_validation.this.certificate_arn`, which only resolves after ACM confirms the DNS records and transitions the certificate to `ISSUED`.

### Circular dependency avoidance

The ALB alias record in Route 53 (pointing the domain at the ALB DNS name) must be created **outside** this module, in the environment root module. Creating it here would introduce a circular dependency: `dns → acm → alb → dns`.

### Certificate renewal

ACM auto-renews certificates 60 days before expiry. Because the DNS validation CNAME records created by this module are permanent (they live in Route 53 for the life of the certificate), renewal is fully automatic with no manual intervention required.

### Cost

ACM public certificates are free. The only associated costs are Route 53 hosted zone charges (~$0.50/month per zone) and per-query charges for the validation CNAME lookups (negligible).
