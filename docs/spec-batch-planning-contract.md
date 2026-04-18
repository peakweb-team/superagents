# Batch Spec Planning Contract And Artifact Model

This document defines the Milestone 4 contract for issue `#76`:

- [#76 Milestone 4: Define Batch Spec Planning Contract And Artifact Model](https://github.com/peakweb-team/pw-agency-agents/issues/76)

It extends, and does not replace, the single-item spec-builder contract in [`docs/spec-builder-contract.md`](./spec-builder-contract.md) from issue `#68`.

It builds on:

- roadmap scope for Milestone 4 / Epic 11 in [`ROADMAP.md`](../ROADMAP.md)
- capability semantics in [`docs/external-capability-model.md`](./external-capability-model.md)
- fallback semantics in [`docs/capability-fallback-behavior.md`](./capability-fallback-behavior.md)
- generated artifact reviewability expectations in [`docs/generated-skill-layout.md`](./generated-skill-layout.md)
- operational decomposition workflow in [`docs/portfolio-to-spec-decomposition-workflow.md`](./portfolio-to-spec-decomposition-workflow.md)
- batch tracker sync and approval behavior in [`docs/spec-batch-tracker-sync-and-approval-gates.md`](./spec-batch-tracker-sync-and-approval-gates.md)

## Why This Exists

Issue `#68` defines the pre-implementation flow for a single spec artifact.

Real sprint planning often starts from one epic objective and yields multiple implementation-ready specs.

This contract defines how batch planning should produce that multi-spec output deterministically, reviewably, and without breaking single-item behavior.

## Compatibility With #68 Single-Item Flow

The following #68 semantics are unchanged:

- single-item direct-brief path still supports `.agency/specs/<slug>.md`
- canonical handoff states remain `ready-for-build`, `needs-clarification`, and `blocked`
- per-item spec quality gate remains the minimum spec package from [`docs/spec-builder-contract.md`](./spec-builder-contract.md)
- tracker-backed, direct-brief, and dual-path storage-of-record behavior remain valid

Batch planning is an additive mode.

If intake contains exactly one work item, the system may use single-item behavior only and may omit batch-group artifacts.

## Batch Intake Model

A batch planning intake object must be explicit, reviewable, and durable.

### Required Intake Fields

- `epic_objective`
  - concise objective statement for the planning batch
- `candidate_work_items`
  - list of candidate items to decompose/specify
- `constraints`
  - delivery, policy, sequencing, or resource constraints that materially affect decomposition

### Recommended Intake Fields

- `epic_id` or stable external reference
- `milestone` (or sprint/release label)
- `planning_window` (for example `2026-sprint-09`)
- `source_refs` (tickets, docs, links)
- `default_assumptions` that apply broadly unless item-overridden

### Candidate Work Item Minimum Shape

Each candidate work item should include:

- `item_id` (stable within batch)
- `title`
- `problem_or_outcome`
- `initial_scope_notes`
- `known_dependencies` (optional)
- `risk_flags` (optional)

## Parent/Child Decomposition And Dependency Ordering

Batch decomposition must create a parent/child map from epic objective to implementable item specs.

### Decomposition Rules

- each generated item has exactly one parent epic objective for the current batch
- child items may reference another child item as a dependency, but not as an ownership parent
- decomposition must produce independently reviewable item-level acceptance criteria
- items that are too large or ambiguous should be split before handoff

### Dependency Rules

- dependencies must be represented as a directed acyclic graph (DAG)
- cycles are not allowed; cyclic items must be marked `blocked` until resolved
- ordering should use topological sort with stable tie-breakers
- stable tie-breaker for equal dependency depth: normalized item slug ascending

### Sequencing Output

The batch output should include:

- dependency edges (`from_item` -> `to_item`)
- ordered execution waves (`wave: 0, 1, 2...`)
- per-item `depends_on` and `blocks` sets

## Artifact Layout For Multi-Spec Runs

The layout must support grouped review by epic/milestone while preserving per-item canonical specs.

### Canonical Per-Item Spec Location (Unchanged)

Each item in a batch still maps to the single-item canonical spec lineage:

- `.agency/specs/<item-slug>.md`

If scope/acceptance materially changes, increment item `revision` using #68 semantics.

### Batch Grouping Bundle

When more than one item is planned in one run, write a grouped bundle under:

- `.agency/specs/batches/<epic-slug>/<milestone-slug-or-unscoped>/<batch-key>/`

Recommended bundle contents:

- `intake.yaml`
  - normalized batch intake and source references
- `decomposition.yaml`
  - parent/child mapping, DAG edges, wave ordering
- `decisions.yaml`
  - confirmed/assumed/unresolved decisions, item-scoped
- `review.md`
  - human review summary and readiness table
- `index.md`
  - operator-facing summary/index with suggested execution order and links to canonical per-item specs
- `items/<order>-<item-slug>.md`
  - item summary sheet with links to canonical per-item spec files

`batch-key` should be stable for reruns of the same planning unit (for example epic + milestone + planning window).

## Item-Scoped Decisions, Assumptions, And Unresolved Handling

Batch planning must not be all-or-nothing.

### Per-Item Decision Ledger

`decisions.yaml` should represent decisions at item scope first:

- `items.<item-id>.confirmed[]`
- `items.<item-id>.assumed[]`
- `items.<item-id>.unresolved[]`

Batch-level entries are allowed only for truly shared decisions:

- `batch.confirmed[]`
- `batch.assumed[]`
- `batch.unresolved[]`

### Readiness And Blocking Semantics

Each item gets its own handoff state:

- `ready-for-build`: implementation for that item may proceed
- `needs-clarification`: item is not ready; other ready items may proceed
- `blocked`: external dependency/risk gate blocks that item

Batch-level summary should aggregate, not override, item states.

Example summary states:

- `fully-ready` (all items `ready-for-build`)
- `partially-ready` (mixed item states)
- `blocked` (no item is currently build-ready)

## Reviewability Contract

Batch output must be reviewable as normal repository artifacts.

`review.md` for batch runs should include:

- epic objective and planning window
- item table with slug, wave, state, and dependency summary
- assumptions and unresolved decisions grouped by item
- explicit links to each canonical `.agency/specs/<item-slug>.md`
- rerun delta summary (what changed from previous batch revision)

`index.md` for batch runs should include:

- concise run summary for operators
- suggested execution order by wave
- quick state rollup for each item (`ready-for-build`, `needs-clarification`, `blocked`)

This keeps planning decisions auditable without requiring runtime logs.

## Rerun And Idempotency Expectations

Batch planning must be deterministic enough for clean diffs.

### Idempotent Regeneration Rules

- rerunning with unchanged normalized intake should preserve item slugs and ordering
- rerunning the same `batch-key` should update artifacts in place and increment `batch_revision`
- unchanged items should not receive artificial revision bumps
- only items with material scope/acceptance changes should increment item `revision`

### Determinism Requirements

- normalization of epic/milestone/item slugs should follow #68 slug rules
- dependency ordering should be reproducible from the same DAG and tie-breakers
- per-item unresolved status should not cascade to unrelated items

## Fallback Alignment

Batch planning should follow capability fallback semantics from [`docs/capability-fallback-behavior.md`](./capability-fallback-behavior.md), with item-scoped impact where possible.

- missing capability for one item path should degrade that item first
- only intake-wide capability failures should block the full batch
- manual-mode steps may apply to specific items without marking unrelated items unresolved

## Tracker Synchronization Alignment

This contract defines planning artifacts and item readiness semantics.

Bulk tracker create/update execution for batch runs is defined separately in [`docs/spec-batch-tracker-sync-and-approval-gates.md`](./spec-batch-tracker-sync-and-approval-gates.md), including:

- dry-run planning of proposed writes
- reviewer/operator approval gates before writes
- idempotency expectations for reruns
- per-item result reporting for partial failure handling

## Acceptance Criteria Coverage For #76

- Batch planning contract is explicit and reviewable:
  - see `Batch Intake Model`, `Parent/Child Decomposition And Dependency Ordering`, `Artifact Layout For Multi-Spec Runs`, `Reviewability Contract`
- Contract preserves compatibility with #68 single-item flow:
  - see `Compatibility With #68 Single-Item Flow` and `Canonical Per-Item Spec Location (Unchanged)`
- Artifact model supports grouped review by epic/milestone:
  - see `Batch Grouping Bundle` and `review.md` expectations in `Reviewability Contract`
- Unresolved decisions can be item-scoped (not all-or-nothing):
  - see `Per-Item Decision Ledger` and `Readiness And Blocking Semantics`

## MVP Boundary

This contract does not require:

- runtime/tooling implementation of batch execution
- automatic reprioritization algorithms
- provider-specific decomposition schemas

It does require:

- explicit batch intake shape
- deterministic decomposition and dependency ordering semantics
- grouped multi-spec artifact model by epic/milestone
- item-scoped unresolved handling
- compatibility with #68 single-item behavior
