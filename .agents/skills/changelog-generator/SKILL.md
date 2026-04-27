# Changelog Generator Skill

Automatically generates and maintains a CHANGELOG.md file based on git commit history, pull requests, and semantic versioning conventions.

## Overview

This skill analyzes git commit history following the [Conventional Commits](https://www.conventionalcommits.org/) specification and produces a well-formatted changelog grouped by version and change type.

## Capabilities

- Parse conventional commit messages (`feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `perf:`, `test:`, `ci:`, `build:`)
- Group changes by semantic version (major, minor, patch)
- Detect breaking changes from `BREAKING CHANGE` footer or `!` suffix
- Pull PR titles and descriptions from GitHub API for richer context
- Update existing CHANGELOG.md or create a new one
- Support for unreleased changes section
- Tag-based version boundary detection

## Usage

### Trigger Conditions

- On new git tag creation (e.g., `v1.2.3`)
- On merge to `main` branch (updates `[Unreleased]` section)
- Manual invocation via workflow dispatch

### Inputs

| Parameter | Description | Default |
|-----------|-------------|----------|
| `from_tag` | Starting git tag for changelog range | Previous tag |
| `to_tag` | Ending git tag for changelog range | `HEAD` |
| `output_file` | Path to the changelog file | `CHANGELOG.md` |
| `include_prs` | Whether to enrich with PR data from GitHub | `true` |

### Outputs

- Updated `CHANGELOG.md` committed to the repository
- Summary of changes added to the changelog

## Changelog Format

Follows [Keep a Changelog](https://keepachangelog.com/) format:

```markdown
## [1.2.0] - 2024-01-15

### Added
- feat: new streaming response support (#123)

### Fixed
- fix: handle timeout errors gracefully (#124)

### Breaking Changes
- feat!: rename `run_sync` to `run_blocking` (#125)
```

## Configuration

Place a `.changelog.yaml` config at the repository root to customize behavior:

```yaml
exclude_types:
  - chore
  - ci
  - test
group_order:
  - Added
  - Changed
  - Fixed
  - Removed
  - Security
```

## Script

See `scripts/run.sh` for the full implementation.
