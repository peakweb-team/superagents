#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QUERY="$ROOT_DIR/scripts/query-workspace-feature-graph.sh"
FIXTURE="$ROOT_DIR/tests/fixtures/workspace-manifests/valid/feature-graph-multi-repo.yaml"

feature_json="$(mktemp)"
repo_json="$(mktemp)"
trap 'rm -f "$feature_json" "$repo_json"' EXIT

"$QUERY" "$FIXTURE" --feature-id rollout-bridge >"$feature_json"
"$QUERY" "$FIXTURE" --view repo --repo-id web --feature-id rollout-bridge >"$repo_json"

ruby -rjson -e '
  feature = JSON.parse(File.read(ARGV[0]))
  repo = JSON.parse(File.read(ARGV[1]))

  raise "expected feature view" unless feature["view"] == "feature"
  raise "expected feature id" unless feature["feature_id"] == "rollout-bridge"
  raise "expected blocked rollup status" unless feature.dig("rollup", "overall_status") == "blocked"
  raise "expected three repo rollups" unless feature["by_repo"].length == 3
  raise "expected blocked blocker count" unless feature.dig("rollup", "blocking", "blocker_count") == 2

  raise "expected repo view" unless repo["view"] == "repo"
  raise "expected repo id" unless repo["repo_id"] == "web"
  raise "expected one web task" unless repo["tasks"].length == 1
  raise "expected blocked repo rollup" unless repo.dig("rollup", "overall_status") == "blocked"
  raise "expected blocked status count" unless repo.dig("rollup", "status_counts", "blocked") == 1
' "$feature_json" "$repo_json"

echo "Workspace feature graph query tests: passed"
