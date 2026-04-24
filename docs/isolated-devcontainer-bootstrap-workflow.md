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

- Removes `init-firewall.sh` usage and firewall bootstrap wiring from startup (`postStartCommand`, `waitFor: "postStartCommand"` when present, and `NET_ADMIN` / `NET_RAW` capability flags in `runArgs`).
- Adds named Docker volumes for package caches:
  - `source=superagents-npm-cache,target=/home/node/.npm-cache,type=volume`
  - `source=superagents-pnpm-store,target=/home/node/.pnpm-store,type=volume`
- Sets package manager cache env vars in `containerEnv`:
  - `npm_config_cache=/home/node/.npm-cache`
  - `npm_config_store_dir=/home/node/.pnpm-store`
- Forwards host-managed secrets into `containerEnv` using `localEnv`:
  - `GH_TOKEN=${localEnv:GH_TOKEN}`
  - `ANTHROPIC_API_KEY=${localEnv:ANTHROPIC_API_KEY}`
  - `VERCEL_TOKEN=${localEnv:VERCEL_TOKEN}`
- Rewrites Dockerfile base image from `node:20` to `node:24` while preserving any tag suffix.
- Updates Dockerfile global Claude Code install line to append `npm cache clean --force` if not already present, keeping image layers smaller without duplicating commands.
- Rewrites `apt-get update` to `apt-get -o APT::Sandbox::User=root update` and inserts a Dockerfile comment documenting the reason, to avoid intermittent Debian repo GPG signature failures caused by APT sandbox keyring access in container builds.

## Host Secret Onboarding Checklist

Before reopening in container, create host-side environment variables (never commit raw secrets into repo files or Dockerfiles).

GitHub token setup:

1. Create a fine-grained PAT at `https://github.com/settings/tokens`.
2. Typical repo permissions:
   - Contents: read/write
   - Pull requests: read/write
   - Workflows: read/write (only if needed)
   - Metadata: read
3. Export on host shell startup (for example in `~/.zshrc` or `~/.zshenv`):

```bash
export GH_TOKEN=ghp_xxx
```

Optional host-side exports for other tools:

```bash
export ANTHROPIC_API_KEY=...
export VERCEL_TOKEN=...
```

After setting host vars, reopen/rebuild the devcontainer. `gh` reads `GH_TOKEN` automatically, so repeated in-container `gh auth login` should not be required.

APT diagnosis shortcut used for this patch:

- If all Debian repos fail at once with `At least one invalid signature was encountered` / `repository is not signed` and manual `gpgv` succeeds, suspect APT sandbox keyring access.
- If only one repo fails, suspect a stale or missing key for that specific repo.

Framing correction:

- What may look like a clock-skew-style signature issue in this scenario is actually an APT sandbox keyring access failure. Signature material can still be valid while APT's sandboxed verifier cannot read the keyring.

Default source URL:

- `https://raw.githubusercontent.com/anthropics/claude-code/main/.devcontainer`

Override with `ANTHROPIC_DEVCONTAINER_BASE_URL` when pinning to a specific fork or revision mirror.
