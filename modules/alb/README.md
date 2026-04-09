# modules/alb

Creates an **Application Load Balancer** with a target group and HTTP/HTTPS listeners. Designed to sit in front of an Auto Scaling Group created by the `compute` module.

Key behaviours:
- When a TLS certificate ARN is provided, the HTTP listener issues a permanent (301) redirect to HTTPS and a separate HTTPS listener is created.
- When no certificate is provided (e.g. dev), HTTP traffic is forwarded directly to the target group — no redirect loop.
- Target group membership is managed entirely by the Auto Scaling Group (pass the target group ARN to the compute module's `target_group_arns`).
- The `create_before_destroy` lifecycle rule on the target group prevents a brief window of zero healthy targets during replacement.

---

## Usage

### HTTP only (dev)

```hcl
module "alb" {
  source = "../../modules/alb"

  name        = "my-app-dev"
  environment = "dev"
  vpc_id      = module.vpc.vpc_id
  subnet_ids  = module.vpc.public_subnet_ids
  security_group_ids = [module.alb_sg.security_group_id]

  health_check_path = "/health"
  target_port       = 8080
}
```

### HTTPS with redirect (staging / prod)

```hcl
module "alb" {
  source = "../../modules/alb"

  name        = "my-app-prod"
  environment = "prod"
  vpc_id      = module.vpc.vpc_id
  subnet_ids  = module.vpc.public_subnet_ids
  security_group_ids = [module.alb_sg.security_group_id]

  certificate_arn            = "arn:aws:acm:us-west-2:123456789012:certificate/abc..."
  ssl_policy                 = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  enable_deletion_protection = true

  health_check_path    = "/health"
  target_port          = 8080
  deregistration_delay = 60
}
```

### Wire up the compute module

```hcl
module "compute" {
  source = "../../modules/compute"

  # ... other variables ...

  target_group_arns = [module.alb.target_group_arn]
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
| `name` | Name prefix for all ALB resources (ALB, target group, listeners). | `string` | — | yes |
| `environment` | Environment name (e.g. dev, staging, prod). | `string` | — | yes |
| `vpc_id` | VPC ID in which the ALB and target group will be created. | `string` | — | yes |
| `subnet_ids` | List of public subnet IDs across multiple AZs. At least two subnets in different AZs are required. | `list(string)` | — | yes |
| `security_group_ids` | List of security group IDs to attach to the ALB. The SG should allow inbound 80 and 443 from the internet. | `list(string)` | — | yes |
| `internal` | Set to `true` for an internal (private) ALB. `false` creates an internet-facing ALB. | `bool` | `false` | no |
| `enable_deletion_protection` | Prevent accidental deletion of the ALB. Always enable this in production. | `bool` | `false` | no |
| `idle_timeout` | Time in seconds the ALB waits for a client to send a request before closing the connection. | `number` | `60` | no |
| `target_port` | Port on which EC2 instances receive traffic from the ALB. | `number` | `80` | no |
| `health_check_path` | HTTP path used to assess target health. Must return 2xx or 3xx. | `string` | `"/health"` | no |
| `deregistration_delay` | Seconds the ALB waits after a target begins deregistering before completing deregistration. Allows in-flight requests to finish. | `number` | `30` | no |
| `certificate_arn` | ACM certificate ARN for HTTPS. When provided, HTTP redirects to HTTPS and an HTTPS listener is created. Leave `null` for HTTP-only. | `string` | `null` | no |
| `ssl_policy` | SSL/TLS negotiation policy for the HTTPS listener. | `string` | `"ELBSecurityPolicy-TLS13-1-2-2021-06"` | no |
| `tags` | Additional tags applied to all ALB resources. | `map(string)` | `{}` | no |

---

## Outputs

| Name | Description |
|------|-------------|
| `alb_id` | The ID of the Application Load Balancer. |
| `alb_arn` | The ARN of the Application Load Balancer. |
| `alb_arn_suffix` | The ARN suffix of the ALB. Used as a CloudWatch metric dimension. |
| `alb_dns_name` | The DNS name of the ALB. Point your domain's CNAME or alias record here. |
| `alb_zone_id` | The canonical hosted zone ID of the ALB. Required for Route 53 alias records. |
| `target_group_arn` | The ARN of the ALB target group. Pass to the compute module's `target_group_arns`. |
| `target_group_arn_suffix` | The ARN suffix of the target group. Used as a CloudWatch metric dimension. |
| `http_listener_arn` | The ARN of the HTTP (port 80) listener. |
| `https_listener_arn` | The ARN of the HTTPS (port 443) listener. Empty string if no certificate was provided. |

---

## Notes

### Security group requirements

The ALB security group must allow:
- Inbound TCP 80 from `0.0.0.0/0` (redirected to 443)
- Inbound TCP 443 from `0.0.0.0/0` (when HTTPS is enabled)
- Outbound TCP `target_port` to the EC2 instance security group

The EC2 instance security group must allow:
- Inbound TCP `target_port` from the ALB security group only (not from the internet)

### SSL policy selection

The default `ELBSecurityPolicy-TLS13-1-2-2021-06` enforces TLS 1.2+ and prefers TLS 1.3. This drops support for older clients (IE11, Android < 5.0). If broader compatibility is required, use `ELBSecurityPolicy-TLS-1-2-Ext-2018-06`.

### Deregistration delay

The default `30` seconds is intentionally low for dev/staging. In production, set this to at least `60` (or match your application's longest request duration) to ensure graceful draining.

### Cost implications

An Application Load Balancer incurs:
- An hourly charge per ALB (~$0.008/hour in us-east-1)
- LCU (Load Balancer Capacity Unit) charges based on traffic volume

For dev environments with minimal traffic, costs are negligible. For production, monitor LCU usage in CloudWatch.
