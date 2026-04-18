#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $# -lt 1 ]]; then
  echo "Usage: ./scripts/validate-workspace-manifest.sh <manifest-path> [manifest-path...]" >&2
  exit 2
fi

ruby "$SCRIPT_DIR/validate-workspace-manifest.rb" "$@"
