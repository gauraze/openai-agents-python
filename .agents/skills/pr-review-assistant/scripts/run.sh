#!/usr/bin/env bash
# PR Review Assistant Script
# Analyzes pull requests and provides structured review feedback
# covering code quality, test coverage, documentation, and breaking changes.

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# Required environment variables
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
PR_NUMBER="${PR_NUMBER:-}"
REPO="${REPO:-}"
OPENAI_API_KEY="${OPENAI_API_KEY:-}"
MODEL="${MODEL:-gpt-4o}"

# Optional tunables
MAX_DIFF_LINES="${MAX_DIFF_LINES:-2000}"
POST_COMMENT="${POST_COMMENT:-true}"
DRY_RUN="${DRY_RUN:-false}"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log()  { echo "[pr-review] $*" >&2; }
die()  { log "ERROR: $*"; exit 1; }

require_cmd() {
  command -v "$1" &>/dev/null || die "Required command not found: $1"
}

check_env() {
  [[ -n "${GITHUB_TOKEN}" ]] || die "GITHUB_TOKEN is not set"
  [[ -n "${PR_NUMBER}" ]]    || die "PR_NUMBER is not set"
  [[ -n "${REPO}" ]]         || die "REPO is not set (owner/repo)"
  [[ -n "${OPENAI_API_KEY}" ]] || die "OPENAI_API_KEY is not set"
}

gh_api() {
  local endpoint="$1"; shift
  curl -fsSL \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com${endpoint}" "$@"
}

# ---------------------------------------------------------------------------
# Fetch PR metadata and diff
# ---------------------------------------------------------------------------
fetch_pr_data() {
  log "Fetching PR #${PR_NUMBER} metadata from ${REPO} ..."
  PR_JSON="$(gh_api "/repos/${REPO}/pulls/${PR_NUMBER}")"
  PR_TITLE="$(echo "${PR_JSON}" | python3 -c "import sys,json; print(json.load(sys.stdin)['title'])")"
  PR_BODY="$(echo  "${PR_JSON}" | python3 -c "import sys,json; print(json.load(sys.stdin)['body'] or '')")"
  PR_BASE="$(echo  "${PR_JSON}" | python3 -c "import sys,json; print(json.load(sys.stdin)['base']['ref'])")"
  PR_HEAD="$(echo  "${PR_JSON}" | python3 -c "import sys,json; print(json.load(sys.stdin)['head']['ref'])")"
  log "PR: '${PR_TITLE}' (${PR_HEAD} -> ${PR_BASE})"
}

fetch_diff() {
  log "Fetching diff for PR #${PR_NUMBER} ..."
  DIFF="$(gh_api "/repos/${REPO}/pulls/${PR_NUMBER}" \
    -H "Accept: application/vnd.github.v3.diff" 2>/dev/null || true)"

  local line_count
  line_count="$(echo "${DIFF}" | wc -l)"
  log "Diff size: ${line_count} lines"

  if (( line_count > MAX_DIFF_LINES )); then
    log "Truncating diff to ${MAX_DIFF_LINES} lines (original: ${line_count})"
    DIFF="$(echo "${DIFF}" | head -n "${MAX_DIFF_LINES}")"
    DIFF+=$'\n\n[... diff truncated ...]'
  fi
}

# ---------------------------------------------------------------------------
# Build review prompt and call OpenAI
# ---------------------------------------------------------------------------
generate_review() {
  log "Generating review via OpenAI (model: ${MODEL}) ..."

  local system_prompt="You are an expert code reviewer for the openai-agents-python project. \
Provide a concise, actionable pull-request review. Structure your response with these sections:\n\
## Summary\n## Strengths\n## Issues (label each: [blocker] / [major] / [minor] / [nit])\n## Testing\n## Documentation\n## Verdict (Approve / Request Changes / Comment)"

  local user_prompt="PR Title: ${PR_TITLE}\n\nPR Description:\n${PR_BODY}\n\nDiff:\n\`\`\`diff\n${DIFF}\n\`\`\`"

  local payload
  payload="$(python3 - <<'PYEOF'
import json, os, sys

system = os.environ["SYSTEM_PROMPT"]
user   = os.environ["USER_PROMPT"]
model  = os.environ["MODEL"]

print(json.dumps({
    "model": model,
    "messages": [
        {"role": "system", "content": system},
        {"role": "user",   "content": user}
    ],
    "temperature": 0.2
}))
PYEOF
  )" SYSTEM_PROMPT="${system_prompt}" USER_PROMPT="${user_prompt}" MODEL="${MODEL}"

  REVIEW="$(curl -fsSL https://api.openai.com/v1/chat/completions \
    -H "Authorization: Bearer ${OPENAI_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "${payload}" \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['choices'][0]['message']['content'])")"

  log "Review generated (${#REVIEW} chars)"
}

# ---------------------------------------------------------------------------
# Post review comment to GitHub
# ---------------------------------------------------------------------------
post_comment() {
  if [[ "${DRY_RUN}" == "true" ]]; then
    log "[dry-run] Skipping GitHub comment post."
    echo "${REVIEW}"
    return
  fi

  if [[ "${POST_COMMENT}" != "true" ]]; then
    log "POST_COMMENT=false — printing review to stdout only."
    echo "${REVIEW}"
    return
  fi

  log "Posting review comment to PR #${PR_NUMBER} ..."
  local body
  body="$(python3 -c "import json,os; print(json.dumps({'body': os.environ['REVIEW']}))" REVIEW="${REVIEW}")"

  gh_api "/repos/${REPO}/issues/${PR_NUMBER}/comments" \
    -X POST \
    -H "Content-Type: application/json" \
    -d "${body}" > /dev/null

  log "Comment posted successfully."
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  require_cmd curl
  require_cmd python3
  check_env

  fetch_pr_data
  fetch_diff
  generate_review
  post_comment

  log "Done."
}

main "$@"
