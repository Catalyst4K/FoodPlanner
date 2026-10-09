#!/usr/bin/env bash
# Applies this repo's GitHub security settings. Idempotent: safe to re-run.
#
#   scripts/github-repo-security.sh                 # everything except branch protection
#   PROTECT_MAIN=1 scripts/github-repo-security.sh  # also protect main
#
# Requires an authenticated `gh` with admin rights on the repo.
# Enable PROTECT_MAIN only once the required checks below have reported at
# least once, otherwise every merge is blocked waiting for a check that never runs.
set -euo pipefail

REPO="${REPO:-Catalyst4K/FoodPlanner}"
BRANCH="${BRANCH:-main}"
REQUIRED_CHECKS="${REQUIRED_CHECKS:-build-test}" # comma-separated; add lint, rules once those jobs exist
DESCRIPTION="Plan meals around what's already in your kitchen: recipes, pantry and shopping list in SwiftUI + Firebase."
HOMEPAGE="${HOMEPAGE:-}" # set to the GitHub Pages privacy page once it exists (plan 5.3)
TOPICS=(ios swift swiftui firebase firestore swift-concurrency portfolio)

echo "Configuring $REPO"

# Repo settings and metadata
args=(-X PATCH "repos/$REPO"
  -f description="$DESCRIPTION"
  -F delete_branch_on_merge=true
  -F has_wiki=false
  -F has_projects=false
  -F "security_and_analysis[secret_scanning][status]=enabled"
  -F "security_and_analysis[secret_scanning_push_protection][status]=enabled")
[ -n "$HOMEPAGE" ] && args+=(-f homepage="$HOMEPAGE")
gh api "${args[@]}" >/dev/null

# Topics
topic_args=()
for t in "${TOPICS[@]}"; do topic_args+=(-f "names[]=$t"); done
gh api -X PUT "repos/$REPO/topics" "${topic_args[@]}" >/dev/null

# Dependabot alerts + automated security fixes, private vulnerability reporting
gh api -X PUT "repos/$REPO/vulnerability-alerts" >/dev/null
gh api -X PUT "repos/$REPO/automated-security-fixes" >/dev/null
gh api -X PUT "repos/$REPO/private-vulnerability-reporting" >/dev/null

# Branch protection (opt in)
if [ "${PROTECT_MAIN:-0}" = "1" ]; then
  contexts=$(printf '%s' "$REQUIRED_CHECKS" | jq -R 'split(",")')
  jq -n --argjson contexts "$contexts" '{
    required_status_checks: {strict: true, contexts: $contexts},
    enforce_admins: true,
    required_pull_request_reviews: {required_approving_review_count: 0},
    restrictions: null,
    allow_force_pushes: false,
    allow_deletions: false
  }' | gh api -X PUT "repos/$REPO/branches/$BRANCH/protection" --input - >/dev/null
  echo "Branch protection applied to $BRANCH (required checks: $REQUIRED_CHECKS)"
else
  echo "Skipping branch protection (set PROTECT_MAIN=1 once required checks have reported)"
fi

echo
echo "Resulting state:"
gh api "repos/$REPO" -q '{description, homepage, delete_branch_on_merge, has_wiki, has_projects, topics, security_and_analysis}'
gh api "repos/$REPO/private-vulnerability-reporting" -q '"private vulnerability reporting: \(.enabled)"'
gh api "repos/$REPO/branches/$BRANCH/protection" -q '{required_status_checks: .required_status_checks.contexts, enforce_admins: .enforce_admins.enabled}' 2>/dev/null \
  || echo "$BRANCH is not protected"
