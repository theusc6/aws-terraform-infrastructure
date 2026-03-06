# AWS Terraform Infrastructure

A production-grade, opinionated Terraform monorepo for deploying a three-tier web application stack on AWS. The repository ships a complete set of reusable modules, three fully-configured environments (dev / staging / prod), and a GitHub Actions CI/CD pipeline that automatically plans on every pull request and applies on environment-specific git tags.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Repository Layout](#repository-layout)
- [Module Catalogue](#module-catalogue)
- [Environment Comparison](#environment-comparison)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [CI/CD Pipeline](#cicd-pipeline)
- [Security Posture](#security-posture)
- [Makefile Reference](#makefile-reference)
- [Branching & Release Strategy](#branching--release-strategy)
- [Contributing](#contributing)
- [Troubleshooting](#troubleshooting)

---

## Architecture Overview

```
                          ┌─────────────────────────────────────────────────┐
                          │                    AWS Account                   │
                          │                                                  │
                          │   ┌──────────────────────────────────────────┐  │
                          │   │                    VPC                    │  │
                          │   │  ┌─────────────────────────────────────┐ │  │
                          │   │  │         Public Subnets (AZa/b/c)    │ │  │
                          │   │  │  ┌──────────┐   ┌───────────────┐  │ │  │
Internet ─────────────────┼───┼──┤  │   ALB    │   │  NAT Gateway  │  │ │  │
                          │   │  │  └────┬─────┘   └───────────────┘  │ │  │
                          │   │  └───────┼─────────────────────────────┘ │  │
                          │   │          │                                  │  │
                          │   │  ┌───────┼─────────────────────────────┐ │  │
                          │   │  │       │  Private Subnets (AZa/b/c)  │ │  │
                          │   │  │  ┌────▼────────────────────────┐   │ │  │
                          │   │  │  │   Auto Scaling Group         │   │ │  │
                          │   │  │  │   EC2 instances (IMDSv2)     │   │ │  │
                          │   │  │  │   EBS gp3, KMS-encrypted     │   │ │  │
                          │   │  │  └─────────────────────────────┘   │ │  │
                          │   │  └─────────────────────────────────────┘ │  │
                          │   └──────────────────────────────────────────┘  │
                          │                                                  │
                          │   ┌──────────┐  ┌──────────┐  ┌─────────────┐  │
                          │   │    S3    │  │   KMS    │  │ CloudWatch  │  │
                          │   │ (storage)│  │  (keys)  │  │ + SNS alarms│  │
                          │   └──────────┘  └──────────┘  └─────────────┘  │
                          │                                                  │
                          │   ┌──────────────────────────────────────────┐  │
                          │   │       S3 + DynamoDB (Terraform State)    │  │
                          │   └──────────────────────────────────────────┘  │
                          └─────────────────────────────────────────────────┘
```

**Data flow:**
1. HTTPS traffic enters via the internet-facing ALB in the public subnets.
2. The ALB terminates TLS and forwards to EC2 instances running in private subnets.
3. EC2 instances reach the internet (for package updates, etc.) via NAT Gateways.
4. Application data is persisted to KMS-encrypted S3 buckets.
5. CloudWatch alarms publish to SNS for operational alerting.
6. VPC Flow Logs capture all traffic metadata for security auditing.

---

## Repository Layout

```
aws-terraform-infrastructure/
├── .github/
│   └── workflows/
│       ├── changelog.yml          # Auto-generate CHANGELOG on main merges
│       ├── dev.yml                # Plan + apply pipeline for dev environment
│       ├── staging.yml            # Plan + apply pipeline for staging environment
│       └── prod.yml               # Plan + apply pipeline for prod (gated)
│
├── environments/
│   ├── dev/                       # Development environment (low cost, no HA)
│   │   ├── backend.tf
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   ├── providers.tf
│   │   ├── variables.tf
│   │   └── terraform.tfvars.example
│   ├── staging/                   # Staging environment (mirrors prod topology)
│   │   └── ...
│   └── prod/                      # Production environment (HA, hardened)
│       └── ...
│
├── modules/
│   ├── alb/                       # Application Load Balancer + target group + listeners
│   ├── compute/                   # Launch template + Auto Scaling Group
│   ├── iam/                       # IAM roles, policy attachments, instance profiles
│   ├── kms/                       # Customer-managed KMS key + alias
│   ├── monitoring/                # CloudWatch alarms + SNS topic
│   ├── storage/                   # S3 bucket with encryption, versioning, lifecycle
│   └── networking/
│       ├── vpc-module/            # VPC, subnets, IGW, NAT GWs, route tables, flow logs
│       ├── security-group-module/ # Security groups with dynamic rules
│       └── vpc-endpoint-module/   # VPC endpoints (Gateway + Interface)
│
├── scripts/
│   └── setup-backend.sh           # Bootstrap Terraform remote state backend (run once)
│
├── .gitignore
├── .tflint.hcl                    # TFLint configuration
├── CHANGELOG.md
├── CONTRIBUTING.md
├── Makefile                       # Developer workflow shortcuts
└── README.md
```

---

## Module Catalogue

| Module | Purpose | Key Resources |
|--------|---------|---------------|
| [`modules/kms`](modules/kms/README.md) | Customer-managed encryption keys | `aws_kms_key`, `aws_kms_alias` |
| [`modules/networking/vpc-module`](modules/networking/vpc-module/README.md) | VPC, subnets, routing, flow logs | VPC, subnets, IGW, NAT GW, route tables |
| [`modules/networking/security-group-module`](modules/networking/security-group-module/README.md) | Dynamic security groups | `aws_security_group` |
| [`modules/networking/vpc-endpoint-module`](modules/networking/vpc-endpoint-module/README.md) | Private connectivity to AWS services | `aws_vpc_endpoint` |
| [`modules/iam`](modules/iam/README.md) | IAM roles and instance profiles | `aws_iam_role`, `aws_iam_instance_profile` |
| [`modules/alb`](modules/alb/README.md) | Application Load Balancer | ALB, target group, HTTP/HTTPS listeners |
| [`modules/compute`](modules/compute/README.md) | Auto-scaling EC2 fleet | Launch template, ASG, IMDSv2, gp3 EBS |
| [`modules/storage`](modules/storage/README.md) | Secure S3 storage | S3 bucket, versioning, lifecycle, KMS |
| [`modules/monitoring`](modules/monitoring/README.md) | Operational observability | SNS, CloudWatch alarms |

---

## Environment Comparison

| Feature | dev | staging | prod |
|---------|-----|---------|------|
| Instance type | `t3.micro` | `t3.small` | `t3.medium` |
| ASG capacity | 1–2 (desired 1) | 1–4 (desired 2) | 2–6 (desired 2) |
| NAT Gateways | 1 (shared) | 1 (shared) | 1 per AZ (HA) |
| Availability zones | 2 | 2 | 3 |
| HTTPS / TLS | Optional | Optional | Required |
| ALB deletion protection | No | No | Yes |
| KMS deletion window | 7 days | 7 days | 30 days |
| Flow log retention | 30 days | 60 days | 90 days |
| S3 lifecycle transitions | — | STANDARD_IA at 30d | GLACIER at 90d |
| CPU warning threshold | 70% | 70% | 60% |
| CPU critical threshold | 90% | 90% | 80% |
| Manual apply approval | No | No | Yes |

---

## Prerequisites

| Tool | Minimum Version | Notes |
|------|-----------------|-------|
| [Terraform](https://developer.hashicorp.com/terraform/downloads) | 1.3.0 | Enforced by `required_version` |
| [AWS CLI](https://aws.amazon.com/cli/) | 2.x | Must be configured with appropriate credentials |
| [TFLint](https://github.com/terraform-linters/tflint) | 0.50+ | For local linting (`make lint`) |
| [Checkov](https://www.checkov.io/) | 3.x | For security scanning (`make security-scan`) |
| [GNU Make](https://www.gnu.org/software/make/) | 3.81+ | For Makefile targets |
| [gh CLI](https://cli.github.com/) | 2.x | For pull request creation |

**AWS Permissions:** The deploying identity (user or role) needs IAM, EC2, VPC, S3, KMS, CloudWatch, SNS, and ALB permissions. Use `AdministratorAccess` for initial bootstrapping and lock down to least-privilege policies for ongoing CI/CD.

---

## Quick Start

### 1. Clone the repository

```bash
git clone https://github.com/<org>/aws-terraform-infrastructure.git
cd aws-terraform-infrastructure
```

### 2. Bootstrap the remote state backend (once per AWS account)

The remote state uses S3 for storage and DynamoDB for state locking. Run this script once before any `terraform init`:

```bash
export AWS_REGION=us-west-2
export BUCKET_NAME=my-org-terraform-state
export DYNAMO_TABLE=my-org-terraform-locks

bash scripts/setup-backend.sh
```

Then update the `backend.tf` files in each environment directory with your chosen bucket name and DynamoDB table name.

### 3. Configure environment variables

```bash
cp environments/dev/terraform.tfvars.example environments/dev/terraform.tfvars
# Edit the file — at minimum, set your AWS account_id and region
```

### 4. Initialise Terraform

```bash
make init ENV=dev
```

### 5. Validate and plan

```bash
make validate ENV=dev
make plan ENV=dev
```

### 6. Apply (dev/staging only — prod uses the CI/CD approval gate)

```bash
make apply ENV=dev
```

---

## CI/CD Pipeline

All three workflows follow the same structure:

```
Pull Request opened/updated
        │
        ▼
  terraform fmt --check     ← fails if files are unformatted
        │
        ▼
  terraform init
        │
        ▼
  terraform validate        ← syntax and schema check
        │
        ▼
  terraform plan            ← plan output posted as PR artefact
        │
        ▼
  checkov scan              ← fails on HIGH/CRITICAL severity findings
        │
        ▼
  tflint                    ← AWS-specific static analysis
        │
        ▼
  [PR merged / environment tag pushed]
        │
        ├── dev-* tag or PR to main → terraform apply (dev, auto-approved)
        ├── staging-* tag           → terraform apply (staging, auto-approved)
        └── prod-* tag              → manual approval → terraform apply (prod)
```

### Deployment tags

| Environment | Tag pattern | Example |
|-------------|-------------|---------|
| dev | `dev-vX.Y.Z` | `dev-v1.4.2` |
| staging | `staging-vX.Y.Z` | `staging-v1.4.2` |
| prod | `prod-vX.Y.Z` | `prod-v1.4.2` |

```bash
# Promote to production
git checkout main && git pull
git tag prod-v1.4.2
git push origin prod-v1.4.2
```

The production workflow requires a GitHub environment named `prod-approval` with at least one required reviewer configured before the `terraform apply` job runs.

### Required GitHub Secrets

The workflows authenticate to AWS using OIDC (no long-lived keys required).

| Secret / Variable | Description |
|-------------------|-------------|
| `AWS_ROLE_ARN` | IAM role ARN to assume via OIDC |
| `AWS_REGION` | Default AWS region (e.g. `us-west-2`) |
| `TF_STATE_BUCKET` | S3 bucket name for Terraform state |
| `TF_LOCK_TABLE` | DynamoDB table name for state locking |

---

## Security Posture

This repository is designed to align with the **CIS AWS Foundations Benchmark** and AWS security best practices:

| Control | Implementation |
|---------|---------------|
| Encryption at rest | All S3 buckets and EBS volumes use customer-managed KMS keys |
| Encryption in transit | S3 bucket policy denies non-TLS requests; ALB redirects HTTP→HTTPS in staging/prod |
| Least-privilege IAM | Explicit trust policies; no wildcard resource in inline policies |
| Instance metadata | IMDSv2 enforced on all EC2 instances (hop limit = 1, token required) |
| No public EC2 | Instances launch in private subnets with `map_public_ip_on_launch = false` |
| VPC Flow Logs | Enabled by default in all environments (CloudWatch Logs) |
| State backend security | S3 bucket versioning + KMS encryption + DynamoDB state locking |
| KMS key rotation | Annual automatic rotation enabled on all keys |
| ALB deletion protection | Enabled in production |
| Public S3 access | Blocked at the bucket level (all four block settings) |
| Security scanning | Checkov runs on every pull request; TFLint catches provider-specific issues |

---

## Makefile Reference

```
make help                    Show all available targets

make bootstrap               Bootstrap S3 backend and DynamoDB lock table (run once)

make init        ENV=<env>   terraform init for the selected environment
make validate    ENV=<env>   terraform validate (implies init)
make fmt                     Format all .tf files recursively
make fmt-check               Check formatting without modifying files

make plan        ENV=<env>   Generate execution plan (saved to environments/<env>/plan.tfplan)
make apply       ENV=<env>   Apply the saved plan (or auto-approve if no plan file exists)
make destroy     ENV=<env>   Destroy all resources in the selected environment (confirmation required)

make lint        ENV=<env>   Run TFLint
make security-scan ENV=<env> Run Checkov security scan

make output      ENV=<env>   Print terraform outputs
make clean                   Remove all local .terraform dirs and plan files
```

`ENV` defaults to `dev`. Override with `make plan ENV=staging`.

---

## Branching & Release Strategy

```
main  ──────────────────────────────────────────────────────────────────▶
       │  merge PR          tag dev-v1.2.0    tag staging-v1.2.0    tag prod-v1.2.0
       │  ──────────────▶   ──────────────▶   ──────────────────▶   ──────────────▶
       │  auto-deploy dev   auto-deploy dev   auto-deploy staging   manual → prod
       │
       └─ feature/my-change  (short-lived branch)
```

1. **Branch** off `main` for every change.
2. **Open a PR** — CI runs format, plan, lint, and security scan automatically.
3. **Merge to main** — triggers an automatic dev deployment.
4. **Tag** `staging-vX.Y.Z` to promote to staging.
5. **Tag** `prod-vX.Y.Z` to kick off the production workflow (requires manual approval from a reviewer in the `prod-approval` GitHub environment).

> Protect the `main` branch with required PR reviews and required status checks.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full contribution guide, including code style, commit message conventions, module design principles, and the pull request checklist.

---

## Troubleshooting

### `Error: Backend configuration changed`

Run `terraform init -reconfigure` if you changed backend settings:

```bash
make init ENV=dev
# or directly:
terraform -chdir=environments/dev init -reconfigure
```

### `Error: Failed to lock state`

Another process holds the DynamoDB lock. Check the DynamoDB table for a stale `LockID` item and delete it manually if the previous run is confirmed dead.

### `Error: AccessDenied when calling KMS`

The IAM role used by Terraform must have `kms:GenerateDataKey` and `kms:Decrypt` on the target key. Verify the key policy includes the deploying role's ARN under the `AllowKeyAdministration` statement.

### `checkov` returns false positives

Add an inline suppression comment above the resource:

```hcl
#checkov:skip=CKV_AWS_XXXX: <reason for skipping>
resource "aws_example" "this" { ... }
```

For project-wide skips, add the check ID to the `--skip-check` list in the relevant workflow YAML file.

### Formatting check fails in CI

Run `make fmt` locally before pushing:

```bash
make fmt
git add -u
git commit -m "style: run terraform fmt"
```
