# Project Integration Declaration Format

This document defines the proposed contract for issue `#18`:

- [#18 Define project integration declaration format](https://github.com/peakweb-team/pw-agency-agents/issues/18)

It builds on:

- the Claude-first MVP direction from issue `#29`
- the generated-skill layout contract in [`docs/generated-skill-layout.md`](./generated-skill-layout.md)
- the builder inventory workflow in [`docs/builder-inventory-workflow.md`](./builder-inventory-workflow.md)
- the builder questionnaire flow in [`docs/builder-questionnaire-flow.md`](./builder-questionnaire-flow.md)
- the external capability model in [`docs/external-capability-model.md`](./external-capability-model.md)
- the capability fallback contract in [`docs/capability-fallback-behavior.md`](./capability-fallback-behavior.md)
- the first-wave task-system fragment set in [`docs/task-system-provider-fragment-set.md`](./task-system-provider-fragment-set.md)
- the first-wave code-host/review fragment set in [`docs/code-host-review-provider-fragment-set.md`](./code-host-review-provider-fragment-set.md)

## Why This Exists

The external capability model defines *what* a generated skill may need.

This document defines how a project declares *which configured integration* satisfies those capabilities.

That declaration needs to be:

- repo-local
- human-reviewable
- compatible with builder output
- explicit about what is confirmed versus what is only assumed

Without this layer, generated skills would know the capability vocabulary but would still lack a stable project-level record of how those capabilities are satisfied.

## Design Goals

- keep the declaration close to the generated-skill metadata bundle
- separate capability semantics from provider selection
- support both external systems and local/direct workflow paths
- distinguish confirmed mappings from assumptions or unresolved gaps
- preserve enough detail for later regeneration and review

## Output Location

The project integration declaration should live at:

- `.agency/skills/superagents/integrations.yaml`

This keeps it inside the existing Superagents builder metadata root rather than scattering workflow configuration across unrelated files.

The file should be committed alongside:

- `manifest.yaml`
- `inventory.yaml`
- `decisions.yaml`
- `fragments.lock.yaml`
- `review.md`

## Core Model

The declaration format has two layers:

### 1. Provider Entries

These define the named integration targets available to the project.

Examples:

- a local direct-brief intake path
- GitHub Issues
- Jira
- GitHub Pull Requests
- CodeRabbit

### 2. Capability Bindings

These map canonical capabilities to one declared provider entry.

Examples:

- `task-intake.direct-brief` -> local direct-brief input
- `task-tracker.read` -> Jira
- `task-tracker.create` -> GitHub Issues
- `code-host.pr.open` -> GitHub
- `review-feedback.read` -> GitHub PR reviews

The provider entry says what the integration is.

The capability binding says what workflow job it satisfies.

## Canonical File Shape

The MVP declaration file should use YAML with this top-level shape:

```yaml
schema_version: 1
generated_by: skill-builder
generated_at: 2026-04-15T18:00:00Z
providers:
  local-direct-brief:
    provider: local
    kind: local
    decision_state: confirmed
    notes: Work may begin from a direct brief supplied at runtime.

  github:
    provider: github
    kind: external
    decision_state: confirmed
    notes: GitHub is the primary code host and issue system.

capability_bindings:
  task-intake.direct-brief:
    provider_ref: local-direct-brief
    support: full
    decision_state: confirmed

  task-tracker.lookup:
    provider_ref: github
    support: full
    decision_state: confirmed

  review-feedback.read:
    provider_ref: github
    support: partial
    decision_state: assumed
    fallback_mode: warn
    notes: Human review is confirmed, but bot-review coverage is still assumed.
```

This shape is intentionally small.

It should be easy to diff, hand-edit, and regenerate.

## Required Fields

### Top-Level Required Fields

#### `schema_version`

- Type: integer
- Required: yes
- MVP value: `1`
- Purpose: version the declaration contract

#### `generated_by`

- Type: string
- Required: yes
- Purpose: identify the builder or process that last wrote the file

#### `generated_at`

- Type: string
- Required: yes
- Format: ISO 8601 timestamp
- Purpose: record when the declaration was last generated

#### `providers`

- Type: object keyed by repo-local provider reference id
- Required: yes
- Purpose: define the integration targets available to the project

#### `capability_bindings`

- Type: object keyed by canonical capability id
- Required: yes
- Purpose: map each declared capability to a provider entry

## Provider Entry Fields

Each entry in `providers` should use a stable repo-local key such as `github`, `jira`, or `local-direct-brief`.

Required fields:

### `provider`

- Type: string
- Purpose: canonical provider label

Example values:

- `local`
- `github`
- `jira`
- `gitlab`
- `coderabbit`

### `kind`

- Type: enum string
- Allowed values:
  - `local`
  - `external`
- Purpose: distinguish local workflow paths from external configured systems

### `decision_state`

- Type: enum string
- Allowed values:
  - `confirmed`
  - `assumed`
  - `unresolved`
- Purpose: record how certain the builder is that this provider entry is valid for the project

### Optional Provider Fields

#### `label`

- Type: string
- Purpose: human-friendly display label when the provider name alone is too generic

#### `notes`

- Type: string
- Purpose: short explanation of relevant project-specific constraints

#### `source`

- Type: object
- Purpose: identify where the provider inference came from

Suggested nested fields:

- `type`
- `path`
- `detail`

#### `config_hint`

- Type: string
- Purpose: short reminder about the expected configured path without attempting auto-setup

Example values:

- `requires gh auth and repository access`
- `requires Jira MCP or CLI credentials outside Superagents`

## Capability Binding Fields

Each entry in `capability_bindings` is keyed by the canonical capability id from [`docs/external-capability-model.md`](./external-capability-model.md).

Required fields:

### `provider_ref`

- Type: string
- Required: yes
- Purpose: reference one entry from the `providers` map

### `support`

- Type: enum string
- Required: yes
- Allowed values:
  - `full`
  - `partial`
  - `unavailable`
- Purpose: describe the expected support level for that capability in this project

### `decision_state`

- Type: enum string
- Required: yes
- Allowed values:
  - `confirmed`
  - `assumed`
  - `unresolved`
- Purpose: record whether the capability binding is established, inferred, or still uncertain

Optional fields:

### `notes`

- Type: string
- Purpose: call out project-specific limitations or interpretation details

### `fallback`

- Type: string
- Purpose: short description of the safe alternate path if support is partial or unavailable

### `fallback_mode`

- Type: enum string
- Purpose: record the selected fallback behavior for that capability
- Allowed values:
  - `continue`
  - `warn`
  - `manual`
  - `fail`

### `warning`

- Type: string
- Purpose: short operator-facing warning when degraded support should remain visible but not block execution

### `manual_steps`

- Type: array of strings
- Purpose: list concrete human actions required when the capability falls back to manual mode

### `source`

- Type: object
- Purpose: record the evidence or decision that justified the binding

## Confirmed vs Assumed vs Unresolved

The declaration format must make certainty visible, not implicit.

### `confirmed`

Use when:

- repository evidence is strong enough
- or the user explicitly confirmed the provider mapping

Example:

- `task-tracker.read` is bound to `jira` because repeated Jira keys and workflow docs make it authoritative

### `assumed`

Use when:

- the builder has a reasonable default
- but the project did not fully confirm the mapping

Example:

- `review-feedback.read` is assumed to be satisfied by GitHub PR review because PR delivery is clear, but the exact review automation path is not

### `unresolved`

Use when:

- the workflow likely needs the capability
- but no safe provider mapping can yet be confirmed or assumed

Example:

- `delivery-status.read` is needed for completion gates, but no stable delivery-status source is confirmed yet

## Local / Direct Workflow Support

The declaration format must support workflows that do not begin with an external task system.

That means:

- local providers are valid first-class entries in `providers`
- `task-intake.direct-brief` may bind to a `kind: local` provider
- `task-intake.assumption-capture` may also bind to a local provider or generated-skill behavior record

Example:

```yaml
providers:
  local-direct-brief:
    provider: local
    kind: local
    decision_state: confirmed

capability_bindings:
  task-intake.direct-brief:
    provider_ref: local-direct-brief
    support: full
    decision_state: confirmed
```

This is a core MVP requirement, not an edge case.

## Compatibility With Builder Output

The declaration file should align with the existing metadata bundle.

### Relationship To `inventory.yaml`

- `inventory.yaml` records evidence and normalized signals
- `integrations.yaml` records the resulting provider-and-capability mapping

### Relationship To `decisions.yaml`

- `decisions.yaml` records the reasoning state of builder choices
- `integrations.yaml` records the concrete declared outcome for integration mapping

### Relationship To `manifest.yaml`

`manifest.yaml` should reference `integrations.yaml` as part of the generated metadata bundle so the declaration becomes part of the reviewable build artifact.

### Relationship To Generated Skills

Generated skills should rely on the declaration semantically, but they do not need to inline the entire mapping into `SKILL.md`.

The declaration file is the durable source of truth for provider-capability mapping inside the repo.

## Example Declaration

```yaml
schema_version: 1
generated_by: skill-builder
generated_at: 2026-04-15T18:00:00Z

providers:
  local-direct-brief:
    provider: local
    kind: local
    decision_state: confirmed
    notes: Direct bootstrap briefs are allowed for greenfield or exploratory work.
    source:
      type: builder-input
      detail: /agent-task <ticket-or-prompt>

  github:
    provider: github
    kind: external
    decision_state: confirmed
    notes: GitHub is the primary forge and issue system for this repository.
    source:
      type: repo-evidence
      path: .git/config
      detail: origin=github.com:peakweb-team/pw-agency-agents.git

  coderabbit:
    provider: coderabbit
    kind: external
    decision_state: assumed
    notes: Review automation appears active but the exact required review path still needs human confirmation.

capability_bindings:
  task-intake.direct-brief:
    provider_ref: local-direct-brief
    support: full
    decision_state: confirmed

  task-intake.assumption-capture:
    provider_ref: local-direct-brief
    support: full
    decision_state: confirmed

  task-tracker.lookup:
    provider_ref: github
    support: full
    decision_state: confirmed

  task-tracker.read:
    provider_ref: github
    support: full
    decision_state: confirmed

  task-tracker.create:
    provider_ref: github
    support: full
    decision_state: confirmed

  task-tracker.update:
    provider_ref: github
    support: full
    decision_state: confirmed

  code-host.pr.open:
    provider_ref: github
    support: full
    decision_state: confirmed

  code-host.pr.review-request:
    provider_ref: github
    support: full
    decision_state: confirmed

  review-feedback.read:
    provider_ref: coderabbit
    support: partial
    decision_state: assumed
    fallback_mode: warn
    fallback: Fall back to human PR review comments when CodeRabbit is unavailable.
```

## Unsupported Or Missing Bindings

This document defines the declaration shape, not the full fallback matrix.

For MVP:

- if a capability is unavailable, it may still appear in `capability_bindings` with `support: unavailable`
- if a workflow decision remains unresolved, the binding may use `decision_state: unresolved`
- fallback handling should be expressed with `fallback_mode` and optional `warning` or `manual_steps` fields
- the builder should not silently omit a required capability that materially affects workflow behavior

That explicit behavior keeps the declaration honest and aligns it with [`docs/capability-fallback-behavior.md`](./capability-fallback-behavior.md).

## Recommended Builder Behavior

When generating or regenerating `integrations.yaml`, the builder should:

1. infer likely providers from repository evidence and user input
2. confirm high-impact mappings through the questionnaire when needed
3. record whether each provider and binding is confirmed, assumed, or unresolved
4. keep provider reference ids stable across regenerations when the underlying mapping has not changed
5. produce deterministic YAML ordering to keep diffs reviewable

## MVP Boundary

This contract intentionally does not define:

- secrets or credentials storage
- how a provider is authenticated
- automatic installation or provisioning
- the complete provider-specific fallback policy for every missing capability

It does define:

- the repo-local file path
- the YAML shape
- the difference between provider entries and capability bindings
- the distinction between confirmed, assumed, and unresolved mappings
- compatibility with builder metadata and repo-local versioning
