#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $# -lt 1 ]]; then
  echo "Usage: ./scripts/query-workspace-feature-graph.sh <manifest-path> (--feature-id ID | --repo-id ID) [--view feature|repo|integration|execution-order|gate-status] [--format json]" >&2
  exit 2
fi

ruby "$SCRIPT_DIR/query-workspace-feature-graph.rb" "$@"
