---
schema_version: 1
id: delivery/pull-request-review
title: Pull Request Review
fragment_type: generic
layer: delivery
summary: Standardize how implementation work becomes a PR, how review is requested, and how reviewer feedback is handled.
capabilities:
  - delivery.pr-review
selection:
  evidence_any:
    - workflow.pull_requests
    - forge.github
    - forge.gitlab
  evidence_all: []
  evidence_none: []
  preference: 75
composition:
  requires: []
  suggests:
    - orchestration/team-sizing
    - runtime/context-and-model-routing
  conflicts: []
  exclusive_within: []
  emits:
    - review-loop
  order: 60
---

# Fragment: Pull Request Review

## Purpose

Standardize how implementation work becomes a PR, how review is requested, and how reviewer feedback is handled.

## Include When

- The repository uses PR-based delivery.
- The team expects agents to open PRs and respond to review feedback.
- Reviewer automation such as CodeRabbit materially changes the loop.

## Expected Behaviors

- Open a PR only after local validation is complete enough for meaningful review.
- Keep the PR body current with scope, evidence, and known risks.
- Request the correct reviewer path for the project: CodeRabbit, human maintainers, or both.
- Treat reviewer feedback as a tracked work queue, then refresh the PR summary after follow-up commits.

## Builder Notes

- Extend this fragment with project-specific reviewer instructions when tools like CodeRabbit are detected.
- Pair with runtime guidance so large review loops do not waste context or expensive model calls.
