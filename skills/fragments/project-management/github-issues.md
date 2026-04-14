---
schema_version: 1
id: project-management/github-issues
title: GitHub Issues
fragment_type: provider
layer: project-management
summary: Use GitHub Issues as the system of record for task intake, progress logging, and traceability.
provider: github
capabilities:
  - task-tracker.read
  - task-tracker.update
selection:
  evidence_any:
    - forge.github
    - task_tracker.github_issues
    - repo.references_issue_numbers
  evidence_all: []
  evidence_none: []
  requires_confirmation:
    - forge.github_without_confirmed_issue_workflow
  preference: 85
composition:
  requires: []
  suggests:
    - orchestration/team-sizing
    - delivery/pull-request-review
  conflicts:
    - project-management/jira
  exclusive_within:
    - primary-task-tracker
  emits:
    - task-intake
    - task-status-updates
  order: 20
---

# Fragment: GitHub Issues

## Purpose

Use GitHub Issues as the system of record for task intake, progress logging, and traceability.

## Include When

- The repository uses GitHub as its primary forge.
- Issues are actively referenced in branches, commits, or PRs.
- The team wants implementation agents to read and update issue context directly.

## Expected Behaviors

- Read the issue before planning or implementation starts.
- Extract acceptance criteria into an explicit checklist.
- Post meaningful status updates when the workflow spans multiple phases or agents.
- Link PRs, validation evidence, and follow-up work back to the issue.

## Builder Notes

- Pair well with `orchestration/team-sizing.md`.
- Pair well with `delivery/pull-request-review.md`.
- If GitHub is present but issues are not used, omit this fragment and prefer a lighter PR-only workflow.
