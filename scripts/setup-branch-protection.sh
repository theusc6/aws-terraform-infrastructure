#!/usr/bin/env bash
# setup-branch-protection.sh — Configure branch protection rules on main via GitHub CLI.
# Run ONCE after creating the repository. Requires gh CLI authenticated with admin scope.
#
# Usage:
#   REPO=theusc6/aws-terraform-infrastructure bash scripts/setup-branch-protection.sh
#
# Requirements:
#   - gh CLI installed and authenticated: gh auth login
#   - Token must have admin:repo_hook and repo scopes

set -euo pipefail

REPO="${REPO:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"

echo "==> Configuring branch protection on main for ${REPO}"

gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  "/repos/${REPO}/branches/main/protection" \
  --input - <<'EOF'
{
  "required_status_checks": {
    "strict": true,
    "contexts": [
      "Module Tests Passed",
      "Plan (dev)",
      "Checkov Security Scan (dev)",
      "TFLint (dev)",
      "Gitleaks Secret Scan"
    ]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": true,
    "required_approving_review_count": 1,
    "require_last_push_approval": true
  },
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": false,
  "required_conversation_resolution": true,
  "lock_branch": false,
  "allow_fork_syncing": false
}
EOF

echo "==> Branch protection configured on main."
echo ""
echo "Required status checks:"
echo "  - Module Tests Passed"
echo "  - Plan (dev)"
echo "  - Checkov Security Scan (dev)"
echo "  - TFLint (dev)"
echo "  - Gitleaks Secret Scan"
echo ""
echo "Rules applied:"
echo "  - 1 required approving review"
echo "  - Code owner review required (CODEOWNERS)"
echo "  - Dismiss stale reviews on new commits"
echo "  - Require last push approval (prevents self-approval)"
echo "  - Linear history (no merge commits)"
echo "  - No force pushes"
echo "  - Admins are NOT exempt (enforce_admins: true)"
echo "  - All conversations must be resolved before merge"
