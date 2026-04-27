---
name: superagents-devcontainer-bootstrap
description: Scaffold an isolated Claude Code devcontainer from Anthropic's reference and install Superagents at user scope inside the container.
disable-model-invocation: true
argument-hint: "[optional-project-path]"
---

# Superagents Devcontainer Bootstrap

Use this skill when a team needs to run Claude Code with `--dangerously-skip-permissions` in an isolated containerized environment.

## Safety Boundary

- Always use this only for trusted repositories.
- Container isolation reduces host risk, but it does not prevent in-container credential exfiltration.
- Never recommend host-level `--dangerously-skip-permissions` for normal workflows.

## Inputs

- Optional project path. If omitted, use the current working directory.
- Optional env overrides:
  - `ANTHROPIC_DEVCONTAINER_BASE_URL` (default: Anthropic reference `.devcontainer` on `main`)
  - `SUPERAGENTS_REPO` (default: `https://github.com/peakweb-team/pw-agency-agents.git`)
  - `SUPERAGENTS_REF` (default: `main`)

## Workflow

1. Resolve the target project path.
2. Ensure a `.devcontainer/` directory exists in that project.
3. Copy the template scripts from this skill bundle into the target `.devcontainer/` directory:
   - `scaffold-devcontainer.sh`
   - `post-create-superagents.sh`
   - `smoke-test-superagents.sh`
4. Run `scaffold-devcontainer.sh` from the project root.
5. Confirm `.devcontainer/devcontainer.json` has `postCreateCommand` set to `.devcontainer/post-create-superagents.sh`.
6. Ask the user to reopen the repository in the container.
7. After container startup, run `.devcontainer/smoke-test-superagents.sh` in the container terminal.
8. Summarize what was generated and any follow-up required.

## Template Location

After installation, this skill's templates are expected at:

- `~/.claude/skills/superagents-devcontainer-bootstrap/templates/`

## Success Criteria

- `.devcontainer/` exists and is based on Anthropic's reference assets (`devcontainer.json`, `Dockerfile`) with superagents-specific patches applied.
- Generated `devcontainer.json` does not require firewall bootstrap (`postStartCommand`/`waitFor` coupling removed, no `NET_ADMIN`/`NET_RAW` capability additions).
- npm and pnpm cache storage is configured to use named Docker volumes mounted at `/home/node/.npm-cache` and `/home/node/.pnpm-store`.
- `postCreateCommand` installs Superagents with user-level scope inside the container.
- Playwright (Chromium) is installed during post-create so browser automation works without additional setup (`npx playwright --version` succeeds inside the container).
- Smoke test passes after container creation.

## Reference

- Anthropic devcontainer docs: `https://code.claude.com/docs/en/devcontainer`
- Anthropic reference source: `https://github.com/anthropics/claude-code/tree/main/.devcontainer`
