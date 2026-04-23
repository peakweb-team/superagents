#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GITIGNORE="$ROOT_DIR/.gitignore"

required_patterns=(
  ".claude/"
  ".agency/"
  ".codex/"
)

for pattern in "${required_patterns[@]}"; do
  if ! rg -qxF "$pattern" "$GITIGNORE"; then
    echo "Missing required dogfooding ignore pattern in .gitignore: $pattern"
    exit 1
  fi
done

if git -C "$ROOT_DIR" ls-files -- ".claude/*" ".agency/*" ".codex/*" | rg -q "."; then
  echo "Tracked runtime artifacts detected under .claude/, .agency/, or .codex/"
  exit 1
fi

if ! git -C "$ROOT_DIR" check-ignore -q ".claude/skills/superagents/SKILL.md"; then
  echo "Expected .claude/ paths to be ignored by git"
  exit 1
fi

if ! git -C "$ROOT_DIR" check-ignore -q ".agency/skills/superagents/SKILL.md"; then
  echo "Expected .agency/ paths to be ignored by git"
  exit 1
fi

if ! git -C "$ROOT_DIR" check-ignore -q ".codex/sessions/runtime.log"; then
  echo "Expected .codex/ paths to be ignored by git"
  exit 1
fi

echo "Dogfooding guardrails check: passed"
