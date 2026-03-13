# modules/dns

Creates a **Route 53 public hosted zone** for a domain. The zone ID is the primary output — it is passed to the `acm` module so certificate validation records are written to the correct zone, and to the environment root module when creating the ALB alias record.

Key behaviours:
- Creates a single public hosted zone for the zone apex (e.g. `example.com`).
- Outputs the four Route 53 name servers that must be set at the domain registrar for DNS resolution to work.
- The ALB alias record is intentionally **not** created in this module — it lives in the environment root module to avoid a circular dependency between `dns`, `acm`, and `alb`.

---

## Usage

```hcl
module "dns" {
  source = "../../modules/dns"

  domain_name = "example.com"
  environment = "prod"
}
```

### Wiring to ACM and ALB

```hcl
module "acm" {
  source = "../../modules/acm"

  domain_name               = "app.example.com"
  subject_alternative_names = ["example.com", "www.example.com"]
  hosted_zone_id            = module.dns.zone_id   # <-- zone ID from this module
  environment               = "prod"
}

# ALB alias record — created here to avoid circular dependency
resource "aws_route53_record" "alb" {
  zone_id = module.dns.zone_id
  name    = "app.example.com"
  type    = "A"

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
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
| `domain_name` | Root domain name for the hosted zone (e.g. `example.com`). Do not include a subdomain — this is the zone apex. | `string` | — | yes |
| `environment` | Environment name (e.g. dev, staging, prod). Used in the hosted zone comment and as a tag. | `string` | — | yes |
| `tags` | Additional tags applied to the hosted zone. | `map(string)` | `{}` | no |

---

## Outputs

| Name | Description |
|------|-------------|
| `zone_id` | The hosted zone ID. Pass to `modules/acm` as `hosted_zone_id` and use when creating the ALB alias record in the environment root module. |
| `name_servers` | The four Route 53 name servers for this zone. Update your domain registrar's NS records to these values to activate DNS resolution. |
| `zone_name` | The domain name of the hosted zone. |

---

## Notes

### Registrar NS delegation

After `terraform apply`, copy `output.name_servers` to your domain registrar's NS records. Until this is done, DNS queries for the domain will not resolve through Route 53. Propagation typically takes a few minutes but can take up to 48 hours depending on the registrar and TTL of any existing NS records.

### One zone per environment

Each environment (dev, staging, prod) typically uses a separate subdomain (e.g. `dev.example.com`, `staging.example.com`, `example.com`). Create one `dns` module per subdomain zone rather than sharing a single zone across environments.

### Cost

Route 53 charges ~$0.50/month per hosted zone plus $0.40 per million queries. For low-traffic or dev environments this is negligible.
