#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GITIGNORE="$ROOT_DIR/.gitignore"

required_patterns=(
  ".claude/"
  ".agency/"
  ".codex/"
)

has_line_match() {
  local literal="$1" file="$2"
  if command -v rg >/dev/null 2>&1; then
    rg -qxF "$literal" "$file"
  else
    grep -Fxq "$literal" "$file"
  fi
}

has_any_output() {
  if command -v rg >/dev/null 2>&1; then
    rg -q "."
  else
    grep -q "."
  fi
}

for pattern in "${required_patterns[@]}"; do
  if ! has_line_match "$pattern" "$GITIGNORE"; then
    echo "Missing required dogfooding ignore pattern in .gitignore: $pattern"
    exit 1
  fi
done

if git -C "$ROOT_DIR" ls-files -- ".claude/*" ".agency/*" ".codex/*" | has_any_output; then
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
