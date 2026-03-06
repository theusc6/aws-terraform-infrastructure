# Terraform Demo Environment — Makefile
# Usage: make <target> ENV=<dev|staging|prod>
#
# Prerequisites:
#   - Terraform >= 0.14 installed
#   - AWS CLI configured (or OIDC role assumed)
#   - ENV variable set (defaults to dev)

ENV ?= dev
TF_DIR := environments/$(ENV)
TF  := terraform -chdir=$(TF_DIR)

.PHONY: help init validate fmt plan apply destroy lint security-scan bootstrap

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "  ENV defaults to 'dev'. Override with: make <target> ENV=staging"

bootstrap: ## Bootstrap S3 backend and DynamoDB lock table (run once per account)
	@bash scripts/setup-backend.sh

init: ## Initialise Terraform for the selected environment
	$(TF) init -backend-config="key=$(ENV)/terraform.tfstate"

validate: init ## Validate Terraform configuration
	$(TF) validate

fmt: ## Format all Terraform files
	terraform fmt -recursive

fmt-check: ## Check formatting without modifying files
	terraform fmt -check -recursive

plan: init ## Generate and display an execution plan
	$(TF) plan -out=$(TF_DIR)/plan.tfplan

apply: init ## Apply the last plan (or auto-approve if no plan file)
	@if [ -f $(TF_DIR)/plan.tfplan ]; then \
		$(TF) apply $(TF_DIR)/plan.tfplan; \
	else \
		$(TF) apply -auto-approve; \
	fi

destroy: init ## Destroy all resources in the selected environment (use with caution!)
	@echo "⚠️  WARNING: This will destroy ALL resources in the '$(ENV)' environment."
	@read -p "Type the environment name to confirm: " confirm; \
		[ "$$confirm" = "$(ENV)" ] || (echo "Aborted." && exit 1)
	$(TF) destroy -auto-approve

lint: ## Run TFLint against the selected environment
	@which tflint > /dev/null || (echo "tflint not found — install from https://github.com/terraform-linters/tflint" && exit 1)
	tflint --init
	cd $(TF_DIR) && tflint

security-scan: ## Run Checkov security scan against the selected environment
	@which checkov > /dev/null || pip install checkov
	checkov -d $(TF_DIR) --download-external-modules true --skip-check CKV_TF_1

output: init ## Print Terraform outputs for the selected environment
	$(TF) output

clean: ## Remove local Terraform artefacts (.terraform dirs, plan files)
	find . -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null; true
	find . -name "*.tfplan" -type f -delete
	find . -name "plan_output.txt" -type f -delete
	find . -name "apply_output.txt" -type f -delete
	@echo "Cleaned local Terraform artefacts."
