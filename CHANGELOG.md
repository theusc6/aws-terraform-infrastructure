# Changelog

All notable changes to this project are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added
- Full documentation suite: root README, CONTRIBUTING guide, and per-module READMEs for all nine modules.
- `modules/alb` — Application Load Balancer module with HTTP→HTTPS redirect, configurable SSL policy, deregistration delay, and deletion protection.
- `modules/kms` — Customer-managed KMS key module with automatic annual rotation, least-privilege default key policy, and multi-region support.
- `modules/monitoring` — CloudWatch alarms (CPU warning/critical, EC2 status checks, ALB 5xx errors, unhealthy hosts, p99 response time) backed by an SNS topic.
- `CONTRIBUTING.md` — Full contribution guide covering setup, code standards, module design principles, commit conventions, and the PR process.

### Changed
- `modules/compute` — Enforced IMDSv2 (`http_tokens = required`, hop limit = 1) on all launch templates; pinned ASG to specific launch template version to prevent unplanned rolling refreshes.
- `modules/compute` — Health check type now automatically switches to `ELB` when `target_group_arns` is non-empty.
- `modules/storage` — Added HTTPS-only bucket policy (`DenyNonTLSRequests`), `bucket_key_enabled = true` to reduce KMS API costs, and optional server access logging.
- `modules/networking/vpc-module` — Added VPC Flow Logs (CloudWatch) with configurable retention; enabled by default.
- `modules/networking/security-group-module` — Added `ingress_sg_rules` for security-group-sourced rules, separating CIDR-based and SG-based ingress.
- `environments/prod` — One NAT Gateway per AZ for full high availability; 90-day flow log retention; KMS deletion window extended to 30 days; tighter CPU alarm thresholds (60% warning, 80% critical); ALB deletion protection enabled; HTTPS required.
- `environments/staging` — S3 lifecycle transitions to STANDARD_IA at 30 days; 60-day flow log retention; optional HTTPS/alarm_email variables.
- `.github/workflows/prod.yml` — Added `prod-approval` environment gate requiring manual reviewer sign-off before `terraform apply`.
- `.tflint.hcl` — Disabled `terraform_module_pinned_source` rule for local monorepo modules.
- `Makefile` — Added `fmt-check`, `output`, and `clean` targets; improved `destroy` with confirmation prompt.

### Fixed
- `modules/alb` — Fixed HTTP listener `default_action` to use two separate `dynamic` blocks (one for redirect, one for forward) — a single block with two actions causes a provider validation error.
- `modules/compute` — Fixed `desired_capacity` lifecycle ignore so external autoscaling policies (target-tracking, scheduled) are not overridden on every `terraform apply`.
- `modules/storage` — Fixed lifecycle configuration `depends_on` ordering to prevent `NoSuchLifecycleConfiguration` errors when versioning and lifecycle are modified in the same plan.
- `modules/networking/vpc-module` — Fixed private route table count to be driven by `nat_gateway_count` rather than subnet count, preventing orphaned route tables when NAT is disabled.

---

## [1.0.0] — 2026-03-06

### Added
- Initial repository structure with `environments/dev`, `environments/staging`, `environments/prod`.
- `modules/compute` — EC2 launch template and Auto Scaling Group.
- `modules/networking/vpc-module` — VPC, public/private subnets, Internet Gateway, NAT Gateways, route tables.
- `modules/networking/security-group-module` — Dynamic security group with CIDR and SG-source ingress rules.
- `modules/networking/vpc-endpoint-module` — Gateway and Interface VPC endpoints.
- `modules/iam` — IAM role with managed policy attachments, inline policies, and optional instance profile.
- `modules/storage` — S3 bucket with versioning and KMS encryption.
- `scripts/setup-backend.sh` — One-time bootstrap script for S3 + DynamoDB remote state backend.
- `.github/workflows/dev.yml`, `staging.yml`, `prod.yml` — CI/CD pipelines with plan on PR and apply on tag.
- `.github/workflows/changelog.yml` — Automatic CHANGELOG generation on merge to main.
- `Makefile` — Developer shortcuts for init, validate, fmt, plan, apply, destroy, lint, security-scan.
- `.tflint.hcl` — TFLint configuration with AWS plugin enabled.
- `.gitignore` — Excludes state files, `.terraform` directories, plan outputs, and secrets.

[Unreleased]: https://github.com/<org>/aws-terraform-infrastructure/compare/prod-v1.0.0...HEAD
[1.0.0]: https://github.com/<org>/aws-terraform-infrastructure/releases/tag/prod-v1.0.0
