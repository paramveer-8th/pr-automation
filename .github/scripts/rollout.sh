#!/usr/bin/env bash
# Adds Jira secrets + the PR Guard caller workflow to all your (non-fork, non-archived) repos.
# Usage:  ./rollout.sh <github-username> [--dry-run]
# Needs:  gh CLI logged in (gh auth login) with repo + workflow scopes.
set -euo pipefail

OWNER="${1:?usage: ./rollout.sh <github-username> [--dry-run]}"
DRY="${2:-}"
STUB_PATH=".github/workflows/pr-guard.yml"
STUB_FILE="$(dirname "$0")/../caller-stub/pr-guard.yml"

read -rp  "Jira base URL (https://xxx.atlassian.net): " JIRA_BASE_URL
read -rp  "Jira email: " JIRA_EMAIL
read -rsp "Jira API token: " JIRA_API_TOKEN; echo

CONTENT=$(sed "s/YOUR_GITHUB_USERNAME/$OWNER/" "$STUB_FILE" | base64 | tr -d '\n')

gh repo list "$OWNER" --limit 500 --no-archived --source --json nameWithOwner -q '.[].nameWithOwner' |
while read -r R; do
  [[ "$R" == "$OWNER/.github" || "$R" == "$OWNER/pr-automation" ]] && continue
  echo "→ $R"
  [[ "$DRY" == "--dry-run" ]] && continue

  gh secret set JIRA_BASE_URL  -R "$R" -b "$JIRA_BASE_URL"
  gh secret set JIRA_EMAIL     -R "$R" -b "$JIRA_EMAIL"
  gh secret set JIRA_API_TOKEN -R "$R" -b "$JIRA_API_TOKEN"

  if gh api "repos/$R/contents/$STUB_PATH" >/dev/null 2>&1; then
    echo "   workflow already present, skipping"
  else
    gh api -X PUT "repos/$R/contents/$STUB_PATH" \
      -f message="ci: add PR Guard (branch naming, PR template, Jira sync)" \
      -f content="$CONTENT" >/dev/null && echo "   workflow added"
  fi
done