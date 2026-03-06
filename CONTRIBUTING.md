# Contributing Guide

Thank you for contributing to this Terraform infrastructure repository. This guide covers everything you need to know: how to set up your local environment, the standards we apply to all code, the commit message format we follow, and the pull request process.

---

## Table of Contents

- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Code Standards](#code-standards)
- [Module Design Principles](#module-design-principles)
- [Commit Message Convention](#commit-message-convention)
- [Pull Request Process](#pull-request-process)
- [Testing Your Changes](#testing-your-changes)
- [Adding a New Module](#adding-a-new-module)
- [Release Process](#release-process)

---

## Getting Started

### 1. Install prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Terraform | >= 1.3.0 | [hashicorp.com/terraform](https://developer.hashicorp.com/terraform/downloads) |
| AWS CLI | >= 2.x | [aws.amazon.com/cli](https://aws.amazon.com/cli/) |
| TFLint | >= 0.50 | `brew install tflint` or [GitHub releases](https://github.com/terraform-linters/tflint/releases) |
| Checkov | >= 3.x | `pip install checkov` |
| GNU Make | >= 3.81 | Pre-installed on most Unix systems |

### 2. Fork and clone

```bash
git clone https://github.com/<your-fork>/aws-terraform-infrastructure.git
cd aws-terraform-infrastructure
```

### 3. Configure AWS credentials

The easiest approach for local development is a named profile:

```bash
aws configure --profile my-dev-profile
export AWS_PROFILE=my-dev-profile
```

For CI/CD, the workflows use OIDC and assume an IAM role — no long-lived keys.

### 4. Bootstrap the state backend (once per AWS account)

```bash
export AWS_REGION=us-west-2
export BUCKET_NAME=my-org-terraform-state
export DYNAMO_TABLE=my-org-terraform-locks
bash scripts/setup-backend.sh
```

---

## Development Workflow

```
1. Create a branch          git checkout -b feature/describe-your-change
2. Make changes             Edit .tf files
3. Format                   make fmt
4. Lint                     make lint ENV=dev
5. Validate                 make validate ENV=dev
6. Plan                     make plan ENV=dev
7. Security scan            make security-scan ENV=dev
8. Commit                   git commit -m "feat(compute): add user_data validation"
9. Push and open PR         git push origin feature/describe-your-change
                            gh pr create --base main
```

Never commit directly to `main`. All changes must go through a pull request.

---

## Code Standards

### Formatting

All Terraform files must be formatted with `terraform fmt`. The CI pipeline enforces this with `terraform fmt -check -recursive` and will fail unformatted PRs.

```bash
make fmt          # format all files in the repo
make fmt-check    # check without modifying (same as CI)
```

### Naming conventions

| Resource type | Convention | Example |
|---------------|-----------|---------|
| Resource names | `snake_case` | `aws_lb_listener.http` |
| Variables | `snake_case` | `var.health_check_path` |
| Outputs | `snake_case` | `output "alb_dns_name"` |
| Local values | `snake_case` | `locals { common_tags = ... }` |
| Module sources | Relative paths for local, pinned version for registry | `source = "../../modules/alb"` |
| Resource labels | `"this"` for single-resource modules | `resource "aws_kms_key" "this"` |
| Tag keys | `PascalCase` | `Environment`, `ManagedBy`, `Name` |

### Tagging

Every resource must have at minimum:

```hcl
tags = merge(local.common_tags, {
  Name = "<descriptive-name>"
})
```

where `local.common_tags` is defined as:

```hcl
locals {
  common_tags = merge(
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}
```

All modules must accept a `tags = map(string)` variable (default `{}`) and merge it with `common_tags`.

### Variables

- Every variable must have a `description`.
- Use `default = null` for optional values rather than empty string.
- Add `validation` blocks for variables with constrained ranges (e.g. port numbers, retention periods).
- Prefer specific types (`list(string)`, `object({...})`) over `any`.

### Outputs

- Every output must have a `description`.
- Export everything that a caller might reasonably need — including ARN suffixes for CloudWatch dimensions.
- When a resource is conditionally created (`count = ...`), return an empty string or `null` rather than leaving the output absent.

### Comments

- Use inline comments (`#`) to explain *why*, not *what*.
- Place a comment block before any non-obvious resource explaining its purpose in the system.
- Use the section header style for major resource groups:

```hcl
# ── Section Name ─────────────────────────────────────────────────────────────
```

---

## Module Design Principles

1. **Single responsibility.** Each module does one thing well. The `compute` module provisions the ASG; it does not create VPCs or IAM roles.

2. **No hard-coded values.** Every environment-specific value (CIDR, instance type, replica count) must be a variable. No account IDs, region names, or ARNs should be hardcoded.

3. **Safe defaults.** Defaults should be safe for development but clearly documented when they need tightening for production (e.g. `force_destroy = false`, `enable_deletion_protection = false` in dev).

4. **Idempotent resources.** All resources must be safe to run multiple times. Use `create_before_destroy` where replacement would cause downtime.

5. **No provider configuration inside modules.** Modules must not contain `provider` blocks. The root module (environment) configures the provider and passes it down.

6. **Explicit over implicit.** Prefer passing explicit values over relying on data sources inside modules. This makes module behaviour predictable regardless of account context.

7. **Every module has a README.** Use the standard template (see [Adding a New Module](#adding-a-new-module)).

---

## Commit Message Convention

We follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <short summary>

[optional body — wrap at 72 characters]

[optional footer — BREAKING CHANGE: or Refs: #<issue>]
```

### Types

| Type | When to use |
|------|-------------|
| `feat` | A new feature or module |
| `fix` | A bug fix |
| `docs` | Documentation only |
| `style` | Formatting (`terraform fmt`), no logic change |
| `refactor` | Code restructuring without behaviour change |
| `test` | Adding or modifying tests |
| `chore` | Dependency updates, CI config, tooling |
| `security` | Security hardening, policy changes |

### Scopes

Use the module or environment name: `compute`, `alb`, `kms`, `networking`, `storage`, `monitoring`, `iam`, `dev`, `staging`, `prod`, `ci`.

### Examples

```
feat(alb): add optional WAF association variable

fix(compute): use pinned launch template version in ASG

docs(kms): add key rotation and multi-region examples to README

security(storage): enforce https-only bucket policy on all buckets

chore(ci): pin terraform version to 1.7.5 in workflows
```

---

## Pull Request Process

### Before opening a PR

- [ ] `make fmt` — all files formatted
- [ ] `make validate ENV=dev` — no validation errors
- [ ] `make plan ENV=dev` — plan output reviewed; no unexpected changes
- [ ] `make lint ENV=dev` — TFLint passes
- [ ] `make security-scan ENV=dev` — Checkov passes (or suppressions are justified)
- [ ] All new or modified modules have an up-to-date README

### PR title

Use the same convention as commit messages:

```
feat(monitoring): add p99 latency alarm to ALB
```

### PR description

Use this template:

```markdown
## Summary

<!-- 2-3 bullet points describing what changed and why -->

## Changes

<!-- List the files/modules changed -->

## Test plan

<!-- How did you verify this works? -->
- [ ] `terraform plan` reviewed — no unexpected resource recreation
- [ ] `terraform validate` passes
- [ ] TFLint passes
- [ ] Checkov passes (or suppressions documented)

## Notes

<!-- Anything reviewers should pay special attention to -->
```

### Review guidelines

- At least **one approval** required before merging.
- Address all review comments before merging. Mark resolved comments.
- Squash-merge feature branches to keep `main` history clean.

---

## Testing Your Changes

### Local plan

```bash
make plan ENV=dev
```

Review the plan output carefully. Look for unexpected `forces replacement` annotations — these indicate your change will destroy and recreate a resource, which may cause downtime.

### TFLint

```bash
make lint ENV=dev
```

TFLint checks for deprecated syntax, invalid resource configurations, and AWS-specific best practice violations.

### Checkov

```bash
make security-scan ENV=dev
```

Checkov performs static analysis against a library of security policies. If a finding is a false positive, suppress it with a comment and document the reason:

```hcl
#checkov:skip=CKV_AWS_18: access logging enabled via the monitoring module, not on this bucket
resource "aws_s3_bucket" "logs" { ... }
```

### Manual integration testing

For significant changes, apply to the `dev` environment and verify:

1. `terraform apply` completes without errors.
2. Resources are visible and healthy in the AWS Console.
3. Application connectivity works end-to-end (ALB → EC2 → health check passes).
4. CloudWatch alarms are in `OK` state.
5. `terraform plan` after apply shows no diff.

---

## Adding a New Module

1. **Create the directory structure:**

```
modules/<module-name>/
├── main.tf
├── variables.tf
├── outputs.tf
└── README.md
```

2. **Follow the standard layout in `main.tf`:**

```hcl
locals {
  common_tags = merge(
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# Resource definitions...
```

3. **Always include these variables:**

```hcl
variable "name"        { type = string; description = "Name prefix for all resources." }
variable "environment" { type = string; description = "Environment name (dev/staging/prod)." }
variable "tags"        { type = map(string); default = {}; description = "Additional tags." }
```

4. **Write the README** using this template:

````markdown
# modules/<name>

One-paragraph description of what this module does and why.

## Usage

```hcl
module "example" {
  source = "../../modules/<name>"

  name        = "my-app"
  environment = "dev"
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.3.0 |
| aws | ~> 5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| name | ... | `string` | — | yes |
| environment | ... | `string` | — | yes |

## Outputs

| Name | Description |
|------|-------------|
| ... | ... |

## Notes

Any important gotchas, cost implications, or operational notes.
````

5. **Wire the module into at least one environment** (typically `dev`) to prove it works end-to-end.

6. **Update** the Module Catalogue table in the root `README.md`.

---

## Release Process

Releases are tagged manually from `main` after changes have been validated in dev and staging.

```bash
# Merge your PR to main, then:
git checkout main
git pull

# Tag and push
git tag prod-v1.5.0 -m "Release prod-v1.5.0"
git push origin prod-v1.5.0
```

The production CI/CD workflow detects the tag, waits for manual approval in the `prod-approval` GitHub environment, then runs `terraform apply`.

### Version numbering

We use [Semantic Versioning](https://semver.org/):

| Change | Version bump |
|--------|-------------|
| Breaking changes (resource recreation, removed outputs) | MAJOR |
| New features, new modules, new optional variables | MINOR |
| Bug fixes, security patches, documentation | PATCH |

The same version is applied to all three environment tags:
- `dev-v1.5.0`
- `staging-v1.5.0`
- `prod-v1.5.0`
