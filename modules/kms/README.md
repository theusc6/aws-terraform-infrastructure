# Module: kms

Creates a customer-managed AWS KMS key (CMK) with automatic annual key rotation, a human-readable alias, and a least-privilege key policy. The module is the encryption foundation for this infrastructure — the same key ARN is consumed by the `storage` module (S3 SSE) and the `compute` module (EBS volume encryption).

## Architecture Notes

- **Key rotation** is always enabled (`enable_key_rotation = true`). AWS automatically generates new backing key material every 365 days. Existing ciphertexts continue to decrypt transparently; the Key ID and alias remain unchanged.
- **Key policy** follows a two-statement least-privilege model:
  1. The account root principal (`arn:aws:iam::<account_id>:root`) receives full `kms:*` access as a break-glass backstop.
  2. The identity running Terraform receives administrative actions (create, rotate, disable, delete, tag). Service principals that _use_ the key (S3, EBS) are granted access via IAM policies on their respective roles — not in the key policy itself — keeping the blast radius small.
- A custom policy can be supplied via `var.key_policy` to override the default entirely (e.g., to grant cross-account access or add a service principal directly).
- **Multi-region keys** are opt-in (`multi_region = false` by default). Enable this only when you need to replicate encrypted objects to another region without re-encrypting them.
- The **deletion window** defaults to 30 days. AWS will not immediately delete the key when `terraform destroy` is run; the pending deletion can be cancelled during that window. Minimum is 7 days; maximum is 30.

## Prerequisites

| Requirement | Version |
|---|---|
| Terraform | `>= 1.3` |
| AWS Provider | `>= 5.0` |
| IAM permissions | `kms:CreateKey`, `kms:CreateAlias`, `kms:PutKeyPolicy`, `kms:TagResource`, `kms:EnableKeyRotation` |

The Terraform identity must have permission to call `sts:GetCallerIdentity` so the module can inject the caller's ARN into the default key policy.

## Usage

```hcl
module "kms" {
  source = "../../modules/kms"

  alias_name              = "prod-app"
  description             = "Customer-managed key for prod S3 and EBS encryption"
  environment             = "prod"
  deletion_window_in_days = 30
  tags = {
    Project = "demo"
    Owner   = "platform-team"
  }
}
```

Reference the outputs in downstream modules:

```hcl
module "app_storage" {
  source      = "../../modules/storage"
  kms_key_arn = module.kms.key_arn
  # ...
}

module "app_compute" {
  source      = "../../modules/compute"
  kms_key_arn = module.kms.key_arn
  # ...
}
```

### Custom Key Policy Example

```hcl
module "kms" {
  source = "../../modules/kms"

  alias_name   = "prod-app"
  description  = "CMK with cross-account access"
  environment  = "prod"

  key_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "RootAccess"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::111122223333:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "CrossAccountRead"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::444455556666:role/reader" }
        Action    = ["kms:Decrypt", "kms:DescribeKey"]
        Resource  = "*"
      }
    ]
  })
}
```

## Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| `alias_name` | KMS key alias (without the `alias/` prefix). Used in logs and the AWS Console. Example: `prod-app`. | `string` | — | yes |
| `description` | Human-readable description of the key's purpose. | `string` | — | yes |
| `environment` | Environment name (e.g. dev, staging, prod). Used as a tag. | `string` | — | yes |
| `deletion_window_in_days` | Waiting period before key deletion takes effect (7–30 days). AWS will not immediately delete the key when destroy is run. | `number` | `30` | no |
| `multi_region` | Create a multi-region primary key. Required for cross-region replication use cases. Defaults to false. | `bool` | `false` | no |
| `key_policy` | Custom IAM key policy document (JSON string). If null, a sensible default policy granting root and caller identity access is applied. | `string` | `null` | no |
| `tags` | Additional tags to apply to the key and alias. | `map(string)` | `{}` | no |

### Validation

`deletion_window_in_days` is validated to be between 7 and 30 (inclusive). Values outside this range will produce an error at plan time.

## Outputs

| Name | Description |
|---|---|
| `key_id` | The globally unique KMS key ID (UUID format). |
| `key_arn` | The ARN of the KMS key. Use this when referencing the key in IAM policies or resource encryption configurations. |
| `alias_arn` | The ARN of the KMS alias. |
| `alias_name` | The full alias name including the `alias/` prefix (e.g. `alias/prod-app`). |

## Important Notes and Gotchas

**Key deletion is irreversible.** Once the deletion window expires, all data encrypted with that key becomes permanently unrecoverable. Set a generous `deletion_window_in_days` in production (the default of 30 is recommended) and enable a CloudWatch alarm on the `aws_kms_key` `KeyDeletion` event if your security posture requires it.

**Service principal access is not in this key policy by default.** If an EC2 instance or S3 bucket receives a "KMS access denied" error, the fix is to add a `kms:GenerateDataKey` / `kms:Decrypt` statement to the _IAM policy attached to the service role_ — not to the key policy. The key policy's root statement delegates all authorization decisions to IAM, which is the recommended pattern.

**Aliases are globally namespaced within an account and region.** Two keys in the same account/region cannot share an alias. Choose an alias that clearly identifies the environment and workload (e.g. `prod-app`, `staging-rds`).

**Multi-region keys cannot be converted to single-region after creation** and vice versa. Plan your replication strategy before deploying.

**`terraform destroy` does not immediately delete the key.** The key enters a pending-deletion state for `deletion_window_in_days` days. Any resources still encrypted with the key will fail to access their data during and after this window.
