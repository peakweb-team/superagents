---
name: superagents-workflow
description: Primary orchestration skill for the superagents repository. Handles issue-backed task execution, auto worktree isolation, PR delivery with CodeRabbit review, context-efficient solo agent operation, and devcontainer lifecycle management.
generated_by: skill-builder
generated_at: 2026-05-01T14:45:00Z
---

# Superagents Workflow

## Purpose

Orchestrate implementation work in the `superagents` repository from a GitHub Issue through to a merged pull request.

## Trigger Conditions

Invoke this skill when:
- Starting work on a GitHub Issue
- Beginning any implementation task that will produce a PR against `main`

## Work Intake

Work begins from a GitHub Issue. Before planning or writing anything:

1. Read the issue: `gh issue view <N>`
2. Extract acceptance criteria into an explicit checklist.
3. Note linked issues, related fragments, or CI contracts affected.
4. Confirm scope is understood before implementation starts.

Do not begin work from a freeform prompt if a relevant issue exists — open an issue first, then execute against it.

## Worktree Isolation

Default strategy: **auto**

Create or reuse a deterministic worktree for each issue:

```
git worktree add ../superagents-issue-<N> -b codex/issue-<N>-<slug>
```

- Do not overwrite or silently skip an existing worktree. Surface actionable remediation when path or branch conflicts arise.
- Per-task override is allowed. Resolution order: task-level override → `auto` default → `off` fallback.
- Operator may override to `off` for quick, low-risk edits (typo fixes, config nits).

## Team Sizing

Default: **solo**

A single Claude Code session handles discovery, implementation, review response, and validation.

Escalate to sub-agent or team execution when any of the following are true:
- Work spans more than two distinct domain areas simultaneously (e.g., CI infrastructure + agent schema + docs all requiring deep changes)
- Acceptance criteria are numerous and each requires independent verification
- Blast radius is high and an independent reviewer agent is warranted before opening a PR

For most issues in this repo — agent additions, doc updates, fragment additions, CI fixes — solo execution is correct.

## Delivery

### Branch and commit conventions

- Branch: `codex/issue-<N>-<short-slug>` (matches existing repo convention)
- Commits: short imperative subject line, no trailing period
- Scope each commit to one logical change

### Pre-PR validation

Run the relevant local validation commands before opening a PR:

| Change type | Command |
|---|---|
| Agent files | `./scripts/lint-agents.sh` |
| Fragment contracts / docs | `./tests/test-fragment-contract-validation.sh` |
| Doc link integrity | `./tests/test-doc-link-integrity.sh` |
| Dogfooding guardrails | `./tests/test-dogfooding-guardrails.sh` |
| Skill-builder runtime target | `./tests/test-skill-builder-runtime-target-contract.sh` |

Run only the commands relevant to the files changed.

### Opening a PR

1. Open a PR against `main` using the repo PR template (`.github/PULL_REQUEST_TEMPLATE.md`).
2. Fill all template sections: what the PR does, agent information (if applicable), checklist.
3. Link the PR to its issue with `Closes #N` in the body.

### CodeRabbit review

CodeRabbit is active on this repository (configured at the GitHub level — no local config file required).

Review sequencing:
1. Open the PR and wait for the CodeRabbit automated summary.
2. Address all actionable CodeRabbit comments before requesting human review.
3. Dismiss nitpicks (style, wording) with a brief explanation when they conflict with established repo conventions.
4. Request human review only after CodeRabbit pass is complete.
5. Do not merge until at least one human approval follows CodeRabbit review.

After addressing feedback, refresh the PR body to reflect the current scope if it changed during review.

## Context and Model Routing

This repository has a large agents + docs surface. Read efficiently:

- Use `find` and `grep` before loading full directories.
- Read only files relevant to the current issue scope.
- Deepen context only when acceptance criteria require cross-cutting understanding of agents/ and docs/ together.
- For planning and synthesis tasks, prefer stronger model capability.
- For mechanical tasks (formatting, schema validation, file moves): economy model tiers are sufficient.

Execution sequence: `discover` → `select` → `deepen` → `execute` → `verify`

Do not load the full `agents/` or `docs/` tree unless the issue scope explicitly requires changes across both.

## Devcontainer Management

This repository uses a Superagents devcontainer (`.devcontainer/`). For lifecycle operations, invoke the `superagents-devcontainer-bootstrap` skill. Key rules:

**When to suggest a rebuild** — proactively recommend a rebuild when any of these files change:
- `.devcontainer/devcontainer.json`
- `.devcontainer/Dockerfile`
- `.devcontainer/post-create-superagents.sh`

**Stopping a container** — use the Docker label filter for the superagents container rather than stopping all containers indiscriminately.

**Adding a package** — distinguish between a one-off in-container install (temporary, for experimentation) and a permanent change committed to `post-create-superagents.sh` (durable, for all contributors). Recommend the permanent path when the package is needed for ongoing development.

## Maintenance

When the installed Superagents framework has moved past this project's recorded `framework_release`, invoke `/superagents-upgrade` to review, apply, or feed back the delta. The upgrade skill compares this bundle against the installed framework, applies approved changes via the skill-builder, and can file upstream issues for any improvements you notice along the way.
