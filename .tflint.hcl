# TFLint configuration
# Docs: https://github.com/terraform-linters/tflint

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "aws" {
  enabled = true
  version = "0.27.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# ── Rule overrides ────────────────────────────────────────────────────────────

# terraform_module_pinned_source (CKV_TF_1 / module_source_version):
# Disabled because this repository uses local module paths (../../modules/...)
# in a monorepo pattern. Local source references cannot and should not be pinned
# to a version tag — the monorepo itself is the version control boundary.
# External registry modules (if added in future) must be version-pinned.
rule "terraform_module_pinned_source" {
  enabled = false
}
