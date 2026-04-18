# Portfolio-To-Spec Decomposition Workflow

This document defines the Milestone 4 workflow behavior for issue `#74`:

- [#74 Milestone 4: Add Portfolio-To-Spec Decomposition Workflow](https://github.com/peakweb-team/pw-agency-agents/issues/74)

It builds on:

- the single-item baseline in [`docs/spec-builder-contract.md`](./spec-builder-contract.md) from issue `#68`
- the batch artifact model in [`docs/spec-batch-planning-contract.md`](./spec-batch-planning-contract.md) from issue `#76`
- batch tracker sync and approval gates in [`docs/spec-batch-tracker-sync-and-approval-gates.md`](./spec-batch-tracker-sync-and-approval-gates.md) from issue `#75`
- fallback semantics in [`docs/capability-fallback-behavior.md`](./capability-fallback-behavior.md)

## Why This Exists

Issue `#68` defines how one brief becomes one implementation-ready spec.

Issue `#76` defines the multi-item artifact contract.

This workflow bridges them with an explicit planning-oriented execution path for sprint and portfolio kickoff where one intake run produces multiple candidate implementation specs with independent handoff states.

## Invocation Paths

Spec generation has two companion invocation paths.

### Path A: Single-Item (Unchanged From #68)

Use this path when intake represents one implementation item.

- input shape: one brief or one tracked task
- output: one canonical `.agency/specs/<slug>.md`
- no batch bundle required

### Path B: Planning-Batch (New In #74)

Use this path when intake represents a portfolio/sprint planning unit.

- input shape: batch planning object as defined in [`docs/spec-batch-planning-contract.md`](./spec-batch-planning-contract.md)
- output: many canonical `.agency/specs/<item-slug>.md` files plus one grouped batch bundle
- each item keeps independent acceptance criteria and handoff state

### Path Selection Rule

- if normalized intake has exactly one candidate implementation item, keep single-item behavior and batch artifacts are optional
- if normalized intake has more than one candidate implementation item, run planning-batch behavior

This preserves #68 compatibility while making multi-item planning explicit.

## Planning-Batch Workflow

### Step 1: Normalize Intake

Normalize the batch intake object into deterministic fields:

- `epic_objective`
- `candidate_work_items[]`
- `constraints`
- optional context (`epic_id`, `milestone`, `planning_window`, `source_refs`, `default_assumptions`)

Normalize slugs using #68 rules for all generated item lineages.

### Step 2: Decompose Into Candidate Implementation Items

For each candidate work item:

- split oversized or ambiguity-heavy items before spec drafting
- ensure each resulting item has one clear implementable outcome
- assign stable `item_id` and normalized `item_slug`
- attach parent epic linkage and candidate dependencies

If decomposition produces cycles in dependencies, mark involved items `blocked` until cycle resolution.

### Step 3: Generate Per-Item Minimum Spec Package

Generate one canonical spec lineage per item at:

- `.agency/specs/<item-slug>.md`

Each item spec must include the #68 minimum package:

- problem and desired outcome
- in-scope and out-of-scope boundaries
- acceptance criteria with testable completion conditions
- dependency and sequencing notes
- risk notes and open questions
- validation expectations and evidence requirements
- explicit handoff state (`ready-for-build`, `needs-clarification`, or `blocked`)

Each item must stand alone for implementation handoff.

### Step 4: Evaluate Independent Item Readiness

Readiness is per-item, not batch-wide.

- `ready-for-build`: this item may proceed
- `needs-clarification`: item-level questions remain; unrelated ready items may proceed
- `blocked`: external dependency/risk prevents safe handoff

Do not collapse mixed outcomes into one forced global state.

### Step 5: Produce Batch Summary / Index

For multi-item runs, write grouped artifacts under:

- `.agency/specs/batches/<epic-slug>/<milestone-slug-or-unscoped>/<batch-key>/`

Required reviewer/operator outputs:

- `index.md`
  - primary summary and navigation index for the run
  - execution waves in suggested build order
  - per-item state summary (`ready-for-build`, `needs-clarification`, `blocked`)
  - links to canonical per-item specs
- `review.md`
  - reviewer-oriented rationale, assumptions, unresolved decisions, and rerun deltas
- `decomposition.yaml`
  - DAG edges and wave ordering
- `decisions.yaml`
  - item-scoped confirmed/assumed/unresolved decisions
- `items/<order>-<item-slug>.md`
  - per-item summary sheets linked to canonical spec files

`index.md` is the operator-facing table of contents; `review.md` is the reviewer-facing decision narrative.

## Suggested Execution Order Rules

The summary/index should compute suggested execution order with deterministic rules:

1. topological sort by dependency edges
2. group into waves (`wave: 0, 1, 2...`)
3. tie-break items in same wave by normalized slug ascending

Only `ready-for-build` items should appear in the default "build now" subset.

## Rerun Behavior

Reruns of the same `batch-key` should:

- update batch bundle files in place
- keep unchanged item slugs stable
- avoid artificial `revision` bumps for unchanged item scope/acceptance
- increment `revision` only for material item changes

## Tracker Sync Follow-On For Batch Runs

When batch outputs are tracker-backed, run a post-planning sync lifecycle defined in [`docs/spec-batch-tracker-sync-and-approval-gates.md`](./spec-batch-tracker-sync-and-approval-gates.md):

1. generate dry-run planned writes
2. complete reviewer and operator approval gates
3. apply approved create/update operations
4. publish per-item created/updated/skipped/failed outcomes with retry guidance

Planning-batch decomposition should not bypass approval boundaries for tracker writes.

## Non-Goals

This workflow does not define:

- provider-specific bulk tracker write mechanics (defined in [`docs/spec-batch-tracker-sync-and-approval-gates.md`](./spec-batch-tracker-sync-and-approval-gates.md))
- sprint capacity prediction heuristics
- automatic reprioritization beyond deterministic DAG ordering

## Acceptance Criteria Coverage For #74

- Multi-item planning input can generate multiple specs in one run:
  - see `Path B: Planning-Batch`, `Step 2`, and `Step 3`
- Each generated item has independent readiness state and acceptance criteria:
  - see `Step 3` and `Step 4`
- Batch summary/index is produced for reviewer/operator use:
  - see `Step 5`
- Existing single-item spec workflow remains intact:
  - see `Path A` and `Path Selection Rule`
