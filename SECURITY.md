# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in this repository, please **do not open a public GitHub issue**. Instead, report it privately:

- **Email:** donfurline@gmail.com
- **Subject line:** `[SECURITY] aws-terraform-infrastructure — <brief description>`

Please include:
- A description of the vulnerability and its potential impact
- Steps to reproduce or a proof-of-concept
- Any suggested remediation if known

You can expect an acknowledgement within 48 hours and a resolution or update within 7 days.

---

## Scope

This repository contains Terraform modules and CI/CD pipeline configuration. Security issues relevant to this project include:

- Insecure default variable values in modules (e.g. overly permissive IAM policies, open security groups)
- Hardcoded secrets or credentials in any file
- CI/CD pipeline vulnerabilities (e.g. script injection, insecure use of GitHub Actions inputs)
- Missing or misconfigured encryption, logging, or access controls in module defaults

Out of scope:
- Vulnerabilities in third-party providers or actions (report those upstream)
- Issues that only affect non-default, explicitly documented insecure configurations

---

## Security Design Principles

This repository is designed with the following controls by default:

| Control | Implementation |
|---------|---------------|
| Encryption at rest | All S3 buckets and EBS volumes use customer-managed KMS keys |
| Encryption in transit | S3 bucket policy denies non-TLS requests; ALB redirects HTTP→HTTPS |
| Least-privilege IAM | Explicit trust policies; no wildcard resource in inline policies |
| Instance metadata | IMDSv2 enforced on all EC2 instances |
| No public EC2 | Instances launch in private subnets |
| Secret scanning | Gitleaks runs on every push via GitHub Actions |
| Static analysis | Checkov and TFLint run on every pull request |
