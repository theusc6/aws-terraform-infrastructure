## Summary

<!-- 2-3 bullet points describing what changed and why -->
-
-

## Type of change

- [ ] Bug fix
- [ ] New feature / module
- [ ] Enhancement to existing module
- [ ] Security hardening
- [ ] Documentation
- [ ] CI/CD pipeline change
- [ ] Refactor (no behaviour change)

## Changes

<!-- List the modules, environments, or files changed -->

## Pre-merge checklist

### Code quality
- [ ] `make fmt` — all files formatted (`terraform fmt -recursive`)
- [ ] `make validate ENV=dev` — no validation errors
- [ ] `make plan ENV=dev` — plan reviewed; no unexpected resource recreation
- [ ] `make lint ENV=dev` — TFLint passes
- [ ] `make security-scan ENV=dev` — Checkov passes (or suppressions documented with justification)
- [ ] `make test` — all module unit tests pass

### Infrastructure safety
- [ ] Plan output reviewed for `forces replacement` — any recreation is intentional and acceptable
- [ ] No sensitive values (account IDs, secrets, ARNs) hardcoded in `.tf` files
- [ ] `force_destroy`, `prevent_destroy`, `deletion_protection` set correctly for the target environment

### Documentation
- [ ] Module README updated if inputs, outputs, or behaviour changed
- [ ] CHANGELOG.md updated under `## [Unreleased]`
- [ ] New modules include a `README.md`, `versions.tf`, and at least one `.tftest.hcl` file

## Notes for reviewers

<!-- Anything that needs special attention, context on decisions made, or known trade-offs -->

## Related issues / PRs

<!-- Closes #<issue> -->
