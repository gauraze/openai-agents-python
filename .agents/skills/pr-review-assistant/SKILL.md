# PR Review Assistant Skill

This skill automates pull request review assistance by analyzing code changes, checking for common issues, and providing structured feedback.

## Overview

The PR Review Assistant skill helps maintain code quality by:
- Analyzing diffs for potential bugs, style violations, and anti-patterns
- Checking test coverage for new code
- Verifying documentation is updated alongside code changes
- Summarizing changes in a human-readable format
- Flagging security concerns or performance regressions

## Usage

This skill is triggered on pull request events and produces a structured review comment.

### Inputs

| Variable | Description | Required |
|----------|-------------|----------|
| `PR_NUMBER` | The pull request number to review | Yes |
| `GITHUB_TOKEN` | Token with repo read and PR write access | Yes |
| `REPO_OWNER` | GitHub repository owner | Yes |
| `REPO_NAME` | GitHub repository name | Yes |
| `BASE_BRANCH` | Base branch to diff against (default: `main`) | No |
| `REVIEW_FOCUS` | Comma-separated focus areas: `security,performance,style,tests,docs` | No |

### Outputs

The skill posts a structured review comment to the pull request with:
- **Summary**: High-level description of what changed
- **Concerns**: Issues that should be addressed before merging
- **Suggestions**: Optional improvements
- **Checklist**: Automated checks (tests pass, docs updated, etc.)

## Configuration

Create a `.agents/skills/pr-review-assistant/config.yaml` to customize behavior:

```yaml
review:
  max_files: 50          # Skip review if PR touches more than this many files
  ignore_patterns:       # File patterns to exclude from review
    - "*.lock"
    - "*.generated.*"
    - "dist/**"
  focus_areas:
    - security
    - tests
    - docs
```

## Agent

This skill uses the `openai` agent defined in `agents/openai.yaml`.

## Script

Run the skill locally:

```bash
export PR_NUMBER=42
export GITHUB_TOKEN=ghp_...
export REPO_OWNER=my-org
export REPO_NAME=my-repo
bash .agents/skills/pr-review-assistant/scripts/run.sh
```

## Notes

- The skill respects `.gitignore` and will not flag issues in ignored files.
- Reviews are idempotent: re-running on the same PR updates the existing review comment rather than creating a new one.
- Large PRs (>50 files by default) will receive a summary-only review with a note to split the PR.
