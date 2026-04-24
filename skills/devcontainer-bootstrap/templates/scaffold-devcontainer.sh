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
chmod +x "$TARGET_DIR/post-create-superagents.sh" "$TARGET_DIR/smoke-test-superagents.sh"

node - "$TARGET_DIR/devcontainer.json" <<'NODE'
const fs = require('fs');
const file = process.argv[2];
const doc = JSON.parse(fs.readFileSync(file, 'utf8'));
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
  npm_config_cache: '/home/node/.npm-cache',
  npm_config_store_dir: '/home/node/.pnpm-store'
};
doc.postCreateCommand = '.devcontainer/post-create-superagents.sh';
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

echo "Scaffolded Anthropic-based devcontainer into $TARGET_DIR"
echo "Next step: reopen this repository in container and run .devcontainer/smoke-test-superagents.sh"
