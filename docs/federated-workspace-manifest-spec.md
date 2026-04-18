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
```

## Required Fields

### Top-level

- `schema_version` (integer): currently must equal `1`.
- `workspace_id` (string): lowercase identifier matching `^[a-z0-9][a-z0-9_-]*$`.
- `repos` (array): must include at least one repository entry.

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
- Future schema changes should increment `schema_version` and preserve v1 parsing behavior where practical.
