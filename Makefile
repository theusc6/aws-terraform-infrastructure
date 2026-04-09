# Terraform Demo Environment — Makefile
# Usage: make <target> ENV=<dev|staging|prod>
#
# Prerequisites:
#   - Terraform >= 1.3.0 installed
#   - AWS CLI configured (or OIDC role assumed via CI)
#   - ENV variable set (defaults to dev)

ENV ?= dev
TF_DIR := environments/$(ENV)
TF  := terraform -chdir=$(TF_DIR)

.PHONY: help bootstrap init validate fmt fmt-check plan apply destroy \
        lint security-scan test lock output clean

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "  ENV defaults to 'dev'. Override with: make <target> ENV=staging"

# ── Backend ───────────────────────────────────────────────────────────────────

bootstrap: ## Bootstrap S3 backend and DynamoDB lock table (run once per account)
	@bash scripts/setup-backend.sh

# ── Core workflow ─────────────────────────────────────────────────────────────

init: ## Initialise Terraform for the selected environment
	$(TF) init -backend-config="key=$(ENV)/terraform.tfstate"

validate: init ## Validate Terraform configuration
	$(TF) validate

fmt: ## Format all Terraform files recursively
	terraform fmt -recursive

fmt-check: ## Check formatting without modifying files (same check as CI)
	terraform fmt -check -recursive

plan: init ## Generate and display an execution plan
	$(TF) plan -out=$(TF_DIR)/plan.tfplan

apply: init ## Apply the last plan (or auto-approve if no plan file)
	@if [ -f $(TF_DIR)/plan.tfplan ]; then \
		$(TF) apply $(TF_DIR)/plan.tfplan; \
	else \
		$(TF) apply -auto-approve; \
	fi

destroy: init ## Destroy all resources in the selected environment (confirmation required)
	@echo "WARNING: This will destroy ALL resources in the '$(ENV)' environment."
	@read -p "Type the environment name to confirm: " confirm; \
		[ "$$confirm" = "$(ENV)" ] || (echo "Aborted." && exit 1)
	$(TF) destroy -auto-approve

# ── Quality checks ────────────────────────────────────────────────────────────

lint: ## Run TFLint against the selected environment
	@which tflint > /dev/null || (echo "tflint not found — install from https://github.com/terraform-linters/tflint" && exit 1)
	tflint --init
	tflint --chdir=$(TF_DIR)

security-scan: ## Run Checkov security scan against the selected environment
	@which checkov > /dev/null || pip install checkov
	checkov --directory $(TF_DIR) --skip-check CKV_TF_1 --compact --quiet

lock: ## Regenerate .terraform.lock.hcl for all environments (run after adding/changing providers)
	@echo "Locking providers for all environments (linux_amd64, darwin_amd64, darwin_arm64)..."
	@for env in dev staging prod; do \
		echo "==> $$env"; \
		terraform -chdir=environments/$$env providers lock \
			-platform=linux_amd64 \
			-platform=darwin_amd64 \
			-platform=darwin_arm64; \
	done
	@echo "Done. Commit the updated .terraform.lock.hcl files."

test: ## Run Terraform native unit tests for all modules (no AWS credentials required)
	@echo "Running module tests..."
	@for module in \
		modules/kms \
		modules/storage \
		modules/alb \
		modules/networking/vpc-module; do \
		echo ""; \
		echo "==> $$module"; \
		terraform -chdir=$$module init -backend=false > /dev/null 2>&1; \
		terraform -chdir=$$module test -verbose || exit 1; \
	done
	@echo ""
	@echo "All module tests passed."

# ── Utilities ─────────────────────────────────────────────────────────────────

output: init ## Print Terraform outputs for the selected environment
	$(TF) output

clean: ## Remove local Terraform artefacts (.terraform dirs, plan files)
	find . -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null; true
	find . -name "*.tfplan" -type f -delete
	find . -name "plan_output.txt" -type f -delete
	find . -name "apply_output.txt" -type f -delete
	@echo "Cleaned local Terraform artefacts."
