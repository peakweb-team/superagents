#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QUERY="$ROOT_DIR/scripts/query-workspace-feature-graph.sh"
FIXTURE="$ROOT_DIR/tests/fixtures/workspace-manifests/valid/feature-graph-multi-repo.yaml"

feature_json="$(mktemp)"
repo_json="$(mktemp)"
integration_json="$(mktemp)"
execution_order_json="$(mktemp)"
gate_status_json="$(mktemp)"
trap 'rm -f "$feature_json" "$repo_json" "$integration_json" "$execution_order_json" "$gate_status_json"' EXIT

"$QUERY" "$FIXTURE" --feature-id rollout-bridge >"$feature_json"
"$QUERY" "$FIXTURE" --view repo --repo-id web --feature-id rollout-bridge >"$repo_json"
"$QUERY" "$FIXTURE" --view integration --feature-id rollout-bridge >"$integration_json"
"$QUERY" "$FIXTURE" --view execution-order --feature-id rollout-bridge >"$execution_order_json"
"$QUERY" "$FIXTURE" --view gate-status --feature-id rollout-bridge >"$gate_status_json"

ruby -rjson -e '
  feature = JSON.parse(File.read(ARGV[0]))
  repo = JSON.parse(File.read(ARGV[1]))
  integration = JSON.parse(File.read(ARGV[2]))
  execution_order = JSON.parse(File.read(ARGV[3]))
  gate_status = JSON.parse(File.read(ARGV[4]))

  raise "expected feature view" unless feature["view"] == "feature"
  raise "expected feature id" unless feature["feature_id"] == "rollout-bridge"
  raise "expected blocked rollup status" unless feature.dig("rollup", "overall_status") == "blocked"
  raise "expected three repo rollups" unless feature["by_repo"].length == 3
  raise "expected blocked blocker count" unless feature.dig("rollup", "blocking", "blocker_count") == 3
  raise "expected ready gate count" unless feature.dig("rollup", "gate_status", "state_counts", "ready") == 1
  raise "expected waiting gate count" unless feature.dig("rollup", "gate_status", "state_counts", "waiting_on_signal") == 1
  raise "expected execution order task count" unless feature.dig("rollup", "execution_order").length == 5
  raise "expected feature integration mapping" unless feature.dig("integration", "mapping", "github", "project", "project_id") == "PVT_kwDOXYZ123"

  raise "expected repo view" unless repo["view"] == "repo"
  raise "expected repo id" unless repo["repo_id"] == "web"
  raise "expected two web tasks" unless repo["tasks"].length == 2
  raise "expected blocked repo rollup" unless repo.dig("rollup", "overall_status") == "blocked"
  raise "expected blocked status count" unless repo.dig("rollup", "status_counts", "blocked") == 1
  raise "expected waiting gate for repo rollup" unless repo.dig("rollup", "gate_status", "state_counts", "waiting_on_signal") == 1
  raise "expected expected_issue_repo in repo integration view" unless repo.dig("integration", "expected_issue_repo") == "example/web"

  raise "expected integration view" unless integration["view"] == "integration"
  raise "expected integration mapped issue tasks count" unless integration.dig("rollup", "mapped_issue_tasks") == 2
  raise "expected integration dedupe keys" unless integration.dig("rollup", "sync", "dedupe_keys").length == 2
  raise "expected per-repo integration rollups" unless integration["by_repo"].length == 3
  raise "expected integration task mapping payload" unless integration["tasks"].any? { |item| item["id"] == "api-prepare" && item.dig("mapping", "github", "issue", "number") == 101 }

  raise "expected execution-order view" unless execution_order["view"] == "execution-order"
  raise "expected no dependency cycles" unless execution_order.dig("dependency_graph", "has_cycles") == false
  expected_order = ["api-prepare", "infra-gates", "ops-signoff", "web-release", "web-smoke"]
  actual_order = execution_order["execution_order"].map { |item| item["task_id"] }
  raise "expected deterministic task order" unless actual_order == expected_order

  raise "expected gate-status view" unless gate_status["view"] == "gate-status"
  raise "expected ready task id" unless gate_status.dig("gate_status", "ready_task_ids") == ["ops-signoff"]
  raise "expected blocked state count" unless gate_status.dig("gate_status", "state_counts", "blocked") == 1
  raise "expected running state count" unless gate_status.dig("gate_status", "state_counts", "running") == 1
  raise "expected waiting state count" unless gate_status.dig("gate_status", "state_counts", "waiting_on_signal") == 1
  web_smoke = gate_status["tasks"].find { |item| item["task_id"] == "web-smoke" }
  raise "expected web-smoke task in gate status output" unless web_smoke
  raise "expected web-smoke waiting gate state" unless web_smoke["gate_state"] == "waiting_on_signal"
  raise "expected web-smoke blocking dependency" unless web_smoke["blockers"].any? { |entry| entry["blocking_task_id"] == "web-release" }
' "$feature_json" "$repo_json" "$integration_json" "$execution_order_json" "$gate_status_json"

echo "Workspace feature graph query tests: passed"
