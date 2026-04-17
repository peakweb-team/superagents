# Generated Skill Reference Scenarios

This directory contains concrete, repo-local generated-skill examples that follow the contracts in [`docs/generated-skill-layout.md`](../../docs/generated-skill-layout.md).

Each scenario includes both required output roots:

- execution-facing generated skills under `.claude/skills/superagents/`
- builder metadata under `.agency/skills/superagents/`

## Scenarios

### 1. GitHub-heavy with layered review and dual intake

Path: [`github-heavy-dual-intake-coderabbit/`](./github-heavy-dual-intake-coderabbit/)

Highlights:

- GitHub Issues as tracked-task system of record
- GitHub PR workflow with CodeRabbit layered input
- direct-brief intake kept active alongside tracked-task intake
- worktree strategy defaulted to `auto` with per-task override enabled

### 2. Jira-heavy with mixed GitHub delivery and dual intake

Path: [`jira-heavy-mixed-delivery/`](./jira-heavy-mixed-delivery/)

Highlights:

- Jira as primary task tracker
- GitHub pull requests as code-host review system of record
- direct-brief bootstrap supported for exploratory work while tracked-task flow remains primary
- worktree strategy defaulted to `manual` with per-task override enabled

### 3. Direct-brief vibe bootstrap (tracker optional)

Path: [`direct-brief-vibe-bootstrap/`](./direct-brief-vibe-bootstrap/)

Highlights:

- direct-brief as primary intake mode
- assumption capture and runtime guardrails emphasized
- tracked-task bindings intentionally unresolved/optional to keep integration boundary explicit
- worktree strategy defaulted to `off` with per-task override enabled

## Notes

- These artifacts are examples for documentation and review workflows.
- They are designed to be realistic and diffable, not placeholders.
- Capability bindings intentionally include warning/manual examples where coverage is partial.
