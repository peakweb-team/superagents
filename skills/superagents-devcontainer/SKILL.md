---
name: superagents-devcontainer
description: Manage a running or stopped Superagents devcontainer — rebuild after config changes, stop running containers, or extend an existing container with a new package or tool.
disable-model-invocation: false
argument-hint: "[rebuild | stop | extend <package>]"
---

# Superagents Devcontainer Management

Use this skill when you need to manage the lifecycle of a Superagents devcontainer:

- **Rebuild** — after changing `devcontainer.json`, `Dockerfile`, or `post-create-superagents.sh`
- **Stop** — shut down a running container (specific project or all Superagents instances)
- **Extend** — add a package or tool to a running container without a full rebuild

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

```bash
# Standard rebuild (uses cached layers where possible)
devcontainer up --workspace-folder .

# Force a clean rebuild (no cached layers)
devcontainer up --workspace-folder . --remove-existing-container
```

Run both commands from the **project root on the host** (not inside the container).

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
devcontainer up --workspace-folder . --remove-existing-container
```

### Where to Run

| Step | Location |
|------|----------|
| One-off `apt-get install` | Inside the running container |
| Edit `post-create-superagents.sh` | Host (your editor) |
| `devcontainer up` rebuild | Host terminal |

---

## Reference

- Anthropic devcontainer docs: `https://code.claude.com/docs/en/devcontainer`
- Dev Containers CLI: `https://github.com/devcontainers/cli`
- VS Code Dev Containers extension: `https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers`
- For initial devcontainer setup, see the `superagents-devcontainer-bootstrap` skill.
