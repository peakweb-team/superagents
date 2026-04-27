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
4. **Look up (or register) the project's designated port** — see [Port Designation](#port-designation) below.
5. Run `scaffold-devcontainer.sh` from the project root.
6. Confirm `.devcontainer/devcontainer.json` has `postCreateCommand` set to `.devcontainer/post-create-superagents.sh` and `forwardPorts` set to the designated port.
7. Ask the user to reopen the repository in the container.
8. After container startup, run `.devcontainer/smoke-test-superagents.sh` in the container terminal.
9. Summarize what was generated and any follow-up required.

## Template Location

After installation, this skill's templates are expected at:

- `~/.claude/skills/superagents-devcontainer-bootstrap/templates/`

## Port Designation

When multiple projects run simultaneously each needs a distinct dev server port to avoid collisions.
A static registry at `skills/devcontainer-bootstrap/ports.yaml` in the superagents repo maps repo names to port numbers.

### Looking up a port

`scaffold-devcontainer.sh` reads the registry automatically.  It resolves the repo name from
`basename $(git rev-parse --show-toplevel)` and looks up the matching port.  Two files are written:

- `devcontainer.json` — `"forwardPorts": [<port>]` is set to the designated port.
- `.devcontainer/.project-port` — contains just the port number so that scripts and skills can read
  it without hardcoding (e.g. `PORT=$(cat .devcontainer/.project-port)`).

### Registering a new project

1. Open `skills/devcontainer-bootstrap/ports.yaml` in the superagents repo.
2. Pick an **unused** port in the range **3100–3999**.  (3000–3099 is reserved for ad-hoc /
   unregistered use; do not use those.)
3. Add an entry under `projects:`:
   ```yaml
   projects:
     superagents: 3100
     my-new-project: 3101   # ← new entry
   ```
4. Verify no other entry uses the same port number — duplicate ports are a registry authoring error
   that will cause port-forwarding conflicts between simultaneously running devcontainers.
5. Commit the change to the superagents repo and re-run `scaffold-devcontainer.sh` in the target
   project.

### Error: repo not found in registry

If `scaffold-devcontainer.sh` exits with:
```
ERROR: repo '<name>' not found in port registry.
       Add an entry to skills/devcontainer-bootstrap/ports.yaml:
         <name>: <port>   # pick an unused port in 3100-3999
```
follow the registration steps above, then re-run the scaffold.

## Success Criteria

- `.devcontainer/` exists and is based on Anthropic's reference assets (`devcontainer.json`, `Dockerfile`) with superagents-specific patches applied.
- Generated `devcontainer.json` does not require firewall bootstrap (`postStartCommand`/`waitFor` coupling removed, no `NET_ADMIN`/`NET_RAW` capability additions).
- npm and pnpm cache storage is configured to use named Docker volumes mounted at `/home/node/.npm-cache` and `/home/node/.pnpm-store`.
- `postCreateCommand` installs Superagents with user-level scope inside the container.
- `devcontainer.json` contains `"forwardPorts": [<port>]` set to the project's designated port.
- `.devcontainer/.project-port` contains the designated port number.
- Playwright (Chromium) is installed during post-create so browser automation works without additional setup (`npx playwright --version` succeeds inside the container).
- Smoke test passes after container creation.

## Container Management

For day-to-day container operations after the initial bootstrap — rebuilding after a config change, stopping a running container, or installing a bespoke package — see the `superagents-devcontainer` skill.

## Reference

- Anthropic devcontainer docs: `https://code.claude.com/docs/en/devcontainer`
- Anthropic reference source: `https://github.com/anthropics/claude-code/tree/main/.devcontainer`
