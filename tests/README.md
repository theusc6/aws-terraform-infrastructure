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

The tests in this directory are **unit tests using mock providers**. They validate that:
- Variable constraints are enforced correctly
- Resources are configured with expected security properties
- Outputs are wired to the correct resource attributes
- Conditional logic (e.g. "only create HTTPS listener when certificate_arn is set") works

Integration tests (which create real AWS resources) are not committed because they require
live credentials and incur cost. The patterns below serve as templates.

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
| `full_stack_integration.tftest.hcl` | `environments/dev` (all modules) | Integration (mock) |

## Adding new tests

1. Create a `.tftest.hcl` file next to the module's `main.tf` (or in this directory for cross-module tests).
2. Use `mock_provider "aws"` for unit tests to avoid real API calls.
3. Use `run` blocks with `command = plan` to validate configuration without applying.
4. Add `assert` blocks to check specific attribute values and conditions.

See the [Terraform test documentation](https://developer.hashicorp.com/terraform/language/tests)
for the full syntax reference.
