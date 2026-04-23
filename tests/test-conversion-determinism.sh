#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! git -C "$ROOT_DIR" diff --quiet -- integrations; then
  echo "Refusing determinism check: tracked changes already exist under integrations/."
  git -C "$ROOT_DIR" status --short -- integrations
  exit 1
fi

"$ROOT_DIR/scripts/convert.sh"

if ! git -C "$ROOT_DIR" diff --quiet -- integrations; then
  echo "Conversion determinism check failed: integrations/ changed after running convert.sh"
  git -C "$ROOT_DIR" --no-pager diff --stat -- integrations
  git -C "$ROOT_DIR" --no-pager diff -- integrations
  exit 1
fi

echo "Conversion determinism tests: passed"
