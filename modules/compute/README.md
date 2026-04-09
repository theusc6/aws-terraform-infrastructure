# modules/compute

Creates an **EC2 Auto Scaling Group** backed by a **Launch Template**. Designed for running stateless application workloads in private subnets behind an Application Load Balancer.

Key behaviours:
- **IMDSv2 enforced** — the instance metadata service requires a signed token (`http_tokens = required`) and limits the hop count to 1, preventing SSRF attacks from reaching the metadata API.
- **EBS encryption** — the root volume is encrypted with a customer-managed KMS key (falls back to the AWS-managed `aws/ebs` key when `kms_key_arn` is not set).
- **Pinned launch template version** — the ASG is wired to `aws_launch_template.this.latest_version` rather than `$Latest`, ensuring only intentional changes trigger a rolling refresh.
- **ELB health checks** — when `target_group_arns` is non-empty, the ASG uses ELB health checks so instances failing the ALB health check are replaced, not just EC2-level failures.
- **Rolling instance refresh** — new launch template versions are rolled out with a 50% minimum healthy percentage, ensuring at least half the fleet remains in service during updates.
- **`desired_capacity` drift ignored** — external autoscaling policies (target-tracking, scheduled) are allowed to adjust capacity without Terraform overriding them on the next apply.

---

## Usage

### Minimal (no ALB, no KMS)

```hcl
module "compute" {
  source = "../../modules/compute"

  name        = "my-app-dev"
  environment = "dev"
  ami_id      = data.aws_ami.amazon_linux.id
  subnet_ids  = module.vpc.private_subnet_ids
  security_group_ids = [module.app_sg.security_group_id]
}
```

### Full (ALB, KMS, IAM profile, user data)

```hcl
module "compute" {
  source = "../../modules/compute"

  name        = "my-app-prod"
  environment = "prod"
  ami_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.medium"

  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.app_sg.security_group_id]

  iam_instance_profile = module.iam.instance_profile_name
  kms_key_arn          = module.kms.key_arn
  target_group_arns    = [module.alb.target_group_arn]

  min_size                 = 2
  max_size                 = 6
  desired_capacity         = 2
  health_check_grace_period = 300

  root_volume_size = 30

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    # ... install and start your application ...
  EOF
  )
}
```

### Resolving the AMI dynamically

Rather than hardcoding an AMI ID, use a data source:

```hcl
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
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
| `name` | Name prefix for all compute resources. | `string` | — | yes |
| `environment` | Environment name (e.g. dev, staging, prod). | `string` | — | yes |
| `ami_id` | AMI ID for EC2 instances. Use `aws_ami` data source to avoid hardcoding. | `string` | — | yes |
| `subnet_ids` | List of private subnet IDs. Should span multiple AZs for HA. | `list(string)` | — | yes |
| `security_group_ids` | List of security group IDs to attach to EC2 instances. | `list(string)` | — | yes |
| `instance_type` | EC2 instance type. | `string` | `"t3.micro"` | no |
| `iam_instance_profile` | Name of the IAM instance profile to attach. Required for SSM Session Manager and CloudWatch agent. | `string` | `null` | no |
| `min_size` | Minimum number of instances the ASG will maintain. | `number` | `1` | no |
| `max_size` | Maximum number of instances the ASG can scale to. | `number` | `3` | no |
| `desired_capacity` | Initial desired instance count. Ignored after first apply (external policies manage this). | `number` | `1` | no |
| `health_check_grace_period` | Seconds after instance launch before health checks begin. Increase if startup takes longer than the default. | `number` | `300` | no |
| `target_group_arns` | ALB/NLB target group ARNs. When non-empty, health check type switches to `ELB`. | `list(string)` | `[]` | no |
| `kms_key_arn` | ARN of the customer-managed KMS key for EBS encryption. When `null`, uses the AWS-managed `aws/ebs` key. | `string` | `null` | no |
| `key_name` | EC2 key pair name for SSH access. Prefer SSM Session Manager over SSH — no key or open port 22 required. | `string` | `null` | no |
| `user_data` | Base64-encoded bootstrap script executed on first boot. | `string` | `null` | no |
| `root_volume_size` | Root EBS volume size in GiB. | `number` | `20` | no |
| `tags` | Additional tags applied to all resources including instance and volume tag specifications. | `map(string)` | `{}` | no |

---

## Outputs

| Name | Description |
|------|-------------|
| `launch_template_id` | The ID of the launch template. |
| `launch_template_arn` | The ARN of the launch template. |
| `autoscaling_group_name` | The name of the Auto Scaling Group. Pass to the monitoring module's `autoscaling_group_name`. |
| `autoscaling_group_arn` | The ARN of the Auto Scaling Group. |

---

## Notes

### Instance metadata (IMDSv2)

IMDSv2 is enforced with `http_tokens = required` and `http_put_response_hop_limit = 1`. Applications running on these instances must use IMDSv2-compatible SDKs (AWS SDK v2+, AWS CLI v2+). If your application uses `curl http://169.254.169.254/latest/...` directly, update it to use the token-based flow:

```bash
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
curl -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id
```

### Instance access via SSM

SSH access is not required (and no security group rule for port 22 is defined). Use AWS Systems Manager Session Manager for shell access:

```bash
aws ssm start-session --target <instance-id>
```

The instance profile must include the `AmazonSSMManagedInstanceCore` managed policy.

### Rolling refresh behaviour

When the launch template is updated (e.g. new AMI, new instance type), the ASG performs a rolling instance refresh. At least 50% of instances are kept healthy at all times. The refresh can take several minutes for large fleets.

To trigger a manual refresh after updating the AMI:

```bash
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name <asg-name> \
  --preferences '{"MinHealthyPercentage": 50}'
```

### `desired_capacity` management

Terraform ignores changes to `desired_capacity` after initial creation. This allows target-tracking and scheduled scaling policies to adjust capacity without being reset on every `terraform apply`. If you need to force a specific capacity, temporarily remove the `ignore_changes` lifecycle rule.
