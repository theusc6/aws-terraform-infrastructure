# modules/iam

Creates an **IAM Role** with configurable trust policy, managed policy attachments, inline policies, and an optional EC2 instance profile.

This module is intentionally minimal and composable. It handles the boilerplate of role creation and attachment, while keeping policy content outside the module so callers retain full control over permissions.

---

## Usage

### EC2 instance role with SSM and CloudWatch access

```hcl
module "app_role" {
  source = "../../modules/iam"

  role_name   = "my-app-prod-ec2-role"
  description = "Allows EC2 instances to use SSM Session Manager and publish CloudWatch metrics."

  trust_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
  ]

  create_instance_profile = true

  tags = {
    Application = "my-app"
  }
}
```

### Role with inline policies

```hcl
module "app_role" {
  source = "../../modules/iam"

  role_name    = "my-app-prod-ec2-role"
  trust_policy = jsonencode({ ... })

  inline_policies = {
    "s3-access" = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject"]
        Resource = "${aws_s3_bucket.app.arn}/*"
      }]
    })

    "kms-decrypt" = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = module.kms.key_arn
      }]
    })
  }

  create_instance_profile = true
}
```

### Passing the instance profile to the compute module

```hcl
module "compute" {
  source = "../../modules/compute"

  # ...
  iam_instance_profile = module.app_role.instance_profile_name
}
```

### Cross-account assume-role

```hcl
module "cross_account_role" {
  source = "../../modules/iam"

  role_name    = "ci-deploy-role"
  description  = "Assumed by GitHub Actions OIDC provider for CI/CD deployments."

  trust_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = "arn:aws:iam::${var.account_id}:oidc-provider/token.actions.githubusercontent.com"
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:<org>/<repo>:*"
        }
      }
    }]
  })

  policy_arns = ["arn:aws:iam::aws:policy/AdministratorAccess"]
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
| `role_name` | Name of the IAM role. Must be unique within the AWS account. | `string` | — | yes |
| `trust_policy` | JSON trust policy document defining which principals can assume this role. | `string` | — | yes |
| `description` | Human-readable description of the role's purpose. | `string` | `"Managed by Terraform"` | no |
| `policy_arns` | List of AWS managed or customer-managed policy ARNs to attach to the role. | `list(string)` | `[]` | no |
| `inline_policies` | Map of inline policy name → JSON policy document. Use for resource-specific permissions not suited to managed policies. | `map(string)` | `{}` | no |
| `create_instance_profile` | Whether to create an EC2 instance profile backed by this role. Set to `true` for roles used by EC2 instances. | `bool` | `false` | no |
| `tags` | Additional tags to apply to the IAM role. | `map(string)` | `{}` | no |

---

## Outputs

| Name | Description |
|------|-------------|
| `role_arn` | The ARN of the IAM role. Use in trust policies of other roles or resource-based policies. |
| `role_name` | The name of the IAM role. |
| `role_id` | The stable, unique role ID (used in IAM conditions). |
| `instance_profile_arn` | The ARN of the instance profile. `null` if `create_instance_profile = false`. |
| `instance_profile_name` | The name of the instance profile. `null` if `create_instance_profile = false`. Pass to the compute module's `iam_instance_profile`. |

---

## Notes

### Managed policies vs inline policies

- **Managed policies** (`policy_arns`) are reusable across multiple roles and can be updated independently of this Terraform configuration. Prefer AWS-managed policies where they exist (e.g. `AmazonSSMManagedInstanceCore`).
- **Inline policies** (`inline_policies`) are tightly coupled to the role. Use inline policies for resource-specific permissions that should not be shared (e.g. access to a specific S3 bucket or KMS key). This makes the role self-documenting — all permissions live in one place.

### Least privilege

Always scope `Resource` in inline policies to the specific ARN rather than `"*"`. Example:

```hcl
# Good
Resource = module.kms.key_arn

# Avoid
Resource = "*"
```

### Instance profile

IAM instance profiles are the mechanism by which EC2 instances assume an IAM role. The profile name is passed to the launch template. Only one role can be associated with an instance profile, and a role can only be associated with one instance profile at a time.

### Policy propagation delay

IAM is eventually consistent. After `terraform apply`, newly attached policies may take 5–30 seconds to take effect on running instances that have already cached their credentials. For EC2 instances, the instance metadata credential refresh cycle is approximately 5 minutes.
