#!/usr/bin/env bash
set -euo pipefail

test -f "${HOME}/.claude/skills/superagents-skill-builder/SKILL.md"
test -f "${HOME}/.claude/skills/superagents-devcontainer-bootstrap/SKILL.md"
test -f "${HOME}/.claude/skills/superagents-devcontainer-bootstrap/templates/scaffold-devcontainer.sh"
command -v claude >/dev/null 2>&1

echo "OK: Superagents user-level bundles are installed inside the container."
echo "Optional: run 'claude --dangerously-skip-permissions' only for trusted repositories."
