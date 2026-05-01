---
name: superagents-devcontainer
description: Manage a running or stopped Superagents devcontainer — rebuild after config changes, stop running containers, extend an existing container with a new package or tool, or refresh the Superagents install in place without a rebuild.
disable-model-invocation: false
argument-hint: "[rebuild | stop | extend <package> | update]"
---

# Superagents Devcontainer Management

Use this skill when you need to manage the lifecycle of a Superagents devcontainer:

- **Rebuild** — after changing `devcontainer.json`, `Dockerfile`, or `post-create-superagents.sh`
- **Stop** — shut down a running container (specific project or all Superagents instances)
- **Extend** — add a package or tool to a running container without a full rebuild
- **Update without rebuild** — refresh `~/.claude/` from a Superagents ref in place when only `agents/`, `skills/`, `docs/`, or `scripts/` changed

---

## CLI Helpers (Recommended Entry Points)

The `superagents-devcontainer-bootstrap` skill installs three small host-side
helper scripts at the **project root** during scaffold. These are the
recommended way to drive the devcontainer lifecycle from a CLI-first workflow
(no VS Code required):

| Helper | Action | Wraps |
|---|---|---|
| `./dc-build` | Force a clean rebuild | `devcontainer up --workspace-folder . --remove-existing-container` |
| `./dc-up` | Launch (cached, idempotent) | `devcontainer up --workspace-folder .` |
| `./dc-shell` | Enter the running container with zsh | `devcontainer exec --workspace-folder . zsh` |

Run all three from the **project root on the host** (not inside the container).
Each helper:

- Verifies `devcontainer` is on `PATH` and bails with an install hint
  (`npm install -g @devcontainers/cli`) when missing.
- Refuses to run inside a container (using `/.dockerenv` and `DEVCONTAINER`
  heuristics) — they are host-side wrappers only.
- For `./dc-shell`: also checks that `zsh` is available inside the container
  before invoking it.

If the helpers are missing from your project (e.g. it was scaffolded before
they shipped), re-run `skills/devcontainer-bootstrap/templates/scaffold-devcontainer.sh`
to install them. The scaffold is idempotent: existing helpers are skipped
rather than overwritten, so operator-modified versions are preserved.

The explicit `devcontainer …` commands in the sections below still work and
are kept for operators not using the helpers.

---

## 1. Rebuild

### When to Use

Rebuild any time you change:

- `.devcontainer/devcontainer.json`
- `.devcontainer/Dockerfile`
- `.devcontainer/post-create-superagents.sh`

### Prerequisites

Either:
- VS Code with the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) installed, **or**
- The `@devcontainers/cli` npm package: `npm install -g @devcontainers/cli`

### Commands

**VS Code (host):**

1. Open the Command Palette (`Cmd+Shift+P` on macOS, `Ctrl+Shift+P` on Linux/Windows).
2. Run `Dev Containers: Rebuild Container`.
3. To discard the cached image layers as well, run `Dev Containers: Rebuild Without Cache` instead.

**CLI (host terminal):**

The recommended path is the helper scripts installed at the project root by
the bootstrap scaffold:

```bash
# Standard rebuild (uses cached layers where possible)
./dc-up                          # (devcontainer up --workspace-folder .)

# Force a clean rebuild (no cached layers)
./dc-build                       # (devcontainer up --workspace-folder . --remove-existing-container)
```

If you prefer the explicit invocations, or your project predates the helpers:

```bash
devcontainer up --workspace-folder .
devcontainer up --workspace-folder . --remove-existing-container
```

Run all of these from the **project root on the host** (not inside the container).

### Prerequisite Check

Before rebuilding, confirm that either VS Code with the Dev Containers extension is active, or `devcontainer` is on your PATH:

```bash
devcontainer --version
```

If the command is not found, install the CLI:

```bash
npm install -g @devcontainers/cli
```

---

## 2. Stop / Shutdown

### Where to Run

All stop commands run on the **host Mac terminal** (not inside the container).

### Stop a Specific Project's Container

```bash
docker ps --filter "label=devcontainer.local_folder=<absolute-path-to-project>" -q \
  | xargs -r docker stop
```

Replace `<absolute-path-to-project>` with the absolute path of the project whose container you want to stop, for example `/Users/yourname/dev/my-project`.

To find the path label for a running container:

```bash
docker inspect <container-id> --format '{{ index .Config.Labels "devcontainer.local_folder" }}'
```

### Stop All Superagents Devcontainers

```bash
docker ps --filter "label=devcontainer.local_folder" -q | xargs -r docker stop
```

This stops every container that carries the `devcontainer.local_folder` label, which is set by VS Code's Dev Containers extension on all devcontainers it manages.

### Important: Detach VS Code First

Containers managed by VS Code **auto-restart** when VS Code re-attaches to them. Before stopping:

1. In VS Code, open the Command Palette and run `Dev Containers: Close Remote Connection`.
2. Confirm the status bar no longer shows the container name.
3. Then run the stop command above.

---

## 3. Extend (Add a Package or Tool)

### One-Off Install (not persisted across rebuilds)

Run inside the container terminal:

```bash
sudo apt-get install -y <package>
```

This installs the package in the running container immediately. The change is **lost on the next rebuild**.

Use this approach for temporary exploration or when you are not yet sure if the package should be permanent.

### Permanent Install (persisted across rebuilds)

1. On the **host**, open `.devcontainer/post-create-superagents.sh`.
2. Add the package under the appropriate `apt-get install` block, following the existing grouping comments in the file.
3. Commit the change.
4. Rebuild the container (see [Rebuild](#1-rebuild) above) so the new package is baked into the post-create step.

#### Example — adding `jq` permanently

```bash
# Inside post-create-superagents.sh, locate the apt install block:
sudo apt-get install -y \
  git \
  curl \
  jq        # ← add here
```

Then rebuild:

```bash
./dc-build                       # (devcontainer up --workspace-folder . --remove-existing-container)
```

### Where to Run

| Step | Location |
|------|----------|
| One-off `apt-get install` | Inside the running container |
| Edit `post-create-superagents.sh` | Host (your editor) |
| `devcontainer up` rebuild | Host terminal |

---

## 4. Update Without Rebuild

For Superagents updates that affect only `agents/`, `skills/`, `docs/`, or `scripts/` (i.e. content the installer copies into `~/.claude/`), you can refresh in-place without a container rebuild.

### When to Use

The `superagents-upgrade` skill detects this case automatically and surfaces it as Phase 5b. Use the manual command below when:

- You know upstream has changes you want to pull in
- The four scaffold files (`.devcontainer/Dockerfile`, `.devcontainer/devcontainer.json`, `.devcontainer/post-create-superagents.sh`, `.devcontainer/scaffold-devcontainer.sh`) are unchanged between your project and the target ref
- A full rebuild would be wasteful (it redoes Playwright, OS packages, and the npm/pnpm caches)

### Command

Run inside the running container terminal (not on the host):

```bash
.devcontainer/upgrade-superagents-in-container.sh
```

To pin a specific ref (defaults to `main`):

```bash
SUPERAGENTS_REF=v0.2.0 .devcontainer/upgrade-superagents-in-container.sh
```

The script:

1. Verifies it is running inside a devcontainer (refuses to clobber a host install).
2. Shallow-clones the configured `SUPERAGENTS_REPO` at `SUPERAGENTS_REF` into a temp dir.
3. Runs the scaffold guard against the four scaffold files.
4. If the guard passes, invokes `scripts/install.sh --tool claude-code --no-interactive` and reports what changed under `~/.claude/`.
5. Cleans up the temp clone on exit.

### Where to Run

| Step | Location |
|------|----------|
| `.devcontainer/upgrade-superagents-in-container.sh` | Inside the running container |

### When the Script Bails

If any of the four scaffold files differ between the project and the target ref, the script exits non-zero with a "rebuild required" message and does **not** modify `~/.claude/`. In that case, follow the [Rebuild](#1-rebuild) section above. The script's exit codes are:

| Exit code | Meaning |
|-----------|---------|
| 0 | Success — install completed (or `--dry-run` guard passed) |
| 1 | General failure (bad arguments, missing project `.devcontainer/`, install.sh failed) |
| 2 | Scaffold guard fired — host-side rebuild required |
| 3 | Not running inside a devcontainer (host guard tripped) |

### Restarting Claude

If a `SKILL.md` you currently have open in the running claude session was updated, restart claude (or re-open the skill) so the new content is picked up. The script prints a reminder when changes are detected.

---

## Reference

- Anthropic devcontainer docs: `https://code.claude.com/docs/en/devcontainer`
- Dev Containers CLI: `https://github.com/devcontainers/cli`
- VS Code Dev Containers extension: `https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers`
- For initial devcontainer setup, see the `superagents-devcontainer-bootstrap` skill.
- To review and apply Superagents framework upgrades against a project bundle (including detection of devcontainer scaffold drift that would require a rebuild), see the `superagents-upgrade` skill.
