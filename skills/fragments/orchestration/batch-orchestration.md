---
schema_version: 1
id: orchestration/batch-orchestration
title: Batch Orchestration
fragment_type: generic
layer: orchestration
summary: Behavioral patterns for multi-PR batch delivery runs — CR rate-limit handling, sibling conflict resolution, chained-PR retargeting, pre-merge follow-up filing, comment attribution, operator-paired issue filing, specialist dispatch, and anti-idle discipline.
capabilities:
  - orchestration.batch-delivery
  - orchestration.specialist-dispatch
  - orchestration.anti-idle
selection:
  evidence_any:
    - workflow.pull_requests
    - forge.github
    - forge.gitlab
  evidence_all: []
  evidence_none: []
  preference: 55
composition:
  requires: []
  suggests:
    - orchestration/team-sizing
    - delivery/pull-request-review
    - runtime/context-and-model-routing
  conflicts: []
  exclusive_within: []
  emits:
    - batch-orchestration-rules
  order: 45
---

# Fragment: Batch Orchestration

## Purpose

Provide behavioral patterns for orchestrating multi-PR batch delivery runs where several PRs are in flight simultaneously.

## Include When

- The project dispatches batch runs (e.g., "work through every groomed issue tonight").
- Multiple PRs are opened in the same session and may conflict on shared files.
- The operator expects the orchestrator to stay productive between CR reviews, merges, or preview deploys.
- Chained PRs (PR B based on `feat/A`) are part of the delivery pattern.

## Patterns Covered

1. **CodeRabbit rate-limit handling** — move to other PRs when CR is cooling down; do not spam re-review; track with a background poll.
2. **Sibling conflict resolution** — merge (not rebase) when a sibling PR lands on `main`; regenerate lockfiles; cascade through chained PRs.
3. **Chained-PR retargeting** — retarget chained PRs at `main` the moment their base merges; recover if out-of-order merge already occurred; manually close issues that auto-close doesn't reach.
4. **Pre-merge follow-up filing** — sweep unchecked AC, deferred CR nits, out-of-scope callouts, and TODO comments; file issues before requesting merge.
5. **CodeRabbit thread reply discipline** — every CR comment gets `Addressed in <sha>`, `Disputed`, or `Deferred to #N`; code alone is not enough.
6. **Agent-comment attribution tagging** — prefix every orchestrator-posted comment with the blockquoted attribution line so the operator can distinguish their own feedback from agent output.
7. **Operator-paired work as separate issues** — steps the orchestrator cannot do autonomously go into their own `chore:` follow-up issues with full AC, not buried in PR body runbooks.
8. **Specialist-team-per-input dispatch** — when N independent inputs each consume meaningful context, dispatch one specialist agent per input in parallel rather than sequentially in the orchestrator session.
9. **Anti-idle discipline** — when waiting (CR rate limit, preview deploy, operator merge), find the next useful thing; only set a timer when genuinely nothing else can move forward.

## Builder Notes

- Include this fragment alongside `delivery/pull-request-review` for projects that regularly run batch sessions.
- This fragment is additive — it extends the primary workflow skill's PR loop rather than replacing it.
- Pair with `orchestration/team-sizing` so specialist-dispatch decisions are grounded in the team-sizing heuristics.
