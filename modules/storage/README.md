# modules/storage

Creates a secure **S3 bucket** with encryption, versioning, lifecycle management, public access blocking, an HTTPS-only bucket policy, and optional server access logging.

Security controls enabled by default:
- **Public access block** — all four public access block settings are enabled, preventing any object from ever being made public (even with an explicit ACL or bucket policy).
- **HTTPS-only policy** — a `DenyNonTLSRequests` bucket policy statement denies all requests that do not use TLS (`aws:SecureTransport = false`).
- **KMS server-side encryption** — objects are encrypted with a customer-managed KMS key (or the AWS-managed `aws/s3` key when no CMK is provided).
- **Bucket key** — `bucket_key_enabled = true` reduces KMS API calls by ~99% for high-throughput workloads by caching a short-lived bucket key in S3.

---

## Usage

### Minimal (development)

```hcl
module "storage" {
  source = "../../modules/storage"

  bucket_name = "my-org-my-app-dev-data"
  environment = "dev"
}
```

### With KMS, lifecycle rules, and logging (production)

```hcl
module "storage" {
  source = "../../modules/storage"

  bucket_name        = "my-org-my-app-prod-data"
  environment        = "prod"
  kms_key_arn        = module.kms.key_arn
  versioning_enabled = true
  force_destroy      = false
  logging_bucket_id  = aws_s3_bucket.access_logs.id

  lifecycle_rules = [
    {
      id      = "transition-to-ia"
      enabled = true

      expiration_days                    = null
      noncurrent_version_expiration_days = 90

      transition = [
        {
          days          = 30
          storage_class = "STANDARD_IA"
        },
        {
          days          = 90
          storage_class = "GLACIER"
        }
      ]
    }
  ]
}
```

### Referencing the bucket in other resources

```hcl
resource "aws_s3_object" "config" {
  bucket = module.storage.bucket_id
  key    = "config/app.json"
  source = "app.json"

  # Objects inherit the bucket's KMS key from the default encryption configuration
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
| `bucket_name` | Name of the S3 bucket. Must be globally unique across all AWS accounts and regions. | `string` | — | yes |
| `environment` | Environment name (e.g. dev, staging, prod). | `string` | — | yes |
| `versioning_enabled` | Enable object versioning. Required to enable MFA delete. Recommended for buckets containing important data. | `bool` | `true` | no |
| `force_destroy` | Allow the bucket to be destroyed even when it contains objects. Set to `false` in production to prevent accidental data loss. | `bool` | `false` | no |
| `kms_key_arn` | ARN of the customer-managed KMS key for server-side encryption. When `null`, uses the AWS-managed `aws/s3` key. | `string` | `null` | no |
| `logging_bucket_id` | ID (name) of an S3 bucket to receive server access logs. When set, all requests to this bucket are logged with a prefix matching the bucket name. | `string` | `null` | no |
| `lifecycle_rules` | List of lifecycle rule objects. See the type definition below. | `list(object)` | `[]` | no |
| `tags` | Additional tags applied to the bucket. | `map(string)` | `{}` | no |

### `lifecycle_rules` type definition

```hcl
list(object({
  id                                 = string           # Unique rule identifier
  enabled                            = bool             # true to activate the rule
  expiration_days                    = optional(number) # Days until object is deleted
  noncurrent_version_expiration_days = optional(number) # Days until old version is deleted
  transition = optional(list(object({
    days          = number  # Days until transition
    storage_class = string  # STANDARD_IA, ONEZONE_IA, GLACIER, DEEP_ARCHIVE, etc.
  })))
}))
```

---

## Outputs

| Name | Description |
|------|-------------|
| `bucket_id` | The name (ID) of the S3 bucket. |
| `bucket_arn` | The ARN of the S3 bucket. Use in IAM policies and KMS key policies. |
| `bucket_domain_name` | The bucket domain name (global, path-style). |
| `bucket_regional_domain_name` | The regional domain name. Use this for applications within the same region for lower latency. |

---

## Notes

### Bucket naming

S3 bucket names must be globally unique, 3–63 characters, lowercase, and contain only letters, numbers, and hyphens. A good naming convention is:

```
<org>-<app>-<environment>-<purpose>
my-org-my-app-prod-data
my-org-my-app-prod-access-logs
```

### Bucket key

`bucket_key_enabled = true` is set on the encryption configuration. This generates a short-lived data key in S3 and uses it to encrypt multiple objects, rather than calling KMS for every PUT. For buckets with high object throughput, this significantly reduces KMS API costs and request rates.

### Access logging bucket

The access logging bucket (`logging_bucket_id`) must already exist before this module is applied. It should be a separate bucket — pointing a bucket's logs to itself causes a recursive loop that fills the bucket. The logging bucket should have its own lifecycle rules to expire old logs.

### Lifecycle and versioning ordering

The `aws_s3_bucket_lifecycle_configuration` resource has a `depends_on` relationship with `aws_s3_bucket_versioning`. If you modify versioning and lifecycle in the same apply, Terraform applies versioning first. This prevents the `NoSuchLifecycleConfiguration` error that occurs when lifecycle rules reference versioning behaviour before versioning is enabled.

### KMS key permissions

The IAM principals that read/write to this bucket must have:
- `kms:GenerateDataKey` — for writing objects
- `kms:Decrypt` — for reading objects

These permissions should be granted via inline policies in the `iam` module, not via the KMS key policy directly.

### CIS AWS Benchmark coverage

| CIS Control | Implementation |
|-------------|---------------|
| 2.1.1 — Server-side encryption | KMS encryption on all objects |
| 2.1.2 — Public access | All four block settings enabled |
| 2.1.5 — TLS required | `DenyNonTLSRequests` bucket policy |
| 3.7 — S3 access logging | Enabled via `logging_bucket_id` |
