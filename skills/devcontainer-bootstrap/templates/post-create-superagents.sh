#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Upgrade gh CLI to latest stable release (base image ships v2.23.0 which
# predates gh project item-edit and gh project field-list improvements).
# Networking failures are non-fatal: a warning is logged and the script
# continues so the rest of post-create is not blocked.
# ---------------------------------------------------------------------------
upgrade_gh_cli() {
  echo "Upgrading gh CLI to latest stable release..."
  if curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
       | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null \
     && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
       | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
     && sudo apt-get -o APT::Sandbox::User=root update -y \
     && sudo apt-get install -y gh; then
    echo "gh CLI upgraded: $(gh --version | head -1)"
  else
    echo "WARNING: gh CLI upgrade failed (network may be degraded) — continuing with existing version: $(gh --version 2>/dev/null | head -1 || echo 'unknown')"
  fi
}

upgrade_gh_cli

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
