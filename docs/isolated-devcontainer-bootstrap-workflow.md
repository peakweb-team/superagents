# Isolated Devcontainer Bootstrap Workflow

This document defines the workflow introduced for issue `#83`:

- [#83 Feature: Superagents skill for isolated Anthropic dev container + user-level packaging](https://github.com/peakweb-team/pw-agency-agents/issues/83)

## Goal

Provide a repeatable and safer path for users who need `claude --dangerously-skip-permissions` by running inside an isolated Anthropic-based devcontainer and installing Superagents at user scope inside that container.

## Scope

- Reusable skill: `superagents-devcontainer-bootstrap`
- Skill install path: `~/.claude/skills/superagents-devcontainer-bootstrap/`
- Template assets:
  - `templates/scaffold-devcontainer.sh`
  - `templates/post-create-superagents.sh`
  - `templates/smoke-test-superagents.sh`

## Safety Guidance

- Use this workflow only with trusted repositories.
- Isolation reduces host risk but does not eliminate in-container credential exfiltration risk.
- Do not recommend host-level use of `--dangerously-skip-permissions` as a default workflow.

## Workflow

1. Install Superagents for Claude Code:

```bash
./scripts/install.sh --tool claude-code
```

2. In a target repository, copy the template scripts from the installed skill bundle into `.devcontainer/`.

3. Run scaffold script from the target repository root:

```bash
.devcontainer/scaffold-devcontainer.sh
```

4. Reopen the repository in the container.

5. After container startup, run smoke test inside container:

```bash
.devcontainer/smoke-test-superagents.sh
```

6. If the smoke test passes, the container has user-level Superagents installed and is ready for trusted-repo workflows that may require `--dangerously-skip-permissions`.

## Anthropic Baseline Dependency

The scaffold script pulls baseline files from Anthropic reference source:

- `devcontainer.json`
- `Dockerfile`

Then applies Superagents-specific container patches:

- Removes firewall bootstrap wiring from `devcontainer.json` (`postStartCommand`, `waitFor: "postStartCommand"` when present, and `NET_ADMIN` / `NET_RAW` capability flags in `runArgs`).
- Adds named Docker volumes for package caches:
  - `source=superagents-npm-cache,target=/home/node/.npm-cache,type=volume`
  - `source=superagents-pnpm-store,target=/home/node/.pnpm-store,type=volume`
- Sets package manager cache env vars in `containerEnv`:
  - `npm_config_cache=/home/node/.npm-cache`
  - `npm_config_store_dir=/home/node/.pnpm-store`
- Updates Dockerfile global Claude Code install line to also run `npm cache clean --force` to keep image layers smaller.

Default source URL:

- `https://raw.githubusercontent.com/anthropics/claude-code/main/.devcontainer`

Override with `ANTHROPIC_DEVCONTAINER_BASE_URL` when pinning to a specific fork or revision mirror.
