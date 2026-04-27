#!/usr/bin/env bash
# examples-auto-run/scripts/run.sh
# Automatically discovers and runs all examples in the repository,
# capturing output and reporting pass/fail status.

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
EXAMPLES_DIR="${REPO_ROOT}/examples"
LOG_DIR="${REPO_ROOT}/.agents/skills/examples-auto-run/logs"
TIMEOUT_SECONDS=${TIMEOUT_SECONDS:-60}
PYTHON_BIN=${PYTHON_BIN:-python}
PASSED=0
FAILED=0
SKIPPED=0
FAILED_EXAMPLES=()

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log()  { echo "[examples-auto-run] $*"; }
warn() { echo "[examples-auto-run] WARN: $*" >&2; }
err()  { echo "[examples-auto-run] ERROR: $*" >&2; }

require_cmd() {
  if ! command -v "$1" &>/dev/null; then
    err "Required command not found: $1"
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
require_cmd "$PYTHON_BIN"
require_cmd timeout

if [[ ! -d "$EXAMPLES_DIR" ]]; then
  err "Examples directory not found: $EXAMPLES_DIR"
  exit 1
fi

mkdir -p "$LOG_DIR"

# ---------------------------------------------------------------------------
# Determine which examples to run
# ---------------------------------------------------------------------------
# Respect an optional allowlist file; otherwise run everything.
ALLOWLIST_FILE="${REPO_ROOT}/.agents/skills/examples-auto-run/allowlist.txt"

if [[ -f "$ALLOWLIST_FILE" ]]; then
  log "Using allowlist: $ALLOWLIST_FILE"
  mapfile -t EXAMPLE_FILES < <(grep -v '^#' "$ALLOWLIST_FILE" | grep -v '^[[:space:]]*$' | sed "s|^|${EXAMPLES_DIR}/|")
else
  log "No allowlist found — discovering all *.py files under $EXAMPLES_DIR"
  mapfile -t EXAMPLE_FILES < <(find "$EXAMPLES_DIR" -name '*.py' | sort)
fi

if [[ ${#EXAMPLE_FILES[@]} -eq 0 ]]; then
  warn "No example files found. Nothing to run."
  exit 0
fi

log "Found ${#EXAMPLE_FILES[@]} example(s) to run."

# ---------------------------------------------------------------------------
# Run each example
# ---------------------------------------------------------------------------
for example in "${EXAMPLE_FILES[@]}"; do
  if [[ ! -f "$example" ]]; then
    warn "File not found, skipping: $example"
    ((SKIPPED++)) || true
    continue
  fi

  rel="${example#${REPO_ROOT}/}"
  log_file="${LOG_DIR}/$(echo "$rel" | tr '/' '_').log"

  log "Running: $rel"

  # Check for a skip marker inside the file
  if grep -q 'SKIP_AUTO_RUN' "$example"; then
    log "  → Skipped (SKIP_AUTO_RUN marker found)"
    ((SKIPPED++)) || true
    continue
  fi

  set +e
  timeout "$TIMEOUT_SECONDS" "$PYTHON_BIN" "$example" \
    > "$log_file" 2>&1
  exit_code=$?
  set -e

  if [[ $exit_code -eq 0 ]]; then
    log "  → PASSED"
    ((PASSED++)) || true
  elif [[ $exit_code -eq 124 ]]; then
    err "  → TIMEOUT (>${TIMEOUT_SECONDS}s): $rel"
    ((FAILED++)) || true
    FAILED_EXAMPLES+=("$rel (timeout)")
  else
    err "  → FAILED (exit $exit_code): $rel"
    err "    Log: $log_file"
    ((FAILED++)) || true
    FAILED_EXAMPLES+=("$rel (exit $exit_code)")
  fi
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
log "==============================="
log " Results"
log "==============================="
log "  Passed:  $PASSED"
log "  Failed:  $FAILED"
log "  Skipped: $SKIPPED"
log "  Total:   ${#EXAMPLE_FILES[@]}"

if [[ ${#FAILED_EXAMPLES[@]} -gt 0 ]]; then
  log ""
  log "Failed examples:"
  for f in "${FAILED_EXAMPLES[@]}"; do
    log "  - $f"
  done
fi

log "Logs written to: $LOG_DIR"

if [[ $FAILED -gt 0 ]]; then
  exit 1
fi
