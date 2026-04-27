---
schema_version: 1
id: runtime/devcontainer-management
title: Devcontainer Management
fragment_type: generic
layer: runtime
summary: Surface rebuild, stop, and package-extension operations for Superagents devcontainers so operators do not need to recall Docker and VS Code commands from memory.
capabilities:
  - runtime.devcontainer-management
selection:
  evidence_any:
    - repo.devcontainer
    - toolchain.docker
    - runtime.claude-code-dangerously-skip-permissions
  evidence_all: []
  evidence_none: []
  preference: 60
composition:
  requires: []
  suggests:
    - runtime/context-and-model-routing
  conflicts: []
  exclusive_within: []
  emits:
    - devcontainer-management-rules
  order: 75
---

# Fragment: Devcontainer Management

## Purpose

Make common devcontainer lifecycle operations discoverable so operators do not need to ask Claude for the right commands each time they rebuild, stop, or extend a running container.

## Include When

- The repository contains a `.devcontainer/` directory.
- The workflow uses `--dangerously-skip-permissions` inside a container.
- Docker is part of the project's local development toolchain.

## Expected Behaviors

- When a config change is detected (`devcontainer.json`, `Dockerfile`, `post-create-superagents.sh`), proactively suggest a rebuild using the `superagents-devcontainer` skill.
- When asked to stop or pause a container environment, use the Docker label-filter approach rather than stopping all containers indiscriminately.
- When asked to add a package, distinguish between a one-off in-container install and a permanent change to `post-create-superagents.sh` and recommend the appropriate path.

## Builder Notes

- This fragment delegates the actual command reference to the `superagents-devcontainer` skill; include that skill in the generated output alongside the primary orchestration skill.
- Do not include this fragment unless a `.devcontainer/` directory or equivalent Docker-based workflow signal is present.
