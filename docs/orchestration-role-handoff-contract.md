# Orchestration Role Expectations And Handoff Contract

This document defines the proposed contract for issue `#23`:

- [#23 Define role expectations and handoff rules for generated teams](https://github.com/peakweb-team/pw-agency-agents/issues/23)

It builds on:

- the roadmap orchestration direction in [`ROADMAP.md`](../ROADMAP.md)
- the tiering rubric in [`docs/orchestration-execution-rubric.md`](./orchestration-execution-rubric.md)
- the runtime context-budgeting and repo-reading contract in [`docs/runtime-context-budgeting-and-repo-reading.md`](./runtime-context-budgeting-and-repo-reading.md)
- task-system external update boundaries in [`docs/task-system-provider-fragment-set.md`](./task-system-provider-fragment-set.md)
- code-host/review external update boundaries in [`docs/code-host-review-provider-fragment-set.md`](./code-host-review-provider-fragment-set.md)
- builder output and review metadata expectations in [`docs/generated-skill-layout.md`](./generated-skill-layout.md)

Model-routing and bounded subtask-splitting heuristics are defined in the runtime contract above; this document focuses on role ownership and handoff behavior once a tier and routing plan are chosen.

## Why This Exists

Issue `#22` established *when* to use `solo`, `sub-agent`, or `agent-team`.

Issue `#23` defines *how* roles and handoffs should behave inside each tier without turning external systems into an internal agent message bus.

The goal is one provider-neutral contract that generated skills can apply consistently.

## Core Policy

### Local Coordination First

Generated agents should coordinate execution locally by default.

External systems (GitHub Issues, Jira, PR comments, similar systems of record) should capture durable human-facing updates, not internal routing chatter.

### Smallest-Capable Tier Still Applies

Role and handoff behavior must stay compatible with the `solo` -> `sub-agent` -> `agent-team` escalation model from [`docs/orchestration-execution-rubric.md`](./orchestration-execution-rubric.md).

This contract does not justify escalating to `agent-team` by itself.

## Role Expectations By Tier

### `solo` Role Shape

One primary agent owns implementation, self-review, and validation sequencing.

Expected behavior:

- maintain one clear execution plan and progress state
- perform implementation plus explicit self-review/validation checks before completion claims
- record unresolved risks and assumptions instead of silently closing work
- publish external human-facing updates only at meaningful milestones

### `sub-agent` Role Shape

One lead orchestrator delegates bounded slices to specialist sub-agents.

Expected behavior:

- lead sets scope boundaries, success criteria, and handoff requirements
- specialists execute assigned slices and return structured handoff payloads
- lead integrates outputs, resolves cross-slice conflicts, and owns external updates
- reviewer/validator roles may be delegated, but acceptance still routes through lead ownership

### `agent-team` Role Shape

Use richer peer coordination only when active cross-role collaboration is required.

Expected behavior:

- assign explicit owners for each active workstream, even with peer collaboration
- allow direct peer alignment locally when coupled decisions must evolve together
- keep one primary orchestrator accountable for final integration and completion signaling
- avoid mirroring internal peer chatter into external task or review systems

## Canonical Role Responsibilities

### Lead / Primary Orchestrator

The lead is accountable for delivery coherence, not just task delegation.

Required responsibilities:

- choose and document the execution tier rationale
- define role ownership boundaries before execution starts
- issue delegation handoffs with explicit scope, constraints, and acceptance criteria
- track open questions, integration risks, and dependency blockers across slices
- accept or reject incoming handoffs with explicit reasons
- own final external milestone updates and completion summary quality

### Specialist / Sub-Agent

Specialists own bounded execution slices and should not silently expand scope.

Required responsibilities:

- confirm scope understanding before substantial execution
- keep changes within delegated ownership boundaries unless re-scoped
- return structured handoff payloads with evidence, risks, and unresolved questions
- flag blockers early rather than holding unresolved dependencies
- avoid posting external status updates unless explicitly delegated

### Reviewer / Validator

Reviewer and validator roles are distinct from implementer ownership, even when played by agents.

Required responsibilities:

- evaluate deliverables against acceptance criteria, not intent alone
- verify evidence quality (tests, checks, artifacts, reproducibility notes)
- distinguish blocking findings from non-blocking improvements
- return explicit acceptance state (`accepted`, `needs-clarification`, or `blocked`)
- escalate unresolved high-risk gaps before completion is claimed

## Handoff Contract

All non-trivial role transitions should use one structured payload contract.

### Required Handoff Payload

Every handoff should include:

- `handoff_id`: stable local reference for traceability
- `from_role` and `to_role`: ownership transition participants
- `scope`: what is in-scope and explicitly out-of-scope
- `artifacts`: changed files, generated outputs, or external artifacts
- `evidence`: validation/check results and relevant proof
- `open_questions`: unresolved decisions requiring receiver action
- `risks`: known risks with severity and proposed mitigation
- `requested_action`: expected receiver action (`implement`, `review`, `validate`, `integrate`, or `decide`)
- `acceptance_criteria`: concrete completion bar for this handoff
- `status`: `proposed`, `accepted`, `needs-clarification`, `blocked`, or `complete`
- `context_scope`: optional but recommended summary of what was read, what was intentionally not read, and whether broader context escalation is requested

Suggested minimal shape:

```yaml
handoff_id: handoff-impl-api-01
from_role: specialist.api
to_role: lead
scope:
  in: "Add endpoint and tests for issue ingest normalization."
  out: "No UI or tracker-comment automation changes."
artifacts:
  files_changed:
    - apps/api/src/issues/normalize.ts
    - apps/api/test/issues/normalize.test.ts
evidence:
  checks:
    - name: npm test -- normalize
      result: pass
open_questions:
  - "Should malformed issue links fail hard or warn + continue?"
risks:
  - severity: medium
    description: "Fallback behavior may diverge from existing handler."
    mitigation: "Confirm expected fallback mode before merge."
requested_action: integrate
acceptance_criteria:
  - "Lead confirms fallback behavior alignment."
status: proposed
context_scope:
  read:
    - apps/api/src/issues/normalize.ts
    - apps/api/test/issues/normalize.test.ts
  intentionally_not_read:
    - apps/web/**
  escalation_requested: false
```

### Ownership Transfer Rules

Ownership transfers should be explicit and singular.

Rules:

- one active owner-of-record per deliverable slice at any time
- sender remains responsible until receiver marks handoff `accepted`
- after `accepted`, receiver becomes owner-of-record for requested action
- rejected or `needs-clarification` handoffs return ownership to sender with explicit remediation notes
- external system updates remain lead-owned unless explicitly delegated as a milestone update task

### Completion And Acceptance Signals

The handoff state machine is intentionally small:

1. `proposed`: payload sent, awaiting receiver response
2. `accepted`: ownership transferred; receiver now accountable
3. `needs-clarification`: missing context or decision; sender must refine payload
4. `blocked`: cannot proceed due to unresolved dependency/risk
5. `complete`: requested action finished and acceptance criteria met

Generated workflows should not treat "work sent" as "work done."

Completion claims should require:

- explicit `complete` signal
- attached evidence or reviewer/validator decision outcome
- no unresolved blocking risk left un-escalated

### Unresolved Questions And Risk Escalation

When unresolved questions or risks appear:

- keep them in the local coordination thread until escalation threshold is met
- escalate immediately to lead when the item can affect correctness, safety, or completion truthfulness
- escalate to human-facing systems only for durable outcomes: blockers, major decisions, validation gates, or completion summaries

Default escalation thresholds:

- `high` risk: escalate to lead immediately and block completion until disposition
- `medium` risk: escalate before final integration or release handoff
- `low` risk: record for reviewer visibility; do not block unless compounded

## Human-Facing Update Threshold

Generated skills should keep external updates concise and milestone-oriented.

Good candidates for external updates:

- start of a major execution phase
- cross-role handoff completion that materially changes project state
- blocked state requiring human decision
- final implementation/review/validation summary

Do not post external updates for:

- every local delegation message
- routine progress pings without durable decisions
- intermediate internal coordination chatter

## Good Patterns And Anti-Patterns

### Good Pattern: Bounded Sub-Agent Handoff

- lead delegates two independent slices with explicit acceptance criteria
- each specialist returns artifacts, evidence, risks, and open questions
- lead accepts both handoffs, resolves one shared ambiguity, then posts one milestone update externally

Why this is good:

- ownership is clear
- local coordination stays local
- external updates remain human-relevant

### Good Pattern: Reviewer Gate Before Completion

- implementer signals `proposed` -> reviewer responds `needs-clarification` with one blocking finding
- implementer remediates and re-handoffs with updated evidence
- reviewer marks `complete`; lead publishes final completion summary

Why this is good:

- review is independent
- completion is evidence-backed
- blocking risk is resolved before closeout

### Anti-Pattern: Tracker-As-Message-Bus

- specialists post frequent internal routing chatter directly in issue comments
- no structured local handoff payloads exist
- human thread becomes noisy while key risks stay implicit

Why this is bad:

- violates local coordination rule
- hides ownership boundaries
- reduces human signal quality

### Anti-Pattern: Implicit Ownership Drift

- lead asks multiple specialists to "help anywhere"
- overlapping edits proceed without explicit owner-of-record transitions
- completion is claimed without reviewer/validator acceptance signals

Why this is bad:

- creates responsibility ambiguity
- increases rework and integration risk
- weakens completion trust

## Integration With Existing Contracts

This document is the canonical role-and-handoff contract for generated execution behavior.

Related documents should reference this contract rather than redefining role and handoff rules independently:

- tier-selection heuristics: [`docs/orchestration-execution-rubric.md`](./orchestration-execution-rubric.md)
- generated metadata and review expectations: [`docs/generated-skill-layout.md`](./generated-skill-layout.md)
- external task/update boundaries: [`docs/task-system-provider-fragment-set.md`](./task-system-provider-fragment-set.md) and [`docs/code-host-review-provider-fragment-set.md`](./code-host-review-provider-fragment-set.md)
