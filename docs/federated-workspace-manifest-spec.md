# Federated Workspace Manifest Specification

This document defines the workspace manifest contract for issue `#86`:

- [#86 Spec: Workspace Manifest For Federated Multi-Repo Projects](https://github.com/peakweb-team/pw-agency-agents/issues/86)

The goal is to coordinate multiple repositories under one workspace-level control plane across different languages and build systems.

This is explicitly **not** a Turborepo/Nx single-stack package-graph format.

## Manifest File Name

Workspace manifests should be stored at the workspace root as:

- `superagents.workspace.yaml`

## Schema

The canonical JSON schema lives at:

- `docs/schemas/superagents.workspace.schema.json`

Current schema contract version:

- `schema_version: 1`

## Top-Level Shape

```yaml
schema_version: 1
workspace_id: atlas-x
# optional
description: Cross-language federated delivery workspace
repos:
  - id: protocol-core
    remote: git@github.com:example/protocol-core.git
    default_branch: main
    role: protocol
    language: solidity
    runtime: evm
    build_system: foundry
    issue_backend:
      type: repo_issues
      repo: example/protocol-core
    ownership:
      team: protocol
      owners:
        - team-protocol
    policy_refs:
      - policy://solidity/foundry-v1

# optional cross-repo feature graph
features:
  - feature_id: crosschain-wallet-v2
    title: Cross-chain wallet v2
    integration:
      github:
        project:
          project_id: PVT_kwDOXYZ123
        child_issue_links:
          - task_id: protocol-risk-review
            repo: example/protocol-core
            issue_number: 201
    tasks:
      - id: protocol-risk-review
        feature_id: crosschain-wallet-v2
        repo_id: protocol-core
        title: Finalize protocol risk review
        status: done
        integration:
          github:
            issue:
              repo: example/protocol-core
              number: 201
        child_ids:
          - infra-rollout-plan
```

## Required Fields

### Top-level

- `schema_version` (integer): currently must equal `1`.
- `workspace_id` (string): lowercase identifier matching `^[a-z0-9][a-z0-9_-]*$`.
- `repos` (array): must include at least one repository entry.
- `features` (array): optional. When provided, must include at least one cross-repo feature.

### Per-repo

- `id` (string): repo identifier matching `^[a-z0-9][a-z0-9_-]*$`; must be unique within `repos`.
- `path` or `remote` (string): exactly one must be provided.
- `default_branch` (string): repo default branch.
- `role` (string): role in the federated program (for example `protocol`, `devops`, `webapp`, `mobile`).
- `build_system` (string): repo-native build/test toolchain (for example `foundry`, `terraform`, `pnpm-workspace`, `gradle`).
- `issue_backend` (object): issue/project tracking mapping for the repo.

### Optional Per-repo

- `language` (string)
- `runtime` (string)
- `ownership.team` (string)
- `ownership.owners` (string array)
- `policy_refs` (string array)

### Optional Cross-Repo Features

- `features[].feature_id` (string): feature identifier matching `^[a-z0-9][a-z0-9_-]*$`.
- `features[].title` (string): human-readable feature title.
- `features[].description` (string): optional feature context.
- `features[].tasks` (array): at least one task, each with:
  - `id` (string): work item id matching `^[a-z0-9][a-z0-9_-]*$`.
  - `feature_id` (string): must match parent `features[].feature_id`.
  - `repo_id` (string): must reference one of `repos[].id`.
  - `title` (string)
  - `status` (enum): `todo`, `in_progress`, `blocked`, `done`, `cancelled`.
  - optional `integration.github` mapping:
    - `issue.repo`, `issue.number`, `issue.node_id`, `issue.url`
    - `pull_requests[]` (`repo`, `number`, `url`)
    - `project_items[]` (`project_id`, `item_id`, `url`)
    - `sync` (`status`, `retry_count`, `last_error`, `last_attempt_at`, `dedupe_key`)
  - optional link arrays: `parent_ids`, `child_ids`, `blocked_by_ids`.

- `features[].integration.github` (optional):
  - `project` (`project_id`, `item_id`, `url`) for cross-repo GitHub Project rollups.
  - `child_issue_links[]` (`task_id`, `repo`, `issue_number`, `url`) for explicit feature <-> child issue mapping.
  - `sync` (`status`, `retry_count`, `last_error`, `last_attempt_at`, `dedupe_key`) for partial-failure/retry-safe sync state.

`parent_ids`/`child_ids` provide explicit parent-child work item links. `blocked_by_ids` provides dependency blockers used by rollup status queries.

## Issue Backend Contract

`issue_backend.type` is required and must be one of:

- `repo_issues`
- `github_project`
- `external_tracker`
- `none`

Additional requirements by type:

- `repo_issues`: requires `issue_backend.repo`
- `github_project`: requires `issue_backend.project_id`
- `external_tracker`: requires `issue_backend.tracker` and non-empty `issue_backend.mapping`
- `none`: no additional required fields

## Validation CLI

Use the built-in validator:

```bash
./scripts/validate-workspace-manifest.sh superagents.workspace.yaml
```

The validator checks schema contract rules and reports actionable field-level errors.

## Feature Graph Query CLI/API

Query feature-level rollups (JSON output suitable for CLI automation or API ingestion):

```bash
./scripts/query-workspace-feature-graph.sh superagents.workspace.yaml --feature-id crosschain-wallet-v2
```

Query repo-level rollups across all features:

```bash
./scripts/query-workspace-feature-graph.sh superagents.workspace.yaml --view repo --repo-id web-console
```

Query repo-level rollups scoped to one feature:

```bash
./scripts/query-workspace-feature-graph.sh superagents.workspace.yaml --view repo --repo-id web-console --feature-id crosschain-wallet-v2
```

Query GitHub integration mapping rollups for one feature:

```bash
./scripts/query-workspace-feature-graph.sh superagents.workspace.yaml --view integration --feature-id crosschain-wallet-v2
```

Query deterministic execution ordering for one feature:

```bash
./scripts/query-workspace-feature-graph.sh superagents.workspace.yaml --view execution-order --feature-id crosschain-wallet-v2
```

Query per-task dependency gate status for one feature:

```bash
./scripts/query-workspace-feature-graph.sh superagents.workspace.yaml --view gate-status --feature-id crosschain-wallet-v2
```

Rollups include aggregate child progression (`progress_pct`, status counts), blocking state (`blocking.blocked`, blocker details), deterministic dependency graph metadata (`dependency_graph`), gate-state rollups (`blocked`, `ready`, `running`, `waiting_on_signal`, `satisfied`), and deterministic execution ordering (`execution_order` with `sequence` + `wave`).

Execution-order tie-breaking is deterministic for equal dependency depth: task id ascending.

Failure and recovery are deterministic:

- dependency cycles fail validation and must be resolved before execution-order views are considered valid.
- gate blockers include explicit reasons (`status_blocked`, `waiting_on_dependency`, `dependency_cycle`) and blocking task ids where applicable.
- recovery path is resumable: update task status/dependency links, then re-run query views to compute the next ready set from the same rules.

## Error Message Examples

```text
Manifest validation failed for superagents.workspace.yaml:
  - $.workspace_id: must match ^[a-z0-9][a-z0-9_-]*$
  - $.repos[0]: must define exactly one of 'path' or 'remote'
  - $.repos[1].issue_backend.project_id: missing required key 'project_id'
```

## Heterogeneous Examples

Reference manifest examples are provided in:

- `docs/examples/workspace-manifests/superagents.workspace.yaml`

That example includes multiple repo types in one workspace:

- Solidity protocol repo (`foundry`)
- Terraform devops repo (`terraform`)
- TypeScript web repo (`pnpm-workspace`)
- Kotlin mobile repo (`gradle`)

### Minimal Node + Python + Terraform Example

```yaml
schema_version: 1
workspace_id: mercury
repos:
  - id: api
    remote: git@github.com:example/api.git
    default_branch: main
    role: backend
    language: python
    runtime: python3.12
    build_system: poetry
    issue_backend:
      type: repo_issues
      repo: example/api

  - id: app
    remote: git@github.com:example/app.git
    default_branch: main
    role: webapp
    language: typescript
    runtime: node20
    build_system: pnpm
    issue_backend:
      type: github_project
      project_id: PVT_kwDOXYZ123

  - id: infra
    path: ../infra
    default_branch: main
    role: devops
    language: hcl
    runtime: terraform
    build_system: terraform
    issue_backend:
      type: external_tracker
      tracker: jira
      mapping:
        project_key: INFRA
```

## Backward Compatibility Notes

- This is an additive, opt-in manifest contract.
- Existing repo-local workflows can continue without a workspace manifest.
- Existing workspace manifests that omit `features` remain valid.
- Future schema changes should increment `schema_version` and preserve v1 parsing behavior where practical.
