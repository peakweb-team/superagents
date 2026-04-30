# Workflow Conventions

This document defines conventions that contributors and operators must follow when working with issues and pull requests in this repository.

## Issue Dependency Declaration

### Standard

When an issue cannot be started until another issue is resolved, the blocked issue body must include a `## Blocked by` section. Each blocker is listed as:

```text
#N — one-line reason
```

where `N` is the issue number and the reason briefly explains why the dependency exists.

### Example

```markdown
## Blocked by

#119 — gh CLI upgrade required before this issue's automation can run correctly
```

Multiple blockers are listed as separate lines under the same section:

```markdown
## Blocked by

#119 — gh CLI upgrade required before automation can run correctly
#125 — port registry must exist before devcontainer scaffold can write forwardPorts
```

### GitHub linked-issue relationship

In addition to the body declaration, set the GitHub "blocked by" linked-issue relationship via the UI (issue sidebar → "Development" or "Linked issues") or via the `gh` CLI:

```bash
gh issue edit <blocked-issue-N> --add-label "" # placeholder — use the GitHub UI or GraphQL API to set the "blocked by" relationship
```

The body `## Blocked by` section is the machine-readable and human-readable source of truth. The GitHub linked-issue relationship is supplementary and improves discoverability in the project board.

### Stale blockers

When a blocker issue is resolved (merged or closed), remove or strike through its entry in the `## Blocked by` section and note the resolution:

```markdown
## Blocked by

~~#119 — gh CLI upgrade required before automation can run correctly~~ (resolved in #118)
```

Or remove the resolved entry entirely if no historical context is needed.

## Commit Message Convention

Follow the imperative mood, present tense for commit messages:

- `Add dependency declaration standard to workflow conventions`
- `Update superagents SKILL.md with blocker-check step`
- `Fix informal blocker language in issue bodies`

Keep the subject line under 72 characters. Include a body when the commit reason is not obvious from the subject alone.
