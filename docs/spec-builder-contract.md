# Spec Builder Contract

This document defines the Milestone 4 contract for adding a pre-implementation spec-builder to Superagents.

It builds on:

- portfolio orchestration direction in [`ROADMAP.md`](../ROADMAP.md)
- capability semantics in [`docs/external-capability-model.md`](./external-capability-model.md)
- task-system provider behavior in [`docs/task-system-provider-fragment-set.md`](./task-system-provider-fragment-set.md)
- role ownership and handoff expectations in [`docs/orchestration-role-handoff-contract.md`](./orchestration-role-handoff-contract.md)

## Why This Exists

Superagents already supports direct-brief and tracked-task intake for implementation.

Milestone 4 adds a missing layer: a deterministic way to convert a brief or portfolio objective into a specification artifact and tracked implementation ticket before coding starts.

The spec-builder is this layer.

## Scope

The spec-builder covers:

- pre-implementation specification authoring
- issue/ticket creation or update for implementation intake
- role routing for who writes and reviews spec content
- storage-of-record behavior for spec artifacts

The spec-builder does not replace implementation, review, or validation flows after the spec is accepted.

## Core Workflow

1. Intake source is identified.
2. Spec-builder selects the smallest capable authoring team.
3. Team drafts implementation-ready spec content.
4. Spec artifact is stored in the configured system of record.
5. Lead marks handoff state as `ready-for-build` or `needs-clarification`.
6. Implementation flow starts only after `ready-for-build`.

## Role Routing Rules

Default pre-build team:

- one product owner role for outcome clarity
- one project management role for scope and sequencing clarity

Conditional specialists:

- architecture specialist when technical shape is non-trivial
- UX/design specialist when interaction behavior is high-risk
- compliance/security specialist when policy or risk constraints are material

Routing policy:

- start from the default two-role team
- add specialists only when risk/scope signals justify it
- keep one lead owner-of-record for final spec acceptance

## Minimum Spec Package

A spec is implementation-ready only when it includes:

- problem and desired outcome
- in-scope and out-of-scope boundaries
- acceptance criteria with testable completion conditions
- dependency and sequencing notes
- risk notes and open questions
- validation expectations and evidence requirements
- explicit handoff state (`ready-for-build` or `needs-clarification`)

## Storage-Of-Record Rules

### Tracker-Backed Path

When a primary task tracker is configured:

- create or update the tracked item via canonical task-tracker capabilities
- store the implementation-ready spec in the ticket/issue body or linked canonical artifact
- persist milestones and final completion summaries in the same tracker

### Direct-Brief Path

When no external tracker is configured:

- store a canonical local spec artifact at `.agency/specs/<slug>.md`
- ensure the artifact remains human-reviewable and versioned in the repository
- keep unresolved questions explicit until the spec reaches `ready-for-build`

### Dual Path

When both local and tracker paths are active:

- keep one canonical source of truth and one mirrored summary
- include stable cross-links between local spec and tracked ticket
- avoid divergent edits across the two records

## Handoff Contract To Implementation

The spec-builder hands off to implementation only with:

- `status: complete` for the spec-authoring handoff
- explicit `requested_action: implement`
- acceptance criteria attached in the handoff payload
- no unresolved high-risk items left un-escalated

If these conditions are not met, the handoff remains `needs-clarification` or `blocked`.

## Capability Alignment

Spec-builder behavior relies on canonical capabilities:

- `task-intake.direct-brief`
- `task-intake.assumption-capture`
- `task-tracker.lookup`
- `task-tracker.read`
- `task-tracker.create`
- `task-tracker.update`

This keeps spec authoring provider-neutral while still allowing provider-specific fragments to map behavior accurately.
