---
schema_version: 1
id: delivery/cross-repo-pr-bundle
title: Cross-Repo PR Bundle Orchestration
fragment_type: generic
layer: delivery
summary: Coordinate one logical delivery that spans multiple repository PRs with explicit dependency order, shared gates, and partial-failure recovery.
capabilities:
  - delivery.cross-repo-pr-bundle
  - validation-signal.read
selection:
  evidence_any:
    - workflow.cross_repo_delivery
    - workflow.multi_repo_prs
    - task_tracker.github_projects
    - output.cross-repo-spec
  evidence_all: []
  evidence_none: []
  preference: 83
composition:
  requires: []
  suggests:
    - project-management/github-projects
    - orchestration/team-sizing
    - delivery/pull-request-review
    - runtime/context-and-model-routing
  conflicts: []
  exclusive_within: []
  emits:
    - bundle-delivery-plan
    - bundle-readiness-gates
    - bundle-recovery-playbook
  order: 65
---

# Fragment: Cross-Repo PR Bundle Orchestration

## Purpose

Coordinate one logical feature delivered through multiple repository PRs while preserving dependency order, bundle-level readiness, and safe recovery when rollout is only partially successful.

## Include When

- One task or project item maps to two or more repository PRs.
- Merge or deploy order is constrained by technical dependencies.
- The team needs one bundle-level readiness decision instead of independent per-repo green lights.
- Rollback may differ per repository (for example, reversible web deploys plus irreversible on-chain actions).

## Expected Behaviors

### 1) Canonical Bundle Model

Define one bundle object for the delivery slice with:

- `task_ref`: tracker item key/url and owning project context.
- `prs`: repo-scoped PR entries (`repo`, `pr_number`, `branch`, `owner`, `status`).
- `dependency_graph`: explicit edges and execution order (`must_merge_after`, `must_deploy_after`).
- `shared_acceptance_criteria`: criteria that only pass when the full bundle behavior is correct.
- `release_gates`: bundle-wide and repo-local checks required before each transition.

When project-management emits `cross-repo-spec`, consume it as the canonical bundle input and preserve traceable links from each repo PR back to the same bundle `task_ref`.

### 2) Merge And Deploy Choreography

Run bundle transitions in explicit phases:

1. Validate all repo PRs are open, scoped correctly, and mapped to the same `task_ref`.
2. Verify dependency prerequisites for the next repo in order.
3. Confirm required checks at repo level and bundle level.
4. Pause at configured human approval points before high-risk transitions.
5. Merge/deploy only the next eligible repo; then refresh bundle state before advancing.

Classify failures as:

- `blocking`: must halt bundle progression immediately.
- `non_blocking`: can continue only when policy explicitly allows degraded progression.

Default to blocking when dependency order, safety, or correctness is ambiguous.

### 3) Coordinated Readiness Gates

Do not mark the bundle merge/deploy-ready until all required gates pass:

- Repo PR gates: CI/test checks, required approvals, mergeability.
- Bundle gates: cross-repo integration checks, migration/contract compatibility checks, rollout-window constraints.
- Tracker gates: task/project item reflects current phase and unresolved blockers.

Treat missing status visibility as a degraded state that requires explicit human acknowledgement before progression.

### 4) Rollback And Forward-Fix Policy

For partial rollout failures, choose recovery path per dependency tier:

- Safe rollback path:
  - revert or rollback only when dependency and data contracts allow safe return to pre-bundle state.
  - record rollback scope, impact, and reopened follow-up tasks.
- Forward-fix path:
  - when rollback is infeasible, stabilize in dependency order with targeted patch PRs.
  - constrain blast radius by pausing downstream merges/deploys until forward-fix gates pass.

Always publish bundle recovery status back to the task tracker with current state, decision rationale, and next operator action.

### 5) Human Escalation Points

Require human confirmation at minimum for:

- entering any irreversible deployment step,
- overriding a blocking gate,
- proceeding with degraded validation visibility,
- choosing forward-fix over rollback for user-facing or compliance-sensitive impact.

Escalation records should include decision owner, timestamp, accepted risk, and required follow-up checks.

## Builder Notes

- Pair this fragment with `project-management/github-projects` when cross-repo item planning emits `cross-repo-spec`.
- Keep this fragment generic: provider-specific PR and status APIs should stay in provider fragments.
- Prefer explicit dependency graphs over implicit ordering assumptions.
