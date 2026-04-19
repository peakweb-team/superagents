#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALIDATOR="$ROOT_DIR/scripts/validate-workspace-manifest.sh"
QUERY="$ROOT_DIR/scripts/query-workspace-feature-graph.sh"
MANIFEST_FIXTURE="$ROOT_DIR/tests/fixtures/workspace-manifests/valid/federated-triple-stack.yaml"
FEATURE_FIXTURE="$ROOT_DIR/tests/fixtures/workspace-manifests/valid/feature-graph-multi-repo.yaml"
POLICY_FIXTURE="$ROOT_DIR/tests/fixtures/workspace-manifests/valid/policy-plugins-heterogeneous.yaml"

feature_json="$(mktemp)"
repo_json="$(mktemp)"
integration_json="$(mktemp)"
execution_json="$(mktemp)"
gate_json="$(mktemp)"
policy_json="$(mktemp)"
trap 'rm -f "$feature_json" "$repo_json" "$integration_json" "$execution_json" "$gate_json" "$policy_json"' EXIT

"$VALIDATOR" "$MANIFEST_FIXTURE" >/dev/null

"$QUERY" "$FEATURE_FIXTURE" --feature-id rollout-bridge >"$feature_json"
"$QUERY" "$FEATURE_FIXTURE" --view repo --repo-id web --feature-id rollout-bridge >"$repo_json"
"$QUERY" "$FEATURE_FIXTURE" --view integration --feature-id rollout-bridge >"$integration_json"
"$QUERY" "$FEATURE_FIXTURE" --view execution-order --feature-id rollout-bridge >"$execution_json"
"$QUERY" "$FEATURE_FIXTURE" --view gate-status --feature-id rollout-bridge >"$gate_json"
"$QUERY" "$POLICY_FIXTURE" --view policy --feature-id policy-rollout >"$policy_json"

ruby -rjson -e '
  feature = JSON.parse(File.read(ARGV[0]))
  repo = JSON.parse(File.read(ARGV[1]))
  integration = JSON.parse(File.read(ARGV[2]))
  execution = JSON.parse(File.read(ARGV[3]))
  gate = JSON.parse(File.read(ARGV[4]))
  policy = JSON.parse(File.read(ARGV[5]))

  [feature, repo, integration, execution, gate, policy].each do |payload|
    raise "expected api_version 1" unless payload["api_version"] == 1
    raise "expected workspace_id" unless payload["workspace_id"].is_a?(String) && !payload["workspace_id"].empty?
  end

  raise "expected feature view" unless feature["view"] == "feature"
  raise "expected rollout-bridge feature" unless feature["feature_id"] == "rollout-bridge"
  raise "expected by_repo rollups" unless feature["by_repo"].is_a?(Array) && feature["by_repo"].length == 3
  raise "expected execution order in feature rollup" unless feature.dig("rollup", "execution_order").is_a?(Array)
  raise "expected gate-status rollup in feature view" unless feature.dig("rollup", "gate_status", "state_counts").is_a?(Hash)

  raise "expected repo view" unless repo["view"] == "repo"
  raise "expected web repo id" unless repo["repo_id"] == "web"
  raise "expected expected_issue_repo" unless repo.dig("integration", "expected_issue_repo") == "example/web"

  raise "expected integration view" unless integration["view"] == "integration"
  raise "expected integration project mapping" unless integration.dig("feature_mapping", "github", "project", "project_id") == "PVT_kwDOXYZ123"
  raise "expected child issue links" unless integration.dig("feature_mapping", "github", "child_issue_links").is_a?(Array)
  raise "expected sync dedupe keys" unless integration.dig("rollup", "sync", "dedupe_keys").is_a?(Array)

  raise "expected execution-order view" unless execution["view"] == "execution-order"
  expected_order = ["api-prepare", "infra-gates", "ops-signoff", "web-release", "web-smoke"]
  actual_order = execution.fetch("execution_order").map { |row| row.fetch("task_id") }
  raise "expected deterministic execution order" unless actual_order == expected_order

  raise "expected gate-status view" unless gate["view"] == "gate-status"
  raise "expected ready task ids" unless gate.dig("gate_status", "ready_task_ids") == ["ops-signoff"]
  raise "expected waiting_on_signal count" unless gate.dig("gate_status", "state_counts", "waiting_on_signal") == 1

  raise "expected policy view" unless policy["view"] == "policy"
  raise "expected two repos in policy view" unless policy.fetch("repos").length == 2
  raise "expected deterministic policy repo ordering" unless policy.fetch("repos").map { |row| row.fetch("repo_id") } == ["infra", "web"]
  web_repo = policy.fetch("repos").find { |row| row.fetch("repo_id") == "web" }
  raise "expected node plugin resolution" unless web_repo.dig("resolution", "plugin_id") == "policy://node/pnpm-v1"
' "$feature_json" "$repo_json" "$integration_json" "$execution_json" "$gate_json" "$policy_json"

echo "Federated cross-language docs validation: passed"
