---
schema_version: 1
id: orchestration/team-sizing
title: Team Sizing
fragment_type: generic
layer: orchestration
summary: Select the smallest capable agent team for a task based on scope, risk, and domain breadth.
capabilities:
  - orchestration.team-sizing
selection:
  evidence_any:
    - repo.multi_step_delivery
    - repo.cross_functional_changes
    - workflow.review_and_validation_expected
  evidence_all: []
  evidence_none: []
  preference: 70
composition:
  requires: []
  suggests:
    - project-management/github-issues
    - project-management/jira
    - delivery/pull-request-review
    - runtime/context-and-model-routing
  conflicts: []
  exclusive_within: []
  emits:
    - team-sizing-rules
  order: 40
---

# Fragment: Team Sizing

## Purpose

Select the smallest capable agent team for a task based on scope, risk, and domain breadth.

## Include When

- The project benefits from multi-agent execution instead of a single generalist.
- Work routinely spans implementation, review, and validation.
- The team wants explicit heuristics for when to stay solo versus coordinate specialists.

## Heuristics

- Solo: typo fixes, copy edits, tiny config changes, or isolated low-risk updates.
- Small team: one implementer, one reviewer, one verifier for most feature or bug work.
- Expanded team: add domain specialists when work spans frontend plus backend, infra plus security, or similar cross-cutting concerns.
- Escalate team size when acceptance criteria are numerous, the blast radius is high, or integration points are unclear.

## Worktree Isolation (Optional)

Treat worktree usage as a configurable execution strategy, not a universal requirement.

- `off`: run in the current checkout with no worktree management.
- `manual`: provide explicit operator steps for selecting/creating a task worktree.
- `auto`: create or reuse deterministic task worktrees and branch context automatically.

When task-level override is enabled, resolve mode in this order:

1. task override
2. repository default
3. safe fallback `off`

In `auto`, do not continue silently after path or branch ambiguity. Surface actionable remediation and keep behavior non-destructive.

## Builder Notes

- This fragment should usually be present in the primary orchestration skill.
- Combine with project-management and delivery fragments to make team decisions actionable.
