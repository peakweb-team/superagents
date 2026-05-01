#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${1:-.devcontainer}"
BASE_URL="${ANTHROPIC_DEVCONTAINER_BASE_URL:-https://raw.githubusercontent.com/anthropics/claude-code/main/.devcontainer}"

mkdir -p "$TARGET_DIR"

curl -fsSL "$BASE_URL/devcontainer.json" -o "$TARGET_DIR/devcontainer.json"
curl -fsSL "$BASE_URL/Dockerfile" -o "$TARGET_DIR/Dockerfile"

TEMPLATE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp "$TEMPLATE_DIR/post-create-superagents.sh" "$TARGET_DIR/post-create-superagents.sh"
cp "$TEMPLATE_DIR/smoke-test-superagents.sh" "$TARGET_DIR/smoke-test-superagents.sh"
cp "$TEMPLATE_DIR/upgrade-superagents-in-container.sh" "$TARGET_DIR/upgrade-superagents-in-container.sh"
chmod +x \
  "$TARGET_DIR/post-create-superagents.sh" \
  "$TARGET_DIR/smoke-test-superagents.sh" \
  "$TARGET_DIR/upgrade-superagents-in-container.sh"

# --- CLI helper scripts (project root) ---
# Install dc-build / dc-up / dc-shell at the *project root* (not under
# .devcontainer/). These are host-side wrappers around the `devcontainer` CLI
# so operators can `./dc-build`, `./dc-up`, `./dc-shell` from the project root.
#
# The project root is the parent of TARGET_DIR (TARGET_DIR is conventionally
# <project>/.devcontainer, but callers can pass any path; resolve the parent
# explicitly so we don't depend on cwd).
PROJECT_ROOT="$(cd "$(dirname "$TARGET_DIR")" && pwd)"

# Idempotency: if a helper already exists at the destination, skip it with a
# notice rather than overwriting an operator-modified version. Mirrors the
# install_aider / install_windsurf pattern in scripts/install.sh.
for helper in dc-build dc-up dc-shell dc-stop; do
  src="$TEMPLATE_DIR/$helper"
  dest="$PROJECT_ROOT/$helper"
  if [ -e "$dest" ]; then
    echo "Skipping $helper: $dest already exists (remove to reinstall)."
    continue
  fi
  cp "$src" "$dest"
  chmod +x "$dest"
  echo "Installed $helper -> $dest"
done

# ---------------------------------------------------------------------------
# Port designation
# ---------------------------------------------------------------------------
# Resolve the repo name from the git root of the project being scaffolded,
# then look up the designated dev server port in the port registry.
REPO_NAME="$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")"
PORTS_REGISTRY="${TEMPLATE_DIR}/../ports.yaml"

if [ ! -f "$PORTS_REGISTRY" ]; then
  echo "ERROR: port registry not found at $PORTS_REGISTRY" >&2
  exit 1
fi

PROJECT_PORT="$(python3 - "$PORTS_REGISTRY" "$REPO_NAME" <<'PYEOF'
import sys, re

registry_file = sys.argv[1]
repo_name     = sys.argv[2]

with open(registry_file) as f:
    content = f.read()

# Parse only the projects block — avoid a hard yaml dependency.
in_projects = False
for line in content.splitlines():
    stripped = line.strip()
    if stripped.startswith('#') or not stripped:
        continue
    if stripped == 'projects:':
        in_projects = True
        continue
    if in_projects:
        # Detect end of mapping (top-level key)
        if re.match(r'^\S', line) and not line.startswith(' '):
            break
        m = re.match(r'^\s+(\S+):\s*(\d+)', line)
        if m and m.group(1) == repo_name:
            print(m.group(2))
            sys.exit(0)

print(f"ERROR: repo '{repo_name}' not found in port registry.", file=sys.stderr)
print(f"       Add an entry to skills/devcontainer-bootstrap/ports.yaml:", file=sys.stderr)
print(f"         {repo_name}: <port>   # pick an unused port in 3100-3999", file=sys.stderr)
sys.exit(1)
PYEOF
)" || exit 1

# Write the port file so scripts/skills can read it without hardcoding.
printf '%s\n' "$PROJECT_PORT" > "$TARGET_DIR/.project-port"
echo "Port designation: $REPO_NAME -> $PROJECT_PORT (written to $TARGET_DIR/.project-port)"

node - "$TARGET_DIR/devcontainer.json" "$PROJECT_PORT" <<'NODE'
const fs   = require('fs');
const file = process.argv[2];
const port = Number(process.argv[3]);
const doc  = JSON.parse(fs.readFileSync(file, 'utf8'));
delete doc.postStartCommand;
if (doc.waitFor === 'postStartCommand') {
  delete doc.waitFor;
}
if (Array.isArray(doc.runArgs)) {
  doc.runArgs = doc.runArgs.filter((arg, idx, arr) => {
    if (arg === 'NET_ADMIN' || arg === 'NET_RAW') {
      return false;
    }
    if ((arg === '--cap-add' || arg === '--cap-drop') && (arr[idx + 1] === 'NET_ADMIN' || arr[idx + 1] === 'NET_RAW')) {
      return false;
    }
    return true;
  });
}

const mounts = Array.isArray(doc.mounts) ? [...doc.mounts] : [];
const requiredMounts = [
  'source=superagents-npm-cache,target=/home/node/.npm-cache,type=volume',
  'source=superagents-pnpm-store,target=/home/node/.pnpm-store,type=volume'
];
for (const mount of requiredMounts) {
  if (!mounts.includes(mount)) {
    mounts.push(mount);
  }
}
doc.mounts = mounts;

doc.containerEnv = {
  ...(doc.containerEnv || {}),
  GH_TOKEN: '${localEnv:GH_TOKEN}',
  VERCEL_TOKEN: '${localEnv:VERCEL_TOKEN}',
  SUPERAGENTS_S3_ACCESS_KEY_ID: '${localEnv:SUPERAGENTS_S3_ACCESS_KEY_ID}',
  SUPERAGENTS_S3_SECRET_ACCESS_KEY: '${localEnv:SUPERAGENTS_S3_SECRET_ACCESS_KEY}',
  SUPERAGENTS_S3_REGION: '${localEnv:SUPERAGENTS_S3_REGION}',
  SUPERAGENTS_S3_BUCKET: '${localEnv:SUPERAGENTS_S3_BUCKET}',
  npm_config_cache: '/home/node/.npm-cache',
  npm_config_store_dir: '/home/node/.pnpm-store'
};
doc.postCreateCommand = '.devcontainer/post-create-superagents.sh';
doc.forwardPorts = [port];
fs.writeFileSync(file, `${JSON.stringify(doc, null, 2)}\n`);
NODE

node - "$TARGET_DIR/Dockerfile" <<'NODE'
const fs = require('fs');
const file = process.argv[2];
const dockerfile = fs.readFileSync(file, 'utf8');
const withUpdatedNode = dockerfile.replace(
  /(^\s*FROM\s+node:)20(\S*)/gim,
  '$124$2'
);
const withCleanNpmInstall = withUpdatedNode.replace(
  /npm install -g @anthropic-ai\/claude-code(@\S+)?(?!\s*&&\s*npm cache clean --force)/g,
  'npm install -g @anthropic-ai/claude-code$1 && npm cache clean --force'
);
const withAptSandboxOverride = withCleanNpmInstall.replace(
  /\bapt-get\s+update\b/g,
  'apt-get -o APT::Sandbox::User=root update'
);
let updated = withAptSandboxOverride;
if (
  updated.includes('apt-get -o APT::Sandbox::User=root update') &&
  !updated.includes('APT sandbox keyring access workaround')
) {
  updated = updated.replace(
    /(RUN\s+apt-get\s+-o APT::Sandbox::User=root update\b)/,
    '# APT sandbox keyring access workaround: prevents intermittent Debian GPG signature failures.\n$1'
  );
}
fs.writeFileSync(file, updated);
NODE

# Install gh CLI from the official GitHub source at build time so the container
# ships the latest version without needing a runtime upgrade in post-create.
node - "$TARGET_DIR/Dockerfile" <<'NODE'
const fs = require('fs');
const file = process.argv[2];
let updated = fs.readFileSync(file, 'utf8');

if (!updated.includes('githubcli-archive-keyring.gpg')) {
  // Remove `gh` from the basic apt-get install list (Debian ships an older version).
  updated = updated.replace(/^[ \t]+gh[ \t]*\\?\n/gm, '');

  // Append the official gh CLI install block after the first apt-get clean line.
  const ghBlock = [
    '',
    '# Install gh CLI from official GitHub source (gets latest, not Debian\'s older version).',
    'RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \\',
    '      | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \\',
    '    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \\',
    '      > /etc/apt/sources.list.d/github-cli.list \\',
    '    && apt-get -o APT::Sandbox::User=root update \\',
    '    && apt-get install -y gh',
  ].join('\n');
  updated = updated.replace(
    /(&&\s*apt-get\s+clean\s*&&\s*rm\s+-rf\s+\/var\/lib\/apt\/lists\/\*)/,
    `$1${ghBlock}`
  );
}
fs.writeFileSync(file, updated);
NODE

# Strip the upstream init-firewall block. The Anthropic base Dockerfile installs
# /usr/local/bin/init-firewall.sh and an associated sudoers entry; we don't ship
# the script (network locked down differently in this fork), so its references
# would break the build. Use a line-based scanner that's robust against minor
# upstream formatting changes (extra blank lines, missing optional USER lines,
# multi-line RUN continuations).
#
# IMPORTANT: this MUST run BEFORE the passwordless-sudo patch below, because
# the upstream block writes to /etc/sudoers.d/node-firewall and its presence
# can confuse a substring-based guard on the sudo patch.
node - "$TARGET_DIR/Dockerfile" <<'NODE'
const fs = require('fs');
const file = process.argv[2];
const original = fs.readFileSync(file, 'utf8');

const lines = original.split('\n');
const out = [];
let i = 0;
let removed = false;

while (i < lines.length) {
  const line = lines[i];

  // Detect the start of the firewall block. The canonical anchor is the
  // `COPY init-firewall.sh` line; the preceding comment is optional.
  if (/^\s*COPY\s+init-firewall\.sh\b/.test(line)) {
    // Drop a trailing comment we may have just appended that introduces the
    // firewall block (e.g. "# Copy and set up firewall script").
    while (
      out.length > 0 &&
      /^\s*#[^\n]*firewall/i.test(out[out.length - 1])
    ) {
      out.pop();
    }
    // Also drop any trailing blank lines that lead into the block, so we
    // don't leave a double-blank gap behind.
    while (out.length > 0 && /^\s*$/.test(out[out.length - 1])) {
      out.pop();
    }

    // Skip the COPY line itself.
    i++;

    // Optional USER root.
    if (i < lines.length && /^\s*USER\s+root\s*$/.test(lines[i])) {
      i++;
    }

    // Skip the RUN block. Anthropic's RUN spans multiple lines via trailing
    // backslashes; consume continuation lines until we see one without a
    // trailing backslash. Only treat it as the firewall RUN if the first
    // line mentions init-firewall (defensive: avoid eating an unrelated RUN).
    if (
      i < lines.length &&
      /^\s*RUN\b[^\n]*init-firewall/.test(lines[i])
    ) {
      let runLine = lines[i];
      i++;
      while (/\\\s*$/.test(runLine) && i < lines.length) {
        runLine = lines[i];
        i++;
      }
    }

    // Optional trailing USER node.
    if (i < lines.length && /^\s*USER\s+node\s*$/.test(lines[i])) {
      i++;
    }

    removed = true;
    continue;
  }

  out.push(line);
  i++;
}

let updated = out.join('\n');

// Final safety net: if any stray init-firewall reference remains (e.g. a new
// upstream variation we didn't anticipate), strip the remaining lines that
// mention it so the acceptance criterion (zero init-firewall references) is
// always satisfied. This is intentionally conservative: it only drops lines
// that explicitly reference init-firewall or sudoers.d/node-firewall.
if (/init-firewall|sudoers\.d\/node-firewall/.test(updated)) {
  updated = updated
    .split('\n')
    .filter((l) => !/init-firewall|sudoers\.d\/node-firewall/.test(l))
    .join('\n');
  removed = true;
}

// Collapse 3+ consecutive blank lines down to 2 to keep diffs tidy.
updated = updated.replace(/\n{3,}/g, '\n\n');

if (removed) {
  fs.writeFileSync(file, updated);
}
NODE

# Enable passwordless sudo for the node user (devcontainer-only).
#
# NOTE: The guard checks for the literal `NOPASSWD:ALL` rule that this patch
# installs, NOT for any path under /etc/sudoers.d/. Earlier versions used
# `sudoers.d/node` as the sentinel, which false-positives on
# `sudoers.d/node-firewall` (a substring) when the upstream firewall block is
# present. Ordering: the firewall-stripping block above runs first, so by this
# point `sudoers.d/node-firewall` should be gone — but the `NOPASSWD:ALL`
# sentinel is robust regardless of order.
node - "$TARGET_DIR/Dockerfile" <<'NODE'
const fs = require('fs');
const file = process.argv[2];
let updated = fs.readFileSync(file, 'utf8');

if (!updated.includes('NOPASSWD:ALL')) {
  const sudoersBlock = [
    '',
    '# Allow the node user to run sudo without a password (devcontainer-only).',
    'RUN echo "node ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/node && \\',
    '    chmod 0440 /etc/sudoers.d/node',
  ].join('\n');
  // Insert immediately before USER node (or USER $USERNAME as a fallback).
  updated = updated.replace(
    /(^\s*USER\s+(?:node|\$USERNAME)\s*$)/m,
    `${sudoersBlock}\n\n$1`
  );
}
fs.writeFileSync(file, updated);
NODE

echo "Scaffolded Anthropic-based devcontainer into $TARGET_DIR"
echo "Next step: reopen this repository in container and run .devcontainer/smoke-test-superagents.sh"
