#!/usr/bin/env bash
set -euo pipefail

# Verifies that scaffold-devcontainer.sh:
#   - removes every init-firewall reference from the Anthropic base Dockerfile
#     (issue #141)
#   - applies the passwordless NOPASSWD:ALL sudoers block even when the source
#     contains /etc/sudoers.d/node-firewall (issue #142)
#   - is idempotent: a second run does not double-apply the patch or fail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCAFFOLD="$ROOT_DIR/skills/devcontainer-bootstrap/templates/scaffold-devcontainer.sh"
FIXTURE="$ROOT_DIR/tests/fixtures/scaffold-devcontainer/anthropic-base-dockerfile.txt"

[[ -x "$SCAFFOLD" ]] || { echo "Missing or non-executable scaffold script: $SCAFFOLD" >&2; exit 1; }
[[ -f "$FIXTURE" ]]  || { echo "Missing fixture: $FIXTURE" >&2; exit 1; }

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

# Stand up a fake "Anthropic upstream" served from the local filesystem so the
# scaffold's curl call is hermetic. The scaffold's BASE_URL is consumed by curl
# directly, so a file:// URL prefix works.
UPSTREAM_DIR="$TMP_ROOT/upstream"
mkdir -p "$UPSTREAM_DIR"
cp "$FIXTURE" "$UPSTREAM_DIR/Dockerfile"

# Minimal devcontainer.json sufficient for the scaffold's JSON patch step.
cat >"$UPSTREAM_DIR/devcontainer.json" <<'JSON'
{
  "name": "test",
  "build": { "dockerfile": "Dockerfile" },
  "runArgs": ["--cap-add", "NET_ADMIN", "--cap-add", "NET_RAW"],
  "mounts": [],
  "containerEnv": {},
  "postStartCommand": "echo hi",
  "waitFor": "postStartCommand"
}
JSON

# Run scaffold inside a fake repo with a known name that exists in ports.yaml.
# Pick the first project entry from the real ports registry so the lookup
# succeeds without us having to mutate the registry.
PORTS_YAML="$ROOT_DIR/skills/devcontainer-bootstrap/ports.yaml"
[[ -f "$PORTS_YAML" ]] || { echo "Missing ports registry at $PORTS_YAML" >&2; exit 1; }
REPO_NAME="$(python3 - "$PORTS_YAML" <<'PYEOF'
import sys, re
with open(sys.argv[1]) as f:
    in_projects = False
    for line in f:
        s = line.strip()
        if s.startswith('#') or not s:
            continue
        if s == 'projects:':
            in_projects = True
            continue
        if in_projects:
            if re.match(r'^\S', line) and not line.startswith(' '):
                break
            m = re.match(r'^\s+(\S+):\s*\d+', line)
            if m:
                print(m.group(1))
                sys.exit(0)
PYEOF
)"
[[ -n "$REPO_NAME" ]] || { echo "Could not pick a repo name from $PORTS_YAML" >&2; exit 1; }

REPO_DIR="$TMP_ROOT/$REPO_NAME"
mkdir -p "$REPO_DIR"
git -C "$REPO_DIR" init -q
git -C "$REPO_DIR" config user.email "test@example.com"
git -C "$REPO_DIR" config user.name  "Test"
git -C "$REPO_DIR" commit --allow-empty -q -m "init"

TARGET_DIR="$REPO_DIR/.devcontainer"

run_scaffold() {
  ( cd "$REPO_DIR" \
    && ANTHROPIC_DEVCONTAINER_BASE_URL="file://$UPSTREAM_DIR" \
       "$SCAFFOLD" "$TARGET_DIR" >/dev/null )
}

assert_dockerfile() {
  local label="$1"
  local dockerfile="$TARGET_DIR/Dockerfile"

  [[ -f "$dockerfile" ]] || { echo "[$label] Dockerfile not produced at $dockerfile" >&2; exit 1; }

  if grep -q "init-firewall" "$dockerfile"; then
    echo "[$label] FAIL: Dockerfile still contains init-firewall references:" >&2
    grep -n "init-firewall" "$dockerfile" >&2 || true
    exit 1
  fi

  if grep -q "sudoers.d/node-firewall" "$dockerfile"; then
    echo "[$label] FAIL: Dockerfile still references sudoers.d/node-firewall" >&2
    exit 1
  fi

  if ! grep -q "NOPASSWD:ALL" "$dockerfile"; then
    echo "[$label] FAIL: Dockerfile missing NOPASSWD:ALL passwordless sudo block" >&2
    exit 1
  fi

  local count
  count="$(grep -c "NOPASSWD:ALL" "$dockerfile" || true)"
  if [[ "$count" -ne 1 ]]; then
    echo "[$label] FAIL: expected exactly 1 NOPASSWD:ALL line, found $count" >&2
    exit 1
  fi

  # Sanity: the COPY init-firewall and its companion USER root/RUN chmod block
  # should be gone, but the rest of the Dockerfile (e.g. FROM, USER node, the
  # claude-code install) should still be present.
  grep -q "^FROM node:" "$dockerfile" || { echo "[$label] FAIL: missing FROM node line" >&2; exit 1; }
  grep -q "@anthropic-ai/claude-code" "$dockerfile" || { echo "[$label] FAIL: missing claude-code install line" >&2; exit 1; }
}

# First run: patches apply against unmodified upstream content.
run_scaffold
assert_dockerfile "first run"

# Snapshot for idempotency comparison.
FIRST_HASH="$(sha256sum "$TARGET_DIR/Dockerfile" | awk '{print $1}')"

# Second run: must not double-apply, must not fail.
run_scaffold
assert_dockerfile "second run"

SECOND_HASH="$(sha256sum "$TARGET_DIR/Dockerfile" | awk '{print $1}')"
if [[ "$FIRST_HASH" != "$SECOND_HASH" ]]; then
  echo "FAIL: scaffold is not idempotent (Dockerfile hash changed between runs)" >&2
  diff <(echo "first") <(echo "second") || true
  exit 1
fi

# Variant: blank lines between firewall sub-blocks. CodeRabbit flagged that the
# scanner stops early on this shape; ensure the patcher still strips cleanly.
rm -rf "$TARGET_DIR"
cat >"$UPSTREAM_DIR/Dockerfile" <<'DOCKERFILE'
FROM node:20

ARG CLAUDE_CODE_VERSION=latest

RUN apt-get update && apt-get install -y --no-install-recommends \
  sudo \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

USER node

# Install Claude
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}


# Copy and set up firewall script
COPY init-firewall.sh /usr/local/bin/

USER root

RUN chmod +x /usr/local/bin/init-firewall.sh && \
  echo "node ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" > /etc/sudoers.d/node-firewall && \
  chmod 0440 /etc/sudoers.d/node-firewall

USER node
DOCKERFILE
run_scaffold
assert_dockerfile "blank-line variant"

# Variant: the firewall block ships without the optional USER root and trailing
# USER node markers (a plausible upstream shape change).
rm -rf "$TARGET_DIR"
cat >"$UPSTREAM_DIR/Dockerfile" <<'DOCKERFILE'
FROM node:20

ARG CLAUDE_CODE_VERSION=latest

RUN apt-get update && apt-get install -y --no-install-recommends \
  sudo \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Claude
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}

# Copy and set up firewall script
COPY init-firewall.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/init-firewall.sh && \
  echo "node ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" > /etc/sudoers.d/node-firewall && \
  chmod 0440 /etc/sudoers.d/node-firewall

USER node
DOCKERFILE
run_scaffold
assert_dockerfile "no USER root variant"

echo "scaffold-devcontainer patches tests: passed"
