---
schema_version: 1
id: task-intake/portfolio-spec-decomposition
title: Portfolio-To-Spec Decomposition
fragment_type: generic
layer: task-intake
summary: Add a planning-oriented intake path that decomposes one portfolio/sprint planning object into multiple item specs without replacing single-item flow.
capabilities:
  - task-intake.batch-planning
  - task-intake.assumption-capture
selection:
  evidence_any:
    - input.batch_planning_object
    - workflow.sprint_kickoff_planning
    - workflow.parallel_work_bounded
  evidence_all: []
  evidence_none: []
  preference: 68
composition:
  requires:
    - task-intake/direct-brief
  suggests:
    - orchestration/team-sizing
    - runtime/context-and-model-routing
  conflicts: []
  exclusive_within: []
  emits:
    - spec-planning-batch
    - decomposition-ordering
    - item-readiness-gating
  order: 15
---

# Fragment: Portfolio-To-Spec Decomposition

## Purpose

Add a planning-oriented intake path that can turn one portfolio/sprint planning input into multiple implementation-ready item specs in a single run.

## Include When

- Sprint or milestone kickoff often starts from one epic objective with many candidate implementation items.
- The team wants deterministic decomposition and ordering before implementation starts.
- Reviewers need one grouped batch index plus canonical per-item specs.

## Expected Behaviors

- Keep #68 single-item semantics intact for one-item intake.
- When intake includes multiple candidate items, decompose into independently reviewable item specs.
- Generate a minimum spec package per item with independent acceptance criteria and handoff state.
- Preserve item-scoped decisions and unresolved questions instead of collapsing to one batch verdict.
- Produce a batch summary/index with suggested execution waves and links to canonical `.agency/specs/<item-slug>.md` artifacts.

## Builder Notes

- This fragment is additive to direct-brief intake, not a replacement.
- Pair with orchestration and runtime fragments to keep decomposition deterministic and budget-aware.
- Follow [`docs/portfolio-to-spec-decomposition-workflow.md`](../../../docs/portfolio-to-spec-decomposition-workflow.md) and [`docs/spec-batch-planning-contract.md`](../../../docs/spec-batch-planning-contract.md) for artifact and readiness rules.
