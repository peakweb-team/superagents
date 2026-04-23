#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_SCRIPT="$ROOT_DIR/scripts/install.sh"

TMP_HOME="$(mktemp -d)"
trap 'rm -rf "$TMP_HOME"' EXIT

mkdir -p "$TMP_HOME/.claude"

HOME="$TMP_HOME" "$INSTALL_SCRIPT" --tool claude-code --no-interactive >/tmp/superagents-install-smoke-1.log

AGENTS_DIR="$TMP_HOME/.claude/agents"
SKILL_BUILDER_DIR="$TMP_HOME/.claude/skills/superagents-skill-builder"
DEVCONTAINER_DIR="$TMP_HOME/.claude/skills/superagents-devcontainer-bootstrap"

[[ -d "$AGENTS_DIR" ]] || { echo "Expected agent install directory at $AGENTS_DIR"; exit 1; }
[[ -f "$SKILL_BUILDER_DIR/SKILL.md" ]] || { echo "Missing skill-builder SKILL.md"; exit 1; }
[[ -f "$DEVCONTAINER_DIR/SKILL.md" ]] || { echo "Missing devcontainer bootstrap SKILL.md"; exit 1; }
[[ -f "$SKILL_BUILDER_DIR/fragments/project-management/github-issues.md" ]] || { echo "Missing copied fragment in skill-builder bundle"; exit 1; }

expected_fragments="$(find "$ROOT_DIR/skills/fragments" -name '*.md' -type f | wc -l | awk '{print $1}')"
installed_fragments="$(find "$SKILL_BUILDER_DIR/fragments" -name '*.md' -type f | wc -l | awk '{print $1}')"
[[ "$installed_fragments" == "$expected_fragments" ]] || {
  echo "Expected $expected_fragments fragments in installed bundle, found $installed_fragments"
  exit 1
}

stale_file="$SKILL_BUILDER_DIR/fragments/stale-should-be-removed.md"
echo "stale" > "$stale_file"
[[ -f "$stale_file" ]] || { echo "Failed to create stale file fixture"; exit 1; }

HOME="$TMP_HOME" "$INSTALL_SCRIPT" --tool claude-code --no-interactive >/tmp/superagents-install-smoke-2.log

[[ ! -e "$stale_file" ]] || {
  echo "Stale fragment file survived reinstall: $stale_file"
  exit 1
}

echo "Installer smoke tests: passed"
