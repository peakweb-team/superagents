#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${1:-.devcontainer}"
BASE_URL="${ANTHROPIC_DEVCONTAINER_BASE_URL:-https://raw.githubusercontent.com/anthropics/claude-code/main/.devcontainer}"

mkdir -p "$TARGET_DIR"

curl -fsSL "$BASE_URL/devcontainer.json" -o "$TARGET_DIR/devcontainer.json"
curl -fsSL "$BASE_URL/Dockerfile" -o "$TARGET_DIR/Dockerfile"
curl -fsSL "$BASE_URL/init-firewall.sh" -o "$TARGET_DIR/init-firewall.sh"
chmod +x "$TARGET_DIR/init-firewall.sh"

TEMPLATE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp "$TEMPLATE_DIR/post-create-superagents.sh" "$TARGET_DIR/post-create-superagents.sh"
cp "$TEMPLATE_DIR/smoke-test-superagents.sh" "$TARGET_DIR/smoke-test-superagents.sh"
chmod +x "$TARGET_DIR/post-create-superagents.sh" "$TARGET_DIR/smoke-test-superagents.sh"

node - "$TARGET_DIR/devcontainer.json" <<'NODE'
const fs = require('fs');
const file = process.argv[2];
const doc = JSON.parse(fs.readFileSync(file, 'utf8'));
doc.postCreateCommand = '.devcontainer/post-create-superagents.sh';
fs.writeFileSync(file, `${JSON.stringify(doc, null, 2)}\n`);
NODE

echo "Scaffolded Anthropic-based devcontainer into $TARGET_DIR"
echo "Next step: reopen this repository in container and run .devcontainer/smoke-test-superagents.sh"
