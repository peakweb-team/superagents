# Federated Multi-Repo Cross-Language Guide

This guide covers the operator workflow for federated multi-repo mode delivered by issues [#86](https://github.com/peakweb-team/pw-agency-agents/issues/86), [#87](https://github.com/peakweb-team/pw-agency-agents/issues/87), [#88](https://github.com/peakweb-team/pw-agency-agents/issues/88), [#89](https://github.com/peakweb-team/pw-agency-agents/issues/89), and [#90](https://github.com/peakweb-team/pw-agency-agents/issues/90).

It is intended for programs that span heterogeneous repositories (for example Solidity + Terraform + TypeScript + Kotlin) while preserving repo-local ownership.

## 1) Decision Guide: Federated Mode vs Turborepo-Style Single Repo

Use this quick decision matrix:

| Program shape | Preferred mode | Why |
| --- | --- | --- |
| One JavaScript/TypeScript repository with many packages and one CI policy | Turborepo-style single-repo orchestration | Package graph and workspace dependency management are primary concerns. |
| Multiple repositories with different languages, runtimes, and build systems | Federated multi-repo mode | Control plane is workspace-level while execution remains repo-local. |
| Shared feature delivery where each repo must keep its own issue tracking and release policy | Federated multi-repo mode | `feature_id` links cross-repo work without collapsing ownership boundaries. |

Federated mode is explicitly not a replacement for Turborepo/Nx package orchestration inside a single Node.js repository.

## 2) Clean Workspace Setup (Reproducible)

From a clean workspace root:

```bash
mkdir -p /tmp/superagents-federated-demo
cd /tmp/superagents-federated-demo

# Bring in a starter manifest and adapt repo remotes/paths for your org.
cp /path/to/pw-agency-agents/docs/examples/workspace-manifests/superagents.workspace.yaml ./superagents.workspace.yaml

# Validate manifest contract before orchestration.
/path/to/pw-agency-agents/scripts/validate-workspace-manifest.sh ./superagents.workspace.yaml
```

Expected behavior:

- Validation exits `0` and prints one success line per manifest path.
- Failures include deterministic field pointers (for example `$.repos[1].issue_backend.project_id`).

## 3) End-To-End Walkthrough: One Feature Across Infra + Backend + Web/Mobile

The shipped fixture `tests/fixtures/workspace-manifests/valid/feature-graph-multi-repo.yaml` models one feature (`rollout-bridge`) spanning backend, infra, and web repositories with cross-repo dependency links.

### 3.1 Feature Rollup Query

```bash
./scripts/query-workspace-feature-graph.sh \
  tests/fixtures/workspace-manifests/valid/feature-graph-multi-repo.yaml \
  --feature-id rollout-bridge
```

Expected JSON contract highlights:

- `view: "feature"`
- `feature_id: "rollout-bridge"`
- `rollup.overall_status` and `rollup.progress_pct`
- `rollup.blocking` with blocker ids/reasons
- `rollup.execution_order` with deterministic `sequence` and `wave`
- `rollup.gate_status` counts (`blocked`, `ready`, `running`, `waiting_on_signal`, `satisfied`)
- `by_repo[]` rollups for each participating repo

### 3.2 Repo Ownership View

```bash
./scripts/query-workspace-feature-graph.sh \
  tests/fixtures/workspace-manifests/valid/feature-graph-multi-repo.yaml \
  --view repo --repo-id web --feature-id rollout-bridge
```

Use this view for repo-local planning while keeping feature context:

- returns only `web` tasks
- retains cross-repo gate/dependency evaluation from the full feature graph
- includes repo integration expectations (for example `integration.expected_issue_repo`)

### 3.3 GitHub Mapping View (Issues + Project Rollup)

```bash
./scripts/query-workspace-feature-graph.sh \
  tests/fixtures/workspace-manifests/valid/feature-graph-multi-repo.yaml \
  --view integration --feature-id rollout-bridge
```

This view is the source of truth for:

- feature-level project rollup mapping (`feature_mapping.github.project`)
- child issue linkage (`feature_mapping.github.child_issue_links`)
- task-level issue/PR/project item mappings (`tasks[].mapping.github`)
- retry-safe sync metadata (`rollup.sync.dedupe_keys`)

### 3.4 Dependency Gates and Deterministic Execution Ordering

Execution order:

```bash
./scripts/query-workspace-feature-graph.sh \
  tests/fixtures/workspace-manifests/valid/feature-graph-multi-repo.yaml \
  --view execution-order --feature-id rollout-bridge
```

Gate status:

```bash
./scripts/query-workspace-feature-graph.sh \
  tests/fixtures/workspace-manifests/valid/feature-graph-multi-repo.yaml \
  --view gate-status --feature-id rollout-bridge
```

Operator rule:

- run tasks in `execution_order` sequence/wave order
- only dispatch tasks whose gate state is `ready`
- treat `blocked` and `waiting_on_signal` as non-dispatchable until blockers clear

### 3.5 Per-Repo Policy Plugin Resolution (Heterogeneous Toolchains)

```bash
./scripts/query-workspace-feature-graph.sh \
  tests/fixtures/workspace-manifests/valid/policy-plugins-heterogeneous.yaml \
  --view policy --feature-id policy-rollout
```

Policy view guarantees:

- resolution order is deterministic: first supported `policy_refs` entry, then toolchain fallback, then default plugin
- phase contract is stable: `preflight` -> `build` -> `test` -> `publish`
- violations are isolated to owning repo/task

## 4) Operational Playbook

### 4.1 Issue Routing

1. Set `repos[].issue_backend` per repo (`repo_issues`, `github_project`, `external_tracker`, or `none`).
2. For GitHub issue-backed repos, set the canonical repo in `issue_backend.repo`.
3. Populate `features[].tasks[].integration.github.issue` for created/linked issues.
4. Use integration view to audit mapping coverage and dedupe keys before retrying sync.

### 4.2 Project Rollups

1. Set `features[].integration.github.project` for the feature rollup target.
2. Track explicit feature-to-child issue links in `child_issue_links`.
3. Re-run integration view after sync attempts; treat `sync.status: error|partial` as actionable.

### 4.3 Dependency Gates

1. Declare dependency edges via `parent_ids`, `child_ids`, and `blocked_by_ids`.
2. Use `--view gate-status` to identify `ready_task_ids` for dispatch.
3. Use `--view execution-order` to preserve deterministic order when multiple tasks become ready.
4. After status changes, re-run queries instead of manually inferring graph state.

## 5) Migration and Backward Compatibility

Federated support is additive and preserves existing repo-centric workflows.

- Existing repositories can remain repo-local with no `features` block.
- Existing issue routing remains valid (`repo_issues`, external tracker mappings, or `none`).
- Feature graph/query views are optional until a workspace adds `features`.
- Mixed adoption is supported: one workspace can onboard only selected repos/features first.
- No single language or build system is required; orchestration remains toolchain-agnostic.

Recommended migration path:

1. Start with `schema_version: 1`, `workspace_id`, and `repos` only.
2. Validate with `validate-workspace-manifest.sh` until clean.
3. Add one `feature_id` with a minimal task graph and verify `feature`, `repo`, and `integration` views.
4. Add dependency gates and confirm `gate-status` + `execution-order` behavior.
5. Add `policy_refs` per repo as needed and verify `policy` output.

## 6) API/CLI Contract Notes

`query-workspace-feature-graph.sh` is the CLI entrypoint for the same deterministic JSON contract consumed by automation.

Stable view names:

- `feature`
- `repo`
- `integration`
- `execution-order`
- `gate-status`
- `policy`

All views include `api_version: 1` and `workspace_id` for explicit contract/version handling.
