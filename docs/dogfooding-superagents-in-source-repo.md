# Dogfooding Superagents In Its Own Source Repo

This guide defines a safe dogfooding workflow for developing Superagents while using Superagents + Claude in parallel.

## Goal

Allow contributors to validate real workflows without polluting the source repository or creating recursive execution loops.

## Core Guardrails

1. Keep one workspace for source edits and one separate workspace for agent execution.
2. Treat generated agent artifacts as local runtime output, not source files for this repo.
3. Keep watch/build scopes pointed at committed source paths only.
4. Verify guardrails before and after a dogfooding run.

## Recommended Two-Workspace Setup

Run this from your local machine and adjust paths as needed:

```bash
# 1) Source workspace (where you edit Superagents itself)
git clone git@github.com:peakweb-team/superagents.git ~/dev/superagents-src

# 2) Sandbox workspace (where Claude executes tasks)
git clone git@github.com:peakweb-team/superagents.git ~/dev/superagents-dogfood
```

Use the source workspace to install/update your user-level Claude bundle:

```bash
cd ~/dev/superagents-src
./scripts/install.sh --tool claude-code --no-interactive
```

Run day-to-day Claude execution in the sandbox workspace:

```bash
cd ~/dev/superagents-dogfood
# Activate superagents skills in Claude and run issue/task prompts here.
```

## In-Repo Dogfooding (When You Intentionally Use Source Repo Directly)

If you intentionally run Claude inside the source repo, apply these rules:

1. Run `./scripts/check-dogfooding-guardrails.sh` before starting.
2. Keep active task scope explicit (single issue, explicit paths, no broad autorewrite prompts).
3. Avoid recursive watch loops by excluding runtime folders:
   - `.claude/`
   - `.agency/`
   - `.codex/`
4. Re-run `./scripts/check-dogfooding-guardrails.sh` after the session.
5. Before committing, inspect untracked files and only stage intentional source changes.

## Do / Don't

Do:

- Keep source changes in tracked directories (`agents/`, `skills/`, `docs/`, `scripts/`, `tests/`).
- Use dedicated issue branches and clean commit boundaries.
- Run existing repo checks before opening a PR.

Don't:

- Commit generated runtime artifacts from `.claude/`, `.agency/`, or `.codex/`.
- Use wildcard watch scopes that include local runtime output roots.
- Mix long-lived dogfooding output with source history.

## Validation Checklist

Run:

```bash
./scripts/check-dogfooding-guardrails.sh
./tests/test-doc-link-integrity.sh
./tests/test-install-smoke.sh
```

Expected result: all commands exit with status `0`.
