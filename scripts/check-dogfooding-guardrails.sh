#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GITIGNORE="$ROOT_DIR/.gitignore"

# Patterns that MUST appear literally in .gitignore. The root-anchored
# `/.claude/*` and `/.agency/*` patterns ignore root-level content by
# default; specific dogfood-bundle paths are re-included via separate
# `!` lines (see required_unignore_patterns below).
required_patterns=(
  "/.claude/*"
  "/.agency/*"
  ".codex/"
)

# Dogfood bundle paths that MUST be re-included via `!` exceptions so
# the committed bundle survives the broad ignores above.
required_unignore_patterns=(
  "!/.claude/skills/superagents-workflow/"
  "!/.agency/skills/superagents/"
)

has_line_match() {
  local literal="$1" file="$2"
  if command -v rg >/dev/null 2>&1; then
    rg -qxF "$literal" "$file"
  else
    grep -Fxq "$literal" "$file"
  fi
}

for pattern in "${required_patterns[@]}"; do
  if ! has_line_match "$pattern" "$GITIGNORE"; then
    echo "Missing required dogfooding ignore pattern in .gitignore: $pattern"
    exit 1
  fi
done

for pattern in "${required_unignore_patterns[@]}"; do
  if ! has_line_match "$pattern" "$GITIGNORE"; then
    echo "Missing required dogfood-bundle un-ignore pattern in .gitignore: $pattern"
    exit 1
  fi
done

# Local-only paths that must remain ignored even though their parents
# are now selectively un-ignored for the dogfood bundle.
must_be_ignored=(
  ".claude/settings.local.json"
  ".claude/skills/superagents/SKILL.md"
  ".codex/sessions/runtime.log"
)

for path in "${must_be_ignored[@]}"; do
  if ! git -C "$ROOT_DIR" check-ignore -q "$path"; then
    echo "Expected path to be ignored by git: $path"
    exit 1
  fi
done

# Dogfood-bundle paths that must NOT be ignored — they are committed so
# the bundle survives devcontainer rebuilds and so the upgrade flow
# exercises against a real committed artifact.
must_not_be_ignored=(
  ".agency/skills/superagents/manifest.yaml"
  ".claude/skills/superagents-workflow/SKILL.md"
)

for path in "${must_not_be_ignored[@]}"; do
  if git -C "$ROOT_DIR" check-ignore -q "$path"; then
    echo "Expected path to be tracked by git (dogfood bundle): $path"
    exit 1
  fi
done

# Tracked files under .claude/, .agency/, .codex/ are restricted to the
# dogfood bundle paths only. Any other tracked file is a leak.
tracked=$(git -C "$ROOT_DIR" ls-files -- ".claude/*" ".agency/*" ".codex/*" || true)
if [ -n "$tracked" ]; then
  unexpected=$(echo "$tracked" | grep -v -E "^(\.agency/skills/superagents/|\.claude/skills/superagents-workflow/)" || true)
  if [ -n "$unexpected" ]; then
    echo "Unexpected tracked runtime artifacts under .claude/, .agency/, or .codex/:"
    echo "$unexpected"
    exit 1
  fi
fi

echo "Dogfooding guardrails check: passed"
