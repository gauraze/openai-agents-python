#!/usr/bin/env bash
# Changelog Generator Skill
# Automatically generates or updates CHANGELOG.md based on git history and conventional commits

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────
CHANGELOG_FILE="${CHANGELOG_FILE:-CHANGELOG.md}"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo '.')"
SINCE_TAG="${SINCE_TAG:-}"
UNRELEASED_HEADER="## [Unreleased]"
DATE=$(date +%Y-%m-%d)

# Conventional commit types to include and their section headers
declare -A COMMIT_TYPES
COMMIT_TYPES=(
  ["feat"]="### Features"
  ["fix"]="### Bug Fixes"
  ["perf"]="### Performance Improvements"
  ["refactor"]="### Refactoring"
  ["docs"]="### Documentation"
  ["test"]="### Tests"
  ["chore"]="### Chores"
  ["ci"]="### CI/CD"
  ["build"]="### Build"
)

# ─── Helpers ──────────────────────────────────────────────────────────────────
log()  { echo "[changelog-generator] $*" >&2; }
err()  { echo "[changelog-generator] ERROR: $*" >&2; exit 1; }

require_git() {
  git rev-parse --git-dir > /dev/null 2>&1 || err "Not inside a git repository."
}

get_latest_tag() {
  git describe --tags --abbrev=0 2>/dev/null || echo ""
}

get_commits_since() {
  local since="$1"
  if [[ -n "$since" ]]; then
    git log "${since}..HEAD" --pretty=format:"%H%x09%s%x09%b%x09%an" --no-merges
  else
    git log --pretty=format:"%H%x09%s%x09%b%x09%an" --no-merges
  fi
}

parse_conventional_commit() {
  # Outputs: type scope breaking subject
  local subject="$1"
  # Match: type(scope)!: subject  OR  type!: subject  OR  type: subject
  if [[ "$subject" =~ ^([a-zA-Z]+)(\(([^)]+)\))?(!)?: ]]; then
    local type="${BASH_REMATCH[1]}"
    local scope="${BASH_REMATCH[3]}"
    local breaking="${BASH_REMATCH[4]}"
    local message="${subject#*: }"
    echo "${type}|${scope}|${breaking}|${message}"
  else
    echo "other|||${subject}"
  fi
}

# ─── Build changelog entry ────────────────────────────────────────────────────
build_changelog_section() {
  local since_ref="$1"
  local -A sections
  local breaking_changes=()

  log "Collecting commits since: ${since_ref:-'beginning'}"

  while IFS=$'\t' read -r hash subject body author; do
    [[ -z "$hash" ]] && continue

    IFS='|' read -r type scope breaking message <<< "$(parse_conventional_commit "$subject")"

    # Detect breaking changes from footer token
    if echo "$body" | grep -q "^BREAKING CHANGE:"; then
      breaking="!"
    fi

    local short_hash="${hash:0:7}"
    local scope_label=""
    [[ -n "$scope" ]] && scope_label="(**${scope}**) "

    local line="- ${scope_label}${message} ([\`${short_hash}\`](../../commit/${hash}))"

    if [[ "$breaking" == "!" ]]; then
      breaking_changes+=("$line")
    fi

    if [[ -v "COMMIT_TYPES[$type]" ]]; then
      sections["$type"]+="${line}"$'\n'
    fi
  done < <(get_commits_since "$since_ref")

  # Output breaking changes first
  if [[ ${#breaking_changes[@]} -gt 0 ]]; then
    echo "### ⚠ Breaking Changes"
    for entry in "${breaking_changes[@]}"; do
      echo "$entry"
    done
    echo ""
  fi

  # Output each section in defined order
  for type in feat fix perf refactor docs test chore ci build; do
    if [[ -v "sections[$type]" && -n "${sections[$type]}" ]]; then
      echo "${COMMIT_TYPES[$type]}"
      echo -n "${sections[$type]}"
      echo ""
    fi
  done
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
  require_git
  cd "$REPO_ROOT"

  local latest_tag
  latest_tag="${SINCE_TAG:-$(get_latest_tag)}"

  log "Generating changelog entries since tag: '${latest_tag:-none}'"

  local new_section
  new_section="$(build_changelog_section "$latest_tag")"

  if [[ -z "$(echo "$new_section" | tr -d '[:space:]')" ]]; then
    log "No conventional commits found. Changelog not updated."
    exit 0
  fi

  local entry_header="${UNRELEASED_HEADER}"
  local full_entry
  full_entry="$(printf '%s\n\n> Generated on %s\n\n%s' "$entry_header" "$DATE" "$new_section")"

  if [[ -f "$CHANGELOG_FILE" ]]; then
    # Insert after the top-level header (first # heading) or prepend
    if grep -q "^# " "$CHANGELOG_FILE"; then
      # Insert new section after the first heading line
      awk -v entry="$full_entry" '
        /^# / && !inserted { print; print ""; print entry; inserted=1; next }
        { print }
      ' "$CHANGELOG_FILE" > "${CHANGELOG_FILE}.tmp"
      mv "${CHANGELOG_FILE}.tmp" "$CHANGELOG_FILE"
    else
      # Prepend to file
      { echo "$full_entry"; echo ""; cat "$CHANGELOG_FILE"; } > "${CHANGELOG_FILE}.tmp"
      mv "${CHANGELOG_FILE}.tmp" "$CHANGELOG_FILE"
    fi
  else
    log "Creating new $CHANGELOG_FILE"
    {
      echo "# Changelog"
      echo ""
      echo "All notable changes to this project will be documented in this file."
      echo ""
      echo "$full_entry"
    } > "$CHANGELOG_FILE"
  fi

  log "Changelog updated: $CHANGELOG_FILE"
}

main "$@"
