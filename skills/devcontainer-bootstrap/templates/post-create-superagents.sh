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

# ---------------------------------------------------------------------------
# Install Playwright (Chromium only) so the container can run browser
# automation without additional setup.  Chromium binaries are ~150 MB;
# --with-deps handles OS-level libraries (libglib, libatk, etc.).
# Expect ~2-3 min on a warm network.  Failures are non-fatal: a warning is
# logged and post-create continues so the rest of the workflow is not blocked.
# ---------------------------------------------------------------------------
install_playwright() {
  echo "Installing Playwright (Chromium only)..."
  if npm install -g playwright \
     && npx playwright install chromium --with-deps; then
    echo "Playwright installed: $(npx playwright --version)"
  else
    echo "WARNING: Playwright install failed (network may be degraded or OS deps unavailable) — continuing without Playwright"
  fi
}

install_playwright

SUPERAGENTS_REPO="${SUPERAGENTS_REPO:-https://github.com/peakweb-team/pw-agency-agents.git}"
SUPERAGENTS_REF="${SUPERAGENTS_REF:-main}"
WORKDIR="$(mktemp -d)"

cleanup() {
  rm -rf "$WORKDIR"
}
trap cleanup EXIT

git clone --depth 1 --branch "$SUPERAGENTS_REF" "$SUPERAGENTS_REPO" "$WORKDIR/pw-agency-agents"
"$WORKDIR/pw-agency-agents/scripts/install.sh" --tool claude-code --no-interactive

# Fix node_modules ownership when a named volume initialises it as root.
[ -d /workspace/node_modules ] && sudo chown -R node:node /workspace/node_modules || true

echo "Superagents installed at user scope in ${HOME}/.claude"
