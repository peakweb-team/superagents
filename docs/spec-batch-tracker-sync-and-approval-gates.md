# Batch Tracker Sync And Approval Gates

This document defines the Milestone 4 contract for issue `#75`:

- [#75 Milestone 4: Add Bulk Tracker Sync And Approval Gates For Spec Batches](https://github.com/peakweb-team/pw-agency-agents/issues/75)

It extends:

- the single-item spec-builder baseline in [`docs/spec-builder-contract.md`](./spec-builder-contract.md) from issue `#68`
- the batch planning artifact model in [`docs/spec-batch-planning-contract.md`](./spec-batch-planning-contract.md) from issue `#76`
- the portfolio decomposition workflow in [`docs/portfolio-to-spec-decomposition-workflow.md`](./portfolio-to-spec-decomposition-workflow.md) from issue `#74`
- fallback semantics in [`docs/capability-fallback-behavior.md`](./capability-fallback-behavior.md)

## Why This Exists

Batch planning should not create tracker noise.

Teams need an explicit review and authorization boundary before a multi-item create/update run writes into GitHub Issues, Jira, or equivalent systems.

This contract adds that boundary while keeping reruns idempotent and preserving #68 single-item behavior.

## Compatibility Rules

The following remain unchanged:

- #68 single-item workflow semantics and handoff states
- #74 planning-batch decomposition and grouped artifact generation
- #76 item-scoped readiness, decisions, and deterministic rerun behavior

This contract is additive:

- single-item sync may continue with existing behavior
- batch tracker sync introduces explicit pre-write planning and approval gates

## Batch Tracker Sync Lifecycle

Batch tracker synchronization has four explicit phases.

### Phase 1: Build Planned Writes (Dry Run)

For each item in a batch run, compute a planned tracker action:

- `create`: no linked tracker record exists for the canonical item lineage
- `update`: linked tracker record exists and content drift is material
- `skip`: no material tracker change needed

Dry-run output should be written to:

- `.agency/specs/batches/<epic-slug>/<milestone-slug-or-unscoped>/<batch-key>/tracker-sync-plan.yaml`

Minimum per-item plan fields:

- `item_id`
- `item_slug`
- `proposed_action` (`create`, `update`, `skip`)
- `idempotency_key`
- `tracker_locator` (when known, such as issue number/key/url)
- `change_summary`
- `status` (`pending-approval`, `ready-to-apply`, `applied`, `failed`, `skipped`)

### Phase 2: Reviewer Gate

Before any write:

- reviewer validates scope/quality for planned tracker operations
- reviewer confirms no low-quality or duplicate ticket payloads are queued
- reviewer may change planned actions (for example force `skip` on low-value updates)

Expected reviewer decision is recorded in:

- `tracker-sync-review.md`

### Phase 3: Operator Approval Gate

After reviewer sign-off and before provider writes:

- operator explicitly approves execution
- operator confirms provider/project targeting (repo/project key, milestone mapping)
- operator confirms safety constraints (rate limits, labeling policy, assignment policy)

No batch create/update operation should run without explicit operator approval.

Required operator approval artifact:

- `.agency/specs/batches/<epic-slug>/<milestone-slug-or-unscoped>/<batch-key>/tracker-sync-approval.yaml`
- minimum fields:
  - `approval_id` (stable approval record id)
  - `batch_key`
  - `approver_id`
  - `approved_at` (timestamp)
  - `decision` (`approved` or `rejected`)
  - `comment` (optional)
  - `approval_nonce` (or equivalent integrity marker)

Execution enforcement requirements:

- apply phase must look up `tracker-sync-approval.yaml` for the current `batch-key` before any provider write
- if approval artifact is missing, malformed, or not `decision: approved`, reject batch create/update execution
- approval artifacts should be treated as immutable decision records and retained with the batch bundle for auditability

### Phase 4: Apply Writes And Record Results

Execute approved writes and persist one result ledger:

- `tracker-sync-results.yaml`

Minimum per-item result fields:

- `item_id`
- `item_slug`
- `attempted_action`
- `outcome` (`created`, `updated`, `skipped`, `failed`)
- `tracker_locator`
- `failure_reason` (when failed)
- `retry_hint` (when failed)

## Idempotency Rules For Reruns

Reruns of the same `batch-key` must avoid duplicate tracker items.

### Stable Identity Requirements

- `item_slug` remains the canonical lineage key
- each item write uses a deterministic `idempotency_key` derived from stable batch and item identity
- if a tracker record already exists for that key or explicit cross-link, use `update` or `skip`, not `create`

### Duplicate-Prevention Requirements

- never `create` when an authoritative locator is already linked
- never emit multiple create operations for the same `(batch-key, item_slug)` in one apply phase
- when locator lookup is ambiguous, block that item with explicit manual resolution guidance instead of guessing

### Material-Change Threshold

`update` should run only for material deltas (scope, acceptance criteria, handoff state, dependencies, or risk posture), not trivial wording edits.

## Grouped Epic/Milestone Assignment Behavior

Where provider supports grouping:

- map batch epic/milestone metadata into provider-native fields
- keep item-level ticket identity independent from group assignment metadata

Where provider does not support grouping:

- preserve batch grouping in local artifacts
- include equivalent grouping text labels in ticket body/labels when safe
- do not claim provider-native grouping was applied if only local grouping exists

## Partial Failure Handling And Retry Guidance

Batch writes may partially succeed.

Required behavior:

- report per-item outcomes (`created`, `updated`, `skipped`, `failed`)
- do not collapse partial success into one opaque batch result
- continue safe writes for unrelated items when one item fails
- provide concrete retry guidance for failed items in `tracker-sync-results.yaml` and `review.md`

Retry guidance should include:

- whether failure is safe to retry automatically
- what human fix is required first (permission, required field, invalid transition, duplicate ambiguity)
- the exact item ids/slugs safe for the next retry attempt

## Fallback Alignment

When capabilities degrade:

- follow `warn`, `manual`, and `fail` semantics from [`docs/capability-fallback-behavior.md`](./capability-fallback-behavior.md)
- preserve item-scoped fallback outcomes for batch runs
- keep direct-brief/local-spec path available when tracker create/update is unavailable and project policy allows it

Manual fallback remains valid when:

- writes are blocked by permissions but human operators can safely complete updates in the tracker

Fail mode remains required when:

- no safe automated or manual path can produce truthful tracker synchronization claims

## Acceptance Criteria Coverage For #75

- Operator can review planned writes before execution:
  - see `Phase 1: Build Planned Writes (Dry Run)`, `Phase 2: Reviewer Gate`, and `Phase 3: Operator Approval Gate`
- Rerunning the same batch does not create duplicate tracker items:
  - see `Idempotency Rules For Reruns`
- Partial provider failure is surfaced clearly with retry guidance:
  - see `Phase 4: Apply Writes And Record Results` and `Partial Failure Handling And Retry Guidance`
- Capability fallback behavior remains aligned with existing contracts:
  - see `Fallback Alignment`
