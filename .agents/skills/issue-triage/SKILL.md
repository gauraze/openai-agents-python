# Issue Triage Skill

Automatically triages new GitHub issues by analyzing content, applying labels, assigning priority, and routing to appropriate team members.

## Overview

This skill monitors incoming GitHub issues and performs automated triage actions to help maintainers manage the issue backlog efficiently. It uses AI to understand issue content and apply consistent categorization.

## Capabilities

- **Label Assignment**: Automatically applies relevant labels based on issue content (bug, enhancement, documentation, question, etc.)
- **Priority Classification**: Assigns priority levels (P0-critical, P1-high, P2-medium, P3-low) based on impact and urgency signals
- **Duplicate Detection**: Identifies potential duplicate issues and links them
- **Component Tagging**: Routes issues to the correct component area (agents, tools, streaming, tracing, etc.)
- **Stale Detection**: Flags issues that need more information from the reporter
- **Response Templates**: Posts appropriate initial responses to guide reporters

## Trigger Conditions

- New issue opened
- Issue reopened
- Issue edited (re-triage if content changes significantly)

## Configuration

The skill reads from `.agents/skills/issue-triage/config.yaml` for:
- Label taxonomy
- Priority keywords
- Component keyword mappings
- Auto-close conditions
- Team member routing rules

## Labels Applied

### Type Labels
- `bug` — Something isn't working
- `enhancement` — New feature or request
- `documentation` — Improvements or additions to documentation
- `question` — Further information is requested
- `performance` — Performance-related issues
- `security` — Security vulnerability or concern

### Priority Labels
- `P0-critical` — Production blocker, needs immediate attention
- `P1-high` — Important issue affecting many users
- `P2-medium` — Standard priority
- `P3-low` — Nice to have, low urgency

### Component Labels
- `component:agents` — Core agent runtime
- `component:tools` — Tool/function calling
- `component:streaming` — Streaming responses
- `component:tracing` — Tracing and observability
- `component:guardrails` — Input/output guardrails
- `component:handoffs` — Agent handoff mechanism

### Status Labels
- `needs-info` — Waiting for more information from reporter
- `needs-reproduction` — Cannot reproduce without more details
- `good-first-issue` — Suitable for new contributors
- `help-wanted` — Extra attention is needed

## Usage

```bash
bash .agents/skills/issue-triage/scripts/run.sh <issue_number>
```

Or triggered automatically via GitHub Actions on `issues` events.

## Outputs

- Applied labels on the GitHub issue
- Initial triage comment with summary and next steps
- Optional assignment to team member or project board
- Duplicate issue links if found
