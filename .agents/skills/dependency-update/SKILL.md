# Dependency Update Skill

This skill automates the process of checking for outdated dependencies, evaluating compatibility, and generating update PRs with appropriate changelogs and test validation.

## Overview

The dependency update skill monitors project dependencies (Python packages via `pyproject.toml`/`requirements.txt`) and:

1. Identifies outdated packages using `pip list --outdated` or `uv pip list --outdated`
2. Evaluates semantic versioning changes (major/minor/patch)
3. Checks for known breaking changes in changelogs
4. Runs the test suite to validate compatibility
5. Generates a structured PR with dependency diff and release notes

## Trigger Conditions

- Scheduled: Weekly on Mondays at 09:00 UTC
- Manual: Via workflow dispatch with optional `package` filter
- Event: When a security advisory is published for a dependency

## Inputs

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `update_type` | string | No | `patch` | One of `patch`, `minor`, `major`, `all` |
| `package` | string | No | `""` | Specific package to update (empty = all) |
| `dry_run` | boolean | No | `false` | Preview changes without creating PR |
| `auto_merge` | boolean | No | `false` | Auto-merge if all checks pass (patch only) |

## Outputs

- Pull request with:
  - Updated dependency files
  - Summary of changes per package
  - Links to relevant changelogs/release notes
  - Test results summary
- Comment on any existing dependency issues referencing the update

## Behavior

### Update Strategy

- **Patch updates** (`x.y.Z`): Auto-propose, can auto-merge if tests pass
- **Minor updates** (`x.Y.z`): Propose with changelog summary, require human review
- **Major updates** (`X.y.z`): Propose with migration guide notes, require explicit approval

### Conflict Resolution

If multiple packages have conflicting version requirements, the skill will:
1. Report the conflict in the PR description
2. Suggest the highest compatible version set
3. Flag packages that cannot be updated due to conflicts

### Security Updates

Packages flagged by `pip-audit` or GitHub's dependency graph as having CVEs are:
- Prioritized regardless of `update_type` setting
- Labeled with `security` in the generated PR
- Assigned to the security review team

## Configuration

Place a `.agents/skills/dependency-update/config.yaml` in the repository root to customize behavior:

```yaml
dependency_update:
  ignore_packages:
    - some-pinned-package
  pin_packages:
    - critical-package==1.2.3
  update_type: minor
  auto_merge_patch: true
  reviewers:
    - team/backend
```

## Example PR Description

```
## Dependency Updates

### Patch Updates (auto-eligible)
| Package | From | To | Changelog |
|---------|------|----|----------|
| httpx | 0.27.0 | 0.27.2 | [link](https://github.com/encode/httpx/releases) |

### Minor Updates (review required)
| Package | From | To | Changelog |
|---------|------|----|----------|
| pydantic | 2.7.0 | 2.9.0 | [link](https://docs.pydantic.dev/changelog) |

### Test Results
✅ All 247 tests passed
⚠️  2 deprecation warnings (see details)
```

## Script

See [`scripts/run.sh`](scripts/run.sh) for the full implementation.
