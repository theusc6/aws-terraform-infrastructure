# Tests

This directory contains [Terraform native tests](https://developer.hashicorp.com/terraform/language/tests)
(introduced in Terraform 1.6). These tests run directly with `terraform test` — no external
frameworks required.

## Test strategy

Tests are divided into two categories:

| Category | What it tests | Requires AWS? |
|----------|---------------|---------------|
| Unit (mock) | Variable validation, output correctness, resource configuration | No |
| Integration | Actual AWS API calls, resource creation/destruction | Yes |

Unit tests live alongside each module (e.g. `modules/kms/kms_unit.tftest.hcl`). They use
**mock providers** and validate that:
- Variable constraints are enforced correctly
- Resources are configured with expected security properties
- Outputs are wired to the correct resource attributes
- Conditional logic (e.g. "only create HTTPS listener when certificate_arn is set") works

A **full-stack integration test** (`environments/dev/tests/full_stack_integration.tftest.hcl`)
plans the entire dev environment end-to-end with mock providers to verify cross-module wiring.
No AWS credentials required.

## Running tests

```bash
# Run all unit tests (no AWS credentials required)
terraform test

# Run tests for a specific module
terraform -chdir=modules/kms test
terraform -chdir=modules/alb test
terraform -chdir=modules/storage test

# Run a specific test file
terraform -chdir=modules/kms test -filter=tests/kms_unit.tftest.hcl

# Run with verbose output
terraform -chdir=modules/kms test -verbose
```

## Test files

| File | Module | Type |
|------|--------|------|
| `kms_unit.tftest.hcl` | `modules/kms` | Unit (mock) |
| `storage_unit.tftest.hcl` | `modules/storage` | Unit (mock) |
| `alb_unit.tftest.hcl` | `modules/alb` | Unit (mock) |
| `networking_unit.tftest.hcl` | `modules/networking/vpc-module` | Unit (mock) |
| `environments/dev/tests/full_stack_integration.tftest.hcl` | `environments/dev` (all modules) | Integration (mock) |

## Adding new tests

1. Create a `.tftest.hcl` file next to the module's `main.tf` (or in this directory for cross-module tests).
2. Use `mock_provider "aws"` for unit tests to avoid real API calls.
3. Use `run` blocks with `command = plan` to validate configuration without applying.
4. Add `assert` blocks to check specific attribute values and conditions.

See the [Terraform test documentation](https://developer.hashicorp.com/terraform/language/tests)
for the full syntax reference.
