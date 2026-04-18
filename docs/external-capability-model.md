# External Capability Model For Integrations

This document defines the proposed contract for issue `#13`:

- [#13 Define external capability model for integrations](https://github.com/peakweb-team/pw-agency-agents/issues/13)

It builds on:

- the Claude-first MVP direction from issue `#29`
- the workflow-pattern lessons from issue `#31`
- the fragment metadata contract in [`docs/fragment-schema.md`](./fragment-schema.md)
- the builder inventory workflow in [`docs/builder-inventory-workflow.md`](./builder-inventory-workflow.md)
- the builder questionnaire flow in [`docs/builder-questionnaire-flow.md`](./builder-questionnaire-flow.md)
- the orchestration execution rubric in [`docs/orchestration-execution-rubric.md`](./orchestration-execution-rubric.md)
- the capability fallback contract in [`docs/capability-fallback-behavior.md`](./capability-fallback-behavior.md)
- the first-wave task-system fragment set in [`docs/task-system-provider-fragment-set.md`](./task-system-provider-fragment-set.md)
- the first-wave code-host/review fragment set in [`docs/code-host-review-provider-fragment-set.md`](./code-host-review-provider-fragment-set.md)
- the roadmap direction toward capability-oriented workflow behavior instead of vendor-bound prompts

## Why This Exists

Superagents fragments need a stable way to express what they expect from external systems without hardcoding every workflow to one provider.

That is the purpose of the capability model.

It gives generated skills and fragments a shared vocabulary for:

- direct local intake when work starts from a freeform brief
- tracked-task intake when work starts from an external issue or ticket
- code-host and PR behavior
- review feedback handling
- delivery and validation signal retrieval

This keeps the builder capability-oriented while still leaving room for provider-specific mappings later.

Execution-tier sizing (`solo`, `sub-agent`, `agent-team`) is a separate internal orchestration concern and is defined in [`docs/orchestration-execution-rubric.md`](./orchestration-execution-rubric.md).

## Goals

- define the MVP capability vocabulary for generated skills
- distinguish direct-brief intake from tracked-task intake explicitly
- describe capability semantics clearly enough for later provider mapping
- call out known provider variability so generated skills do not assume a false uniform API
- establish the minimum unsupported-capability behavior for MVP

## Non-Goals

- defining the project declaration file or configuration shape for choosing providers
- implementing provider adapters or MCP servers
- promising that every provider supports every capability equally
- replacing future issue work on fallback matrices or provider-specific coverage

## Core Principles

### Capabilities Describe Workflow Intent, Not Vendor APIs

A capability should name what the generated skill needs to accomplish.

It should not name how a specific provider exposes that behavior.

Good:

- `task-tracker.read`
- `task-tracker.create`
- `code-host.pr.open`
- `review-feedback.read`

Bad:

- `github.issue.get`
- `jira.transition-ticket`
- `coderabbit.fetch-review`

### Direct-Brief Intake Is First-Class

Generated skills must be allowed to start from a freeform prompt or bootstrap brief without requiring an external task system.

The capability model must therefore distinguish:

- local/direct intake capabilities
- external tracked-task capabilities

This is not a fallback hack. It is a primary supported workflow mode for MVP.

### Provider Mapping May Be Partial

Later provider declarations may map only part of the capability set.

The generated skill should therefore know:

- which capabilities are required for its chosen workflow
- which capabilities are optional refinements
- what to do when a capability is unavailable

### Local Evidence Still Matters

Not every useful workflow signal comes from an external API.

For MVP, local or repo-derived signals remain valid inputs alongside provider-backed capabilities.

Examples:

- local test results
- CI config in the repository
- branch and PR conventions in docs
- a direct brief supplied at builder runtime

## Capability Families

The MVP capability set is organized into five families.

### 1. Task Intake Capabilities

These determine how work begins.

#### `task-intake.direct-brief`

- Purpose: allow work to begin from a freeform prompt, bootstrap brief, or greenfield request
- Required for:
  - direct-brief-first workflows
  - dual-intake workflows that allow both briefs and tracked tasks
- Semantics:
  - accept a human-provided brief as the initial work object
  - treat the brief as authoritative enough to start planning
  - do not require an external task id before work can begin
- Notes:
  - this is usually satisfied by local prompt input, not a third-party system
  - this capability should pair naturally with explicit assumption capture

#### `task-intake.batch-planning`

- Purpose: allow intake to begin from one planning object that can decompose into multiple implementation-ready item specs in one run
- Required for:
  - portfolio/sprint kickoff spec planning workflows
  - dual-path workflows that support both single-item and multi-item spec intake
- Semantics:
  - accept normalized signal `input.batch_planning_object` containing objective, candidate items, and constraints
  - accept a planning intake object containing an objective, candidate items, and constraints
  - preserve item-scoped decomposition, acceptance criteria, and readiness outcomes
  - generate a reviewer/operator summary index with suggested execution order
- Notes:
  - this capability is additive and must not replace `task-intake.direct-brief` single-item behavior
  - canonical artifact semantics for this mode are defined in [`docs/spec-batch-planning-contract.md`](./spec-batch-planning-contract.md) and [`docs/portfolio-to-spec-decomposition-workflow.md`](./portfolio-to-spec-decomposition-workflow.md)

#### `task-intake.assumption-capture`

- Purpose: record assumptions, missing facts, and unresolved decisions when work starts without a fully structured ticket
- Required for:
  - direct-brief-first workflows
  - tracker-optional workflows where the initial brief may be incomplete
- Semantics:
  - turn implicit assumptions into explicit reviewable output
  - preserve unresolved questions for later human or system follow-up
- Notes:
  - this is commonly satisfied by generated-skill behavior and metadata output rather than by an external provider

Batch planning note:

- `task-intake.batch-planning` is the explicit multi-item intake capability for planning objects (epic objective + candidate work items + constraints)
- assumption capture should remain item-scoped where possible instead of collapsing all uncertainty into one batch-level unresolved state

### 2. Tracked-Task Capabilities

These apply when work begins from or must sync back to an external issue system.

#### `task-tracker.lookup`

- Purpose: resolve a task reference into the canonical tracked work item
- Required for:
  - tracked-task-first workflows
  - dual-intake workflows when the entry point is a task reference
- Semantics:
  - accept a task key, issue number, URL, or equivalent reference
  - return the canonical task record to drive later reads and updates
- Known variability:
  - some providers support multiple reference formats
  - some require exact ids or project-scoped keys
  - some can resolve URLs but not plain-language references

#### `task-tracker.read`

- Purpose: read the task record and its delivery-relevant context
- Required for:
  - tracked-task-first workflows
- Semantics:
  - retrieve title, description, acceptance criteria, status, and related links when available
  - make the task readable enough to produce an implementation plan
- Known variability:
  - some providers expose structured fields for status, assignee, and acceptance criteria
  - others expose mostly freeform text plus comments

#### `task-tracker.create`

- Purpose: create a tracked task artifact from a spec-ready brief when implementation should start from a newly authored ticket/issue
- Required for:
  - spec-first tracked-task workflows
  - direct-brief workflows that must publish a tracker artifact before implementation
- Semantics:
  - create a canonical task record with enough structure for implementation handoff
  - persist title, scope summary, acceptance expectations, and traceable links to supporting spec artifacts
- Known variability:
  - some providers require issue type, project key, or workflow-state defaults at create time
  - some providers allow rich templates while others provide minimal create surfaces
  - permissions may allow read/update on existing records but restrict creation of new records

#### `task-tracker.update`

- Purpose: write meaningful progress or completion updates back to the tracked task
- Required for:
  - tracked-task workflows that expect durable system-of-record updates
- Semantics:
  - post status notes, links, or summary updates back to the task system
  - keep the tracked task aligned with meaningful workflow milestones
- Known variability:
  - some providers support rich field transitions
  - some only support comments or lightweight status mutation
  - permissions may allow reading but not updating

### 3. Code-Host And Pull Request Capabilities

These govern how implementation work is published for review.

#### `code-host.pr.open`

- Purpose: create a pull request or merge request for the current implementation slice
- Required for:
  - PR-based delivery workflows
- Semantics:
  - open the review artifact in the primary code host
  - include enough summary information for reviewers to evaluate the change
- Known variability:
  - some systems require a branch on the same remote
  - some allow draft PRs or merge requests while others differ in terminology and available states

#### `code-host.pr.update`

- Purpose: keep the PR description and metadata aligned with the current state of the work
- Required for:
  - PR-based delivery workflows that expect living PR summaries
- Semantics:
  - update title, description, labels, or linked references when the workflow requires it
- Known variability:
  - editable metadata differs across providers
  - some workflows depend heavily on templates or labels, others do not

#### `code-host.pr.review-request`

- Purpose: route a PR into the expected reviewer path
- Required for:
  - workflows with explicit human or automated review routing
- Semantics:
  - request the relevant review path for the project, such as maintainers, a team, or reviewer automation
- Known variability:
  - some providers support explicit reviewer assignment
  - some automation is triggered through labels, comments, or branch rules instead

#### `code-host.pr.status-read`

- Purpose: read PR-level status and check outcomes
- Required for:
  - PR workflows that gate completion on checks, approvals, or mergeability
- Semantics:
  - retrieve review state, check state, and merge-readiness signals when available
- Known variability:
  - the available status surface differs significantly across providers
  - some systems separate CI, approvals, and branch protection into different APIs

### 4. Review Feedback Capabilities

These govern how generated skills consume and act on review comments.

#### `review-feedback.read`

- Purpose: read human and automated review feedback on implementation work
- Required for:
  - review-driven workflows
- Semantics:
  - retrieve unresolved review comments, approval state, and notable automated review findings
  - normalize them into a work queue the generated skill can act on
- Known variability:
  - review comments may be inline, summary-level, or bot-generated
  - some providers expose threaded resolution state, others do not

#### `review-feedback.respond`

- Purpose: update the review conversation after follow-up changes
- Required for:
  - workflows that expect visible reviewer follow-through
- Semantics:
  - acknowledge or resolve feedback in the review system when appropriate
  - keep the review loop legible after changes are made
- Known variability:
  - some systems support formal review replies and resolution markers
  - others only support generic comments

### 5. Delivery And Validation Capabilities

These let generated skills inspect whether the work is ready to hand off or complete.

#### `delivery-status.read`

- Purpose: read delivery-state signals tied to the change
- Required for:
  - workflows that rely on hosted checks, deploy previews, or release gates
- Semantics:
  - retrieve the status of downstream delivery signals that materially affect completion
- Known variability:
  - signals may come from the code host, CI provider, deployment platform, or release tooling
  - some projects treat this as mandatory, others as optional context

#### `validation-signal.read`

- Purpose: retrieve validation evidence relevant to the task
- Required for:
  - workflows where tests, lint, static analysis, or similar evidence affect completion
- Semantics:
  - make validation outcomes visible to the generated skill for planning, PR preparation, or completion checks
- Known variability:
  - validation may be local-only, CI-only, or both
  - some providers expose rich structured results, others only expose pass/fail summaries

## Intake Modes And Required Capability Sets

The builder should treat work intake mode as a top-level workflow decision.

### Direct-Brief-First

Required capabilities:

- `task-intake.direct-brief`
- `task-intake.assumption-capture`

Not required:

- any `task-tracker.*` capability

This mode explicitly allows generated skills to operate without an external task system.

### Planning-Batch (Direct-Brief)

Required capabilities:

- `task-intake.direct-brief`
- `task-intake.batch-planning`
- `task-intake.assumption-capture`

This mode allows one planning object to produce multiple item specs in one run while keeping item-scoped readiness and acceptance details.

### Tracked-Task-First

Required capabilities:

- `task-tracker.lookup`
- `task-tracker.read`

Usually required:

- `task-tracker.update`

This mode assumes the tracked task is the system of record for work intake.

### Spec-First (Tracker-Backed)

Required capabilities:

- `task-intake.direct-brief`
- `task-intake.batch-planning` (when multi-item planning input is in scope)
- `task-intake.assumption-capture`
- `task-tracker.create`
- `task-tracker.read`

Usually required:

- `task-tracker.update`

This mode turns a brief or portfolio objective into a tracker-backed implementation ticket before coding starts.

### Dual Intake

Required capabilities:

- `task-intake.direct-brief`
- `task-intake.batch-planning` (when planning-batch path is enabled)
- `task-intake.assumption-capture`
- `task-tracker.lookup`
- `task-tracker.read`

This mode allows the generated skill to start from either a direct brief or a tracked task depending on the request.

## Provider Mapping Expectations

Provider mapping work should translate a concrete system into one or more of the canonical capabilities above.

The initial provider coverage posture now lives in [`docs/provider-matrix.md`](./provider-matrix.md).

That later mapping should answer:

- which capabilities the provider satisfies
- whether support is full, partial, or unavailable
- any provider-specific restrictions worth surfacing to the generated skill

Examples:

- GitHub Issues may satisfy `task-tracker.lookup`, `task-tracker.read`, `task-tracker.create`, and `task-tracker.update`
- Jira may satisfy the same tracked-task capabilities with different field semantics
- GitHub Pull Requests may satisfy `code-host.pr.open`, `code-host.pr.update`, `code-host.pr.review-request`, `code-host.pr.status-read`, `review-feedback.read`, and `review-feedback.respond`
- local prompt input satisfies `task-intake.direct-brief` without any external provider at all
- local planning intake objects satisfy `task-intake.batch-planning` without any external provider at all

This document defines the capability semantics, not the declaration format for those mappings. The declaration shape now lives in [`docs/project-integration-declaration-format.md`](./project-integration-declaration-format.md).

## Unsupported-Capability Behavior

Generated skills must not pretend a capability exists when it has not been mapped or confirmed.

For MVP:

### 1. Do Not Invent Support

If a capability is unavailable, generated instructions should not fabricate a provider-specific step.

### 2. Prefer A Safe Alternate Path

If the missing capability has a safe local or direct-brief alternative, the builder may prefer that path.

Example:

- if no authoritative task-tracker capability is available, prefer direct-brief-first workflow when that remains compatible with the project

### 3. Record The Gap Explicitly

If a missing capability materially affects workflow behavior, record it in builder output rather than hiding it.

This should surface in:

- `decisions.yaml`
- `review.md`
- generated-skill instructions where the limitation changes operator behavior

### 4. Escalate When No Safe Path Exists

If the workflow requires a capability and no safe fallback exists, the builder should leave the related decision unresolved instead of generating misleading behavior.

Examples:

- a tracked-task-only workflow without `task-tracker.read`
- a review-driven PR workflow without any usable review-feedback path

### 5. Use The Shared Fallback Contract

This document defines the baseline behavior only.

The detailed fallback matrix now lives in [`docs/capability-fallback-behavior.md`](./capability-fallback-behavior.md).

## Recommended Capability Vocabulary For Fragments

Fragments should prefer the canonical capability ids in this document when declaring behavior.

That keeps:

- provider fragments comparable to each other
- generic fragments independent from vendor names
- builder output ready for later provider-mapping work

This does not require every fragment to enumerate every possible capability immediately.

For MVP, fragments should declare:

- the smallest set of capabilities they genuinely depend on or contribute
- in canonical capability language

## MVP Boundary

This contract is intentionally modest.

It defines:

- the shared capability vocabulary
- the distinction between direct/local intake and external tracked-task intake
- the baseline semantics needed for later provider mapping
- the minimum unsupported-capability behavior

It does not define:

- the config file or declaration syntax for selecting providers
- provider-specific adapter implementations
- the full fallback matrix for every missing capability combination
