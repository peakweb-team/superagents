# Fragment Assembly And Conflict-Resolution Rules

This document defines the proposed contract for issue `#16`:

- [#16 Define fragment assembly and conflict-resolution rules](https://github.com/peakweb-team/pw-agency-agents/issues/16)

It builds on:

- the fragment metadata contract in [`docs/fragment-schema.md`](./fragment-schema.md)
- the generated-skill layout contract in [`docs/generated-skill-layout.md`](./generated-skill-layout.md)
- the builder inventory workflow in [`docs/builder-inventory-workflow.md`](./builder-inventory-workflow.md)
- the builder questionnaire flow in [`docs/builder-questionnaire-flow.md`](./builder-questionnaire-flow.md)
- the orchestration tiering rubric in [`docs/orchestration-execution-rubric.md`](./orchestration-execution-rubric.md)
- the runtime context-budgeting and repo-reading contract in [`docs/runtime-context-budgeting-and-repo-reading.md`](./runtime-context-budgeting-and-repo-reading.md)
- the project integration declaration format in [`docs/project-integration-declaration-format.md`](./project-integration-declaration-format.md)
- the capability fallback contract in [`docs/capability-fallback-behavior.md`](./capability-fallback-behavior.md)
- the first-wave task-system provider fragment set in [`docs/task-system-provider-fragment-set.md`](./task-system-provider-fragment-set.md)
- the first-wave code-host/review provider fragment set in [`docs/code-host-review-provider-fragment-set.md`](./code-host-review-provider-fragment-set.md)
- the Claude-first MVP direction in [`docs/claude-first-mvp-strategy.md`](./claude-first-mvp-strategy.md)

## Why This Exists

The earlier builder docs define:

- how the builder discovers evidence
- how it records confidence
- how it asks clarifying questions
- how fragments declare metadata such as `conflicts`, `exclusive_within`, `order`, and `emits`

What they do not yet define is the assembly contract that turns that information into deterministic generated skills.

This document fills that gap.

It defines:

- how selected fragments become one assembled fragment plan
- how conflicts and exclusivity buckets are resolved
- when the builder should continue, warn, ask for clarification, or fail
- how fragment order becomes emitted behavior blocks in generated output

## Goals

- define a deterministic fragment-assembly pipeline for MVP
- keep fragment overlap honest instead of silently merging contradictory behavior
- make exclusivity resolution predictable and reviewable
- preserve human-readable generated skills and metadata
- give `fragments.lock.yaml` and `review.md` a stable assembly contract

## Non-Goals

- implementing a full general-purpose rule engine
- allowing unlimited fragment overrides in v1
- hiding unresolved workflow choices behind silent defaults
- replacing future provider-specific refinement work

## Core Principle

The builder should assemble one coherent operating path per generated skill role.

That means:

- every selected fragment must be individually applicable
- incompatible fragments must not coexist in the same primary path
- repeated emitted behavior should merge intentionally, not duplicate blindly
- every suppression, warning, or unresolved choice should remain visible in metadata

## Assembly Inputs

The assembly phase should begin only after inventory and questionnaire work have produced:

- normalized signals from `inventory.yaml`
- builder decisions and decision states from `decisions.yaml`
- any integration constraints from `integrations.yaml`
- the candidate fragment library

The assembly phase should not rediscover repository facts on its own.

It should consume the recorded decisions and apply fragment rules deterministically.

## Assembly Pipeline

The MVP assembly pipeline should follow seven steps.

### 1. Build The Candidate Set

For each fragment in the library:

1. evaluate `selection.evidence_any`
2. evaluate `selection.evidence_all`
3. evaluate `selection.evidence_none`
4. note any `selection.requires_confirmation` triggers

Signal matching should be interpreted strictly and without type coercion.

A signal counts as a match only when:

- the signal id exists in `inventory.yaml`
- the recorded value is not `null`
- the fragment condition and the recorded value agree exactly under the rules below

Matching rules for MVP:

- bare signal ids such as `forge.github`
  - match only when the recorded value is the boolean `true`
  - do not match when the value is `false`, `null`, missing, the string `"true"`, or the number `1`
- string or enum-valued signals
  - match only by exact, case-sensitive string equality
  - example: `work_intake_mode=both` matches `both`, but not `Both`
- missing signals
  - count as not matched
- arrays of signals in `evidence_any`, `evidence_all`, `evidence_none`, or `requires_confirmation`
  - are evaluated item by item using the same exact-match rules

`selection.requires_confirmation` may reference either:

- a signal condition
  - evaluated with the same inventory-based match rules above
- a builder decision condition such as `primary_task_tracker=jira`
  - evaluated against `decisions.yaml`, not `inventory.yaml`
  - matched only when the named decision exists, its value is not `null`, and the value matches exactly with the same no-coercion, case-sensitive equality rules

Builders should treat signal-backed and decision-backed confirmation checks as separate paths and should not implicitly look for decisions inside `inventory.yaml` or signals inside `decisions.yaml`.

Examples:

- `evidence_any: [forge.github, forge.gitlab]`
  - matches when either signal is recorded as boolean `true`
- `evidence_all: [workflow.pull_requests, review.coderabbit]`
  - matches only when both are recorded as boolean `true`
- `evidence_none: [task_tracker.jira]`
  - matches the exclusion rule only when `task_tracker.jira` is recorded as boolean `true`
- `requires_confirmation: [primary_task_tracker=jira]`
  - triggers only when the `primary_task_tracker` decision exists in `decisions.yaml` with the exact value `jira`

A fragment becomes a candidate when:

- at least one `evidence_any` signal matches, or `evidence_any` is empty
- every `evidence_all` signal matches
- no `evidence_none` signal matches

Candidate evaluation should record:

- matched signals
- missing required signals
- conflicting signals
- whether confirmation is still required before auto-selection

### 2. Classify Candidates By Selection Status

Each candidate should be classified as one of:

- `selected`
  - the fragment is applicable and no clarification blocks it
- `needs-clarification`
  - the fragment is plausible, but `requires_confirmation` or a conflicting decision blocks automatic selection
- `rejected`
  - the fragment does not satisfy the applicability rules

The builder should prefer explicit classification over silent omission.

### 3. Expand Hard Requirements

After the initial candidate pass, the builder should resolve `composition.requires`.

Rules:

- if fragment `A` is selected and requires fragment `B`, attempt to include `B`
- if `B` is already selected, keep it
- if `B` is applicable and unblocked, add it
- if `B` is blocked by clarification, the depending fragment should also become `needs-clarification`
- if `B` is unavailable or conflicts with a confirmed decision, the depending fragment should fail assembly for the current path

The builder should not silently keep a fragment whose declared requirements are missing.

### 4. Resolve Exclusivity Buckets

Fragments that share a `composition.exclusive_within` bucket are competing to satisfy one primary role.

Examples:

- `primary-intake-mode`
- `primary-task-tracker`
- future `primary-pr-review-system`

The builder should choose at most one primary winner per bucket for the assembled path.

Bucket resolution priority should be:

1. fragment aligned with a `confirmed` builder decision
2. fragment aligned with an `assumed` builder decision
3. fragment with higher decision confidence from inventory or questionnaire inputs
4. higher `selection.preference`
5. if multiple fragments are still tied, check whether auto-selecting any one of them would be unsafe or misleading
6. lexicographically smaller `id`

The safety gate in step 5 should prefer `needs-clarification` over a forced winner when:

- the remaining tied fragments would materially change the generated workflow
- no safe default exists
- the questionnaire has not already resolved the ambiguity

Example:

- if `project-management/github-issues` and `project-management/jira` remain tied in `primary-task-tracker`, and selecting either one would redefine the system of record, the bucket should become `needs-clarification` instead of falling through to an `id` tie-break

If a bucket falls through to step 6, the builder should choose the lexicographically smaller `id` and record the tie-break attempt explicitly in `review.md`.

Non-winning fragments in the bucket should be marked:

- `suppressed_by_exclusivity`

They should remain visible in `fragments.lock.yaml` for review.

### 5. Resolve Explicit Conflicts

After exclusivity resolution, the builder should evaluate `composition.conflicts`.

Conflict resolution rules:

1. If one fragment is aligned with a `confirmed` decision and the other is not, keep the confirmed one.
2. If one fragment is aligned with an `assumed` decision and the other is only weakly inferred, keep the assumed one.
3. If both fragments are still plausible and the conflict changes workflow meaning materially, ask for clarification instead of guessing.
4. If one fragment has a safe fallback path and the other is required for correctness, keep the correctness-preserving fragment and warn.
5. If neither fragment can be chosen safely, fail assembly for that skill path.

Conflict resolution should never produce a generated skill that contains contradictory instructions as if both paths were active.

### 6. Validate Capability And Workflow Viability

Once the provisional fragment set is stable, the builder should verify that the assembled path is still honest given:

- the required capability set for the chosen intake mode
- declared capability bindings in `integrations.yaml`
- fallback behavior from [`docs/capability-fallback-behavior.md`](./capability-fallback-behavior.md)

Recommended outcomes:

- `continue`
  - the selected fragments are coherent and all required capabilities are satisfied or safely optional
- `warn`
  - the assembled path is usable, but a degraded provider mapping or suppressed fragment should remain visible
- `needs-clarification`
  - the path is plausible, but the builder cannot choose truthfully between materially different options
- `fail`
  - the path would otherwise claim unsupported behavior or violate a hard fragment requirement

### 7. Emit Ordered Behavior Blocks

After the fragment set is finalized, the builder should transform fragments into emitted behavior blocks.

The builder should:

1. sort selected fragments by `composition.order`, then by `id`
2. walk fragments in that order
3. append each fragment's contributions to the blocks named in `composition.emits`
4. create each emitted block once, at the point where it first appears

This means repeated emitted block names should merge into one block rather than producing duplicate section headers.

## Order And Composition Rules

### Fragment Order

`composition.order` defines the stable assembly order of the selected fragment list.

Ascending order should be used.

The final sort key is:

1. `composition.order`
2. `id`

This keeps assembly deterministic even when two fragments use the same numeric order.

### Canonical MVP Shape

For the current layer model, the typical order should feel like:

1. task intake
2. project-management system of record
3. orchestration and team-shaping rules
4. delivery and review loop
5. runtime and efficiency guidance

The numeric `order` values on fragments should preserve this shape, but the builder should still trust the metadata rather than hardcoding layer order separately.

### Composition Of Repeated Concepts

If multiple selected fragments emit the same behavior block:

- merge them into the same block
- preserve fragment contribution order
- do not duplicate headings
- do not deduplicate away intentionally different guidance unless the text is actually contradictory

Examples:

- both a direct-intake fragment and a task-tracker fragment may emit `task-intake`
- a review fragment and a provider-specific review fragment may both emit `review-loop`

The builder should preserve both contributions when they are additive and compatible.

## Emitted Behavior Blocks

`composition.emits` tells the builder which behavior blocks a fragment contributes to.

In MVP, a behavior block is:

- a named section of generated operating behavior
- backed by one or more selected fragments
- traceable in metadata

`composition.emits` is the canonical metadata path for this field.

Builders and docs should not introduce a parallel `fragment.emits` key in v1.

If an implementation encounters legacy data that exposes `fragment.emits`, it should map that value to `composition.emits`, prefer `composition.emits` when both are present, and record the normalization in review metadata.

Behavior blocks should be recorded in `fragments.lock.yaml` with:

- the block name
- contributing fragment ids in order
- any suppressed competing fragments that would have emitted the same role

The generated `SKILL.md` does not need to expose raw metadata, but it should reflect the resulting block order clearly.

### Suggested Output Pattern

The primary orchestration skill should assemble blocks in first-appearance order.

A typical generated `SKILL.md` may therefore read like:

1. work intake and assumption handling
2. tracked-task or system-of-record rules
3. PR and review loop
4. team-sizing heuristics
5. context and model-routing rules

Team-sizing block content should apply the canonical `solo` -> `sub-agent` -> `agent-team` escalation rules from [`docs/orchestration-execution-rubric.md`](./orchestration-execution-rubric.md).

Companion skills may project a subset of the same assembled fragment plan, but they should inherit the same conflict-resolution results rather than rerunning selection independently.

## Warning, Clarification, And Failure Rules

### Warn

Warn when:

- the assembled path is still truthful and usable
- a competing fragment was suppressed in a way a reviewer should understand
- a capability fallback degrades convenience or visibility but not correctness

Warnings should appear in:

- `fragments.lock.yaml`
- `review.md`
- `integrations.yaml` when capability support is the reason

### Ask For Clarification

Ask for clarification when:

- two fragments could satisfy the same role
- the conflict materially changes the meaning of the generated workflow
- no safe default exists
- the questionnaire has not already resolved the ambiguity

Typical examples:

- GitHub Issues and Jira both appear primary
- both direct-brief-first and tracked-task-first intake remain plausible, but the project does not permit a safe dual-intake default
- two review-system fragments would produce different reviewer-routing instructions

### Fail

Fail the affected assembly path when:

- a selected fragment has an unmet hard requirement
- the chosen workflow requires a capability whose fallback mode is `fail`
- the builder would otherwise emit contradictory instructions as if they were both active

Failure should block generation of the misleading skill path rather than silently dropping the problem.

## Metadata Expectations

Assembly decisions should stay reviewable.

### `fragments.lock.yaml`

The lock file should record at minimum:

- selected fragments in final order
- selected fragment version and source provenance
- suppressed fragments and suppression reason
- suppressed fragment version and source provenance
- exclusivity bucket winners
- explicit conflict resolutions
- unresolved clarification items, including status, affected bucket or conflict, and blocking question
- emitted behavior blocks and contributing fragments

Recommended conceptual shape:

```yaml
selected_fragments:
  - id: task-intake/direct-brief
    version: 1.0.0
    source:
      type: repo-path
      path: skills/fragments/task-intake/direct-brief.md
      ref: main@abc1234
    order: 10
  - id: orchestration/team-sizing
    version: 1.0.0
    source:
      type: repo-path
      path: skills/fragments/orchestration/team-sizing.md
      ref: main@abc1234
    order: 40
  - id: delivery/pull-request-review
    version: 1.0.0
    source:
      type: repo-path
      path: skills/fragments/delivery/pull-request-review.md
      ref: main@abc1234
    order: 60
  - id: runtime/context-and-model-routing
    version: 1.0.0
    source:
      type: repo-path
      path: skills/fragments/runtime/context-and-model-routing.md
      ref: main@abc1234
    order: 80

suppressed_fragments:
  - id: project-management/github-issues
    version: 1.0.0
    source:
      type: repo-path
      path: skills/fragments/project-management/github-issues.md
      ref: main@abc1234
    reason: suppressed_by_exclusivity
    bucket: primary-task-tracker

needs_clarification:
  - status: pending
    affected_bucket: primary-task-tracker
    blocking_question: Which task tracker should the builder treat as authoritative?
    candidates:
      - project-management/github-issues
      - project-management/jira

exclusive_buckets:
  primary-task-tracker:
    winner: project-management/jira
    winner_version: 1.0.0
    winner_source:
      type: repo-path
      path: skills/fragments/project-management/jira.md
      ref: main@abc1234
    suppressed:
      - project-management/github-issues
    basis: confirmed decision primary_task_tracker=jira

behavior_blocks:
  - name: task-intake
    source_fragments:
      - id: task-intake/direct-brief
        version: 1.0.0
        ref: main@abc1234
    contributors:
      - task-intake/direct-brief
  - name: review-loop
    source_fragments:
      - id: delivery/pull-request-review
        version: 1.0.0
        ref: main@abc1234
    contributors:
      - delivery/pull-request-review
  - name: team-sizing-rules
    source_fragments:
      - id: orchestration/team-sizing
        version: 1.0.0
        ref: main@abc1234
    contributors:
      - orchestration/team-sizing
  - name: context-budgeting
    source_fragments:
      - id: runtime/context-and-model-routing
        version: 1.0.0
        ref: main@abc1234
    contributors:
      - runtime/context-and-model-routing
```

### `review.md`

The review summary should call out:

- which fragments were selected
- which fragments were suppressed and why
- any warnings or degradations
- any questions that blocked a more specific assembly

## Worked Examples

### Example 1: Direct-Brief-First Repo With PR Delivery

Signals and decisions:

- `input.direct_brief`
- `workflow.pull_requests`
- `repo.monorepo`
- `workflow.review_and_validation_expected`
- `work_intake_mode=direct-brief` (`confirmed`)

Selected fragments:

- `task-intake/direct-brief`
- `delivery/pull-request-review`
- `orchestration/team-sizing`
- `runtime/context-and-model-routing`

Suppressed fragments:

- none

Final fragment order:

1. `task-intake/direct-brief`
2. `orchestration/team-sizing`
3. `delivery/pull-request-review`
4. `runtime/context-and-model-routing`

Final emitted block order:

1. `task-intake`
2. `assumption-capture`
3. `team-sizing-rules`
4. `review-loop`
5. `context-budgeting`
6. `model-routing-rules`

The meaning of `context-budgeting` should follow the canonical runtime contract in [`docs/runtime-context-budgeting-and-repo-reading.md`](./runtime-context-budgeting-and-repo-reading.md) rather than ad hoc file-reading guidance.

Outcome:

- the generated workflow starts from a brief
- PR review remains part of delivery
- no task-tracker fragment is emitted because tracked-task intake is not primary

### Example 2: GitHub Forge, Jira As Confirmed Primary Tracker

Signals and decisions:

- `forge.github`
- `task_tracker.github_issues`
- `task_tracker.jira`
- `repo.references_jira_keys`
- `primary_task_tracker=jira` (`confirmed`)
- `work_intake_mode=tracked-task` (`confirmed`)

Candidate tracker fragments:

- `project-management/github-issues`
- `project-management/jira`

Resolution:

- both fragments are candidates for `primary-task-tracker`
- Jira wins because it matches the confirmed decision
- GitHub Issues is marked `suppressed_by_exclusivity`

Selected fragments:

- `project-management/jira`
- `delivery/pull-request-review`
- `orchestration/team-sizing`

Warnings:

- `review.md` should note that GitHub issue references were present but not treated as authoritative task intake

Outcome:

- the assembled skill reads and updates Jira as the system of record
- GitHub remains the forge and PR venue without becoming the primary tracker

### Example 3: Ambiguous Tracker Authority Without A Safe Default

Signals and decisions:

- `forge.github`
- `task_tracker.github_issues`
- `task_tracker.jira`
- no confirmed `primary_task_tracker`
- no safe direct-brief default for this repository

Candidate tracker fragments:

- `project-management/github-issues`
- `project-management/jira`

Resolution:

- both fragments compete in `primary-task-tracker`
- neither has a confirmed or assumed decision advantage
- choosing either one would materially change system-of-record instructions

Outcome:

- assembly status becomes `needs-clarification`
- the builder should ask which tracker is authoritative
- the generated skill should not pretend both are primary

### Example 4: Dual Intake With Shared `task-intake` Emission

Signals and decisions:

- `input.direct_brief`
- `task_tracker.github_issues`
- `work_intake_mode=both` (`confirmed`)

Selected fragments:

- `task-intake/direct-brief`
- `project-management/github-issues`
- `delivery/pull-request-review`

Emission behavior:

- both the direct-brief fragment and the GitHub Issues fragment emit `task-intake`
- the builder creates one `task-intake` block
- direct-brief guidance appears first because its fragment order is lower
- tracked-task guidance follows in the same block

Outcome:

- the generated skill clearly supports both entry paths
- duplicated task-intake headings are avoided
- the merged block still shows both valid workflow starts

## MVP Boundary

This contract defines:

- the assembly pipeline
- exclusivity and conflict resolution behavior
- warning, clarification, and failure conditions
- fragment ordering and emitted behavior-block rules
- reviewable metadata expectations

It does not define:

- a user-authored custom override language
- provider-specific merge logic for every future fragment family
- unlimited companion-skill decomposition rules
