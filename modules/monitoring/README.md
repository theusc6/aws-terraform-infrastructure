# modules/monitoring

Creates a **CloudWatch alarm suite** and an **SNS topic** for operational alerting. All alarms publish to a single SNS topic, which can be subscribed by email, PagerDuty, Slack (via Lambda), or any other supported protocol.

Alarms covered:
- **EC2 CPU utilisation** — warning (default 70%) and critical (default 90%) thresholds, evaluated over 10 minutes.
- **EC2 status check failures** — triggers immediately on any instance or system-level failure.
- **ALB 5xx error count** — flags application errors and backend timeouts (optional — requires `alb_arn_suffix`).
- **ALB unhealthy host count** — alerts when the target group has unhealthy instances (optional — requires both ALB and TG ARN suffixes).
- **ALB p99 response time** — flags backend latency degradation (optional — requires `alb_arn_suffix`).

All alarms use `treat_missing_data = "notBreaching"` to avoid false-positive alerts during partial outages or CloudWatch metric delivery delays.

---

## Usage

### EC2 alarms only (no ALB)

```hcl
module "monitoring" {
  source = "../../modules/monitoring"

  name                   = "my-app-dev"
  environment            = "dev"
  autoscaling_group_name = module.compute.autoscaling_group_name
  alarm_email            = "ops@example.com"
}
```

### Full suite (EC2 + ALB alarms)

```hcl
module "monitoring" {
  source = "../../modules/monitoring"

  name                   = "my-app-prod"
  environment            = "prod"
  autoscaling_group_name = module.compute.autoscaling_group_name
  alarm_email            = "oncall@example.com"

  # ALB alarms require these two values from the ALB module outputs
  alb_arn_suffix          = module.alb.alb_arn_suffix
  target_group_arn_suffix = module.alb.target_group_arn_suffix

  # Tighter thresholds for production
  cpu_warning_threshold       = 60
  cpu_critical_threshold      = 80
  alb_5xx_threshold           = 5
  alb_response_time_threshold = 1
}
```

### Adding additional SNS subscriptions

The SNS topic ARN is exported. Use it to add subscriptions outside this module (e.g. a PagerDuty or Slack integration):

```hcl
resource "aws_sns_topic_subscription" "pagerduty" {
  topic_arn = module.monitoring.sns_topic_arn
  protocol  = "https"
  endpoint  = "https://events.pagerduty.com/integration/<key>/enqueue"
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
| `name` | Name prefix for all monitoring resources. | `string` | — | yes |
| `environment` | Environment name (e.g. dev, staging, prod). | `string` | — | yes |
| `autoscaling_group_name` | Name of the Auto Scaling Group to monitor. Comes from `module.compute.autoscaling_group_name`. | `string` | — | yes |
| `alarm_email` | Email address for alarm notifications. A subscription confirmation email is sent automatically. Set to `null` to skip email subscription. | `string` | `null` | no |
| `cpu_warning_threshold` | CPU utilisation (%) that triggers the warning alarm. Evaluated over two 5-minute periods. | `number` | `70` | no |
| `cpu_critical_threshold` | CPU utilisation (%) that triggers the critical alarm. Evaluated over two 5-minute periods. | `number` | `90` | no |
| `alb_arn_suffix` | ARN suffix of the ALB (from `module.alb.alb_arn_suffix`). ALB alarms are skipped when `null`. | `string` | `null` | no |
| `target_group_arn_suffix` | ARN suffix of the ALB target group (from `module.alb.target_group_arn_suffix`). Required for the unhealthy host alarm. | `string` | `null` | no |
| `alb_5xx_threshold` | Number of ALB 5xx responses per minute that triggers the error alarm. | `number` | `10` | no |
| `alb_response_time_threshold` | ALB p99 target response time in seconds that triggers the latency alarm. | `number` | `3` | no |
| `tags` | Additional tags applied to all monitoring resources. | `map(string)` | `{}` | no |

---

## Outputs

| Name | Description |
|------|-------------|
| `sns_topic_arn` | The ARN of the SNS alarm topic. Use to add additional subscriptions. |
| `sns_topic_name` | The name of the SNS alarm topic. |
| `cpu_warning_alarm_arn` | ARN of the CPU warning CloudWatch alarm. |
| `cpu_critical_alarm_arn` | ARN of the CPU critical CloudWatch alarm. |
| `status_check_alarm_arn` | ARN of the EC2 status check CloudWatch alarm. |

---

## Alarm Reference

| Alarm | Metric | Threshold | Evaluation | Action |
|-------|--------|-----------|------------|--------|
| `<name>-cpu-warning` | `CPUUtilization` (ASG) | > `cpu_warning_threshold`% | 2 × 5 min | SNS |
| `<name>-cpu-critical` | `CPUUtilization` (ASG) | > `cpu_critical_threshold`% | 2 × 5 min | SNS |
| `<name>-status-check-failed` | `StatusCheckFailed` (ASG) | > 0 | 1 × 1 min | SNS |
| `<name>-alb-5xx` | `HTTPCode_ELB_5XX_Count` (ALB) | > `alb_5xx_threshold` | 1 × 1 min | SNS |
| `<name>-unhealthy-hosts` | `UnHealthyHostCount` (ALB+TG) | > 0 | 1 × 1 min | SNS |
| `<name>-high-response-time` | `TargetResponseTime` p99 (ALB) | > `alb_response_time_threshold` s | 2 × 1 min | SNS |

---

## Notes

### Email subscription confirmation

When `alarm_email` is set, AWS SNS sends a subscription confirmation email to the address. **The subscription remains in `PendingConfirmation` state until the recipient clicks the confirm link.** Alarms are not delivered to unconfirmed subscriptions. Confirm the subscription before relying on email alerting.

### Recommended threshold tuning

The default thresholds are conservative starting points. Tune them based on your application's observed behaviour:

- **CPU thresholds** — set warning at ~20% below your target CPU for scaling policies, and critical at the actual degradation point.
- **Response time threshold** — set based on your application's SLA. A p99 of 1s is reasonable for most web applications.
- **5xx threshold** — set based on normal error rates. A threshold of 0 is too noisy; 5–10 per minute is a useful starting point.

### ALB alarms and missing data

ALB metrics are only published when the ALB receives traffic. During periods of zero traffic, `HTTPCode_ELB_5XX_Count` and `TargetResponseTime` have no data points. `treat_missing_data = "notBreaching"` prevents these alarms from firing spuriously in low-traffic environments.

### Extending with composite alarms

For more sophisticated alerting (e.g. "alert only when CPU is high AND unhealthy hosts > 0"), use `aws_cloudwatch_composite_alarm` referencing the ARNs exported by this module.
