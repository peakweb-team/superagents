#!/usr/bin/env bash
set -euo pipefail

SUPERAGENTS_REPO="${SUPERAGENTS_REPO:-https://github.com/peakweb-team/pw-agency-agents.git}"
SUPERAGENTS_REF="${SUPERAGENTS_REF:-main}"
WORKDIR="$(mktemp -d)"

cleanup() {
  rm -rf "$WORKDIR"
}
trap cleanup EXIT

git clone --depth 1 --branch "$SUPERAGENTS_REF" "$SUPERAGENTS_REPO" "$WORKDIR/pw-agency-agents"
"$WORKDIR/pw-agency-agents/scripts/install.sh" --tool claude-code --no-interactive

echo "Superagents installed at user scope in ${HOME}/.claude"
