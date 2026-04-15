---
schema_version: 1
id: task-intake/direct-brief
title: Direct Brief Intake
fragment_type: generic
layer: task-intake
summary: Allow work to begin from a freeform prompt or bootstrap brief instead of requiring an external ticket.
capabilities:
  - task-intake.direct-brief
selection:
  evidence_any:
    - input.direct_brief
    - workflow.bootstrap_greenfield_likely
    - workflow.task_tracker_optional
  evidence_all: []
  evidence_none: []
  preference: 70
composition:
  requires: []
  suggests:
    - orchestration/team-sizing
    - runtime/context-and-model-routing
  conflicts: []
  exclusive_within:
    - primary-intake-mode
  emits:
    - task-intake
    - assumption-capture
  order: 10
---

# Fragment: Direct Brief Intake

## Purpose

Allow work to begin from a freeform prompt or bootstrap brief instead of requiring an external ticket.

## Include When

- The project is greenfield, exploratory, or intentionally light-process.
- The team wants to support vibe-coding or bootstrap flows alongside tracked-task delivery.
- No authoritative external task tracker is present, or tracker usage is optional.

## Expected Behaviors

- Turn the incoming brief into a concrete checklist, assumptions list, and proposed delivery slice.
- Record notable assumptions and unresolved decisions explicitly so humans can review them later.
- Prefer lightweight local coordination unless and until the work merits durable human-facing tracking.
- Escalate into tracker-backed workflow only when the team or repository conventions require it.

## Builder Notes

- Pair well with `orchestration/team-sizing.md`.
- Pair well with `runtime/context-and-model-routing.md`.
- This fragment is a first-class alternative to task-system provider fragments, not just a fallback.
