---
schema_version: 1
id: project-management/github-issues
title: GitHub Issues
fragment_type: provider
layer: project-management
summary: Use GitHub Issues as the tracked-task system of record when the project actually manages work there.
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
  evidence_none:
    - repo.no_individual_repo_issues
  requires_confirmation:
    - forge.github_without_confirmed_issue_workflow
  preference: 85
composition:
  requires: []
  suggests:
    - orchestration/team-sizing
    - delivery/pull-request-review
  conflicts:
    - project-management/github-projects
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

Use GitHub Issues as the tracked-task system of record when the project manages implementation work there.

## Include When

- The repository uses GitHub as its primary forge.
- Issues are actively referenced in branches, commits, or PRs.
- The team wants issue-backed work to be read from and summarized back to GitHub.

## Expected Behaviors

- Read the issue before planning or implementation starts for issue-backed work.
- Extract acceptance criteria into an explicit checklist.
- Post meaningful status updates when the workflow spans multiple phases or agents.
- Link PRs, validation evidence, and follow-up work back to the issue.

## Builder Notes

- Pair well with `orchestration/team-sizing.md`.
- Pair well with `delivery/pull-request-review.md`.
- Exclude this fragment when repo evidence indicates GitHub Projects is authoritative and per-repo issue workflow is not.
- If GitHub is present but issues are not authoritative, omit this fragment and prefer direct-brief or lighter PR-only workflow guidance.
