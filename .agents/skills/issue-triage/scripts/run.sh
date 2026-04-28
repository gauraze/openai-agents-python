#!/usr/bin/env bash
# Issue Triage Skill - Automatically categorizes and labels GitHub issues
# Usage: ./run.sh <issue_number> [repo]

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
REPO="${REPO:-${2:-openai/openai-agents-python}}"
ISSUE_NUMBER="${1:-}"
GH_TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"

# Label definitions
BUG_LABELS=("bug" "needs-reproduction")
FEATURE_LABELS=("enhancement" "feature-request")
DOCS_LABELS=("documentation")
QUESTION_LABELS=("question" "needs-more-info")
PRIORITY_HIGH_LABELS=("priority: high")
PRIORITY_LOW_LABELS=("priority: low")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log()  { echo "[issue-triage] $*" >&2; }
err()  { echo "[issue-triage] ERROR: $*" >&2; exit 1; }

require_cmd() {
  command -v "$1" &>/dev/null || err "Required command not found: $1"
}

require_cmd gh
require_cmd jq

[[ -z "$ISSUE_NUMBER" ]] && err "Usage: $0 <issue_number> [repo]"
[[ -z "$GH_TOKEN" ]]     && err "GH_TOKEN / GITHUB_TOKEN must be set"

export GH_TOKEN

# ---------------------------------------------------------------------------
# Fetch issue data
# ---------------------------------------------------------------------------
log "Fetching issue #${ISSUE_NUMBER} from ${REPO}..."

ISSUE_JSON=$(gh api "repos/${REPO}/issues/${ISSUE_NUMBER}" 2>/dev/null) \
  || err "Failed to fetch issue #${ISSUE_NUMBER}"

TITLE=$(echo "$ISSUE_JSON"  | jq -r '.title // ""')
BODY=$(echo "$ISSUE_JSON"   | jq -r '.body  // ""')
STATE=$(echo "$ISSUE_JSON"  | jq -r '.state // "open"')
AUTHOR=$(echo "$ISSUE_JSON" | jq -r '.user.login // ""')
EXISTING_LABELS=$(echo "$ISSUE_JSON" | jq -r '[.labels[].name] | join(",")')

log "Title  : $TITLE"
log "Author : $AUTHOR"
log "State  : $STATE"
log "Labels : ${EXISTING_LABELS:-<none>}"

[[ "$STATE" != "open" ]] && { log "Issue is not open — skipping."; exit 0; }

# ---------------------------------------------------------------------------
# Classify issue
# ---------------------------------------------------------------------------
COMBINED=$(echo "${TITLE} ${BODY}" | tr '[:upper:]' '[:lower:]')

declare -a LABELS_TO_ADD=()

# Bug detection
if echo "$COMBINED" | grep -qE '\b(bug|error|exception|crash|broken|fail|traceback|stacktrace|regression)\b'; then
  log "Detected: bug"
  LABELS_TO_ADD+=("${BUG_LABELS[@]}")
fi

# Feature request detection
if echo "$COMBINED" | grep -qE '\b(feature|enhancement|request|suggestion|add support|would be nice|please add|implement)\b'; then
  log "Detected: feature request"
  LABELS_TO_ADD+=("${FEATURE_LABELS[@]}")
fi

# Documentation detection
if echo "$COMBINED" | grep -qE '\b(docs|documentation|readme|typo|spelling|example|tutorial|guide)\b'; then
  log "Detected: documentation"
  LABELS_TO_ADD+=("${DOCS_LABELS[@]}")
fi

# Question detection
if echo "$COMBINED" | grep -qE '\b(how (do|to|can)|question|help|confused|unclear|not sure|what is|why does)\b'; then
  log "Detected: question"
  LABELS_TO_ADD+=("${QUESTION_LABELS[@]}")
fi

# Priority: high — security / data-loss keywords
if echo "$COMBINED" | grep -qE '\b(security|vulnerability|cve|data loss|critical|urgent|production|outage)\b'; then
  log "Detected: high priority"
  LABELS_TO_ADD+=("${PRIORITY_HIGH_LABELS[@]}")
fi

# Default to 'needs-more-info' when body is very short
BODY_LEN=$(echo "$BODY" | wc -c)
if [[ "$BODY_LEN" -lt 80 && ${#LABELS_TO_ADD[@]} -eq 0 ]]; then
  log "Body too short — requesting more info"
  LABELS_TO_ADD+=("needs-more-info")
fi

# De-duplicate and filter already-applied labels
declare -a NEW_LABELS=()
for label in "${LABELS_TO_ADD[@]}"; do
  if ! echo "$EXISTING_LABELS" | grep -qF "$label"; then
    NEW_LABELS+=("$label")
  fi
done

# ---------------------------------------------------------------------------
# Apply labels
# ---------------------------------------------------------------------------
if [[ ${#NEW_LABELS[@]} -eq 0 ]]; then
  log "No new labels to apply."
else
  # Build JSON array
  LABEL_JSON=$(printf '%s\n' "${NEW_LABELS[@]}" | jq -R . | jq -sc .)
  log "Applying labels: ${NEW_LABELS[*]}"

  gh api --method POST \
    "repos/${REPO}/issues/${ISSUE_NUMBER}/labels" \
    --input - <<< "{\"labels\": ${LABEL_JSON}}" \
    > /dev/null \
    && log "Labels applied successfully." \
    || err "Failed to apply labels."
fi

# ---------------------------------------------------------------------------
# Post triage comment
# ---------------------------------------------------------------------------
if [[ ${#NEW_LABELS[@]} -gt 0 ]]; then
  LABEL_LIST=$(printf '`%s` ' "${NEW_LABELS[@]}")
  COMMENT="Thanks for opening this issue, @${AUTHOR}! 🤖\n\nThis issue has been automatically triaged and labelled: ${LABEL_LIST}\n\nA maintainer will review it shortly."

  log "Posting triage comment..."
  gh api --method POST \
    "repos/${REPO}/issues/${ISSUE_NUMBER}/comments" \
    -f body="$(printf '%b' "$COMMENT")" \
    > /dev/null \
    && log "Comment posted." \
    || log "Warning: failed to post comment (non-fatal)."
fi

log "Triage complete for issue #${ISSUE_NUMBER}."
