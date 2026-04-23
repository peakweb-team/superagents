---
schema_version: 1
id: project-management/jira
title: Jira
fragment_type: provider
layer: project-management
summary: Use Jira as the tracked-task source of truth when the project manages delivery through Jira.
provider: jira
capabilities:
  - task-tracker.read
  - task-tracker.update
selection:
  evidence_any:
    - task_tracker.jira
    - repo.references_jira_keys
    - docs.references_jira_workflows
  evidence_all: []
  evidence_none: []
  requires_confirmation:
    - forge.github_with_possible_jira_reference_only
  preference: 90
composition:
  requires: []
  suggests:
    - orchestration/team-sizing
    - delivery/pull-request-review
  conflicts:
    - project-management/github-issues
    - project-management/github-projects
  exclusive_within:
    - primary-task-tracker
  emits:
    - task-intake
    - task-status-updates
  order: 20
---

# Fragment: Jira

## Purpose

Use Jira as the tracked-task source of truth when the project manages delivery through Jira.

## Include When

- The team references Jira issue keys in branch names, commits, or PR titles.
- The repository or docs mention Jira workflows, statuses, or ceremonies.
- Delivery requires explicit traceability back to Jira tickets.

## Expected Behaviors

- Resolve the active Jira issue before making implementation decisions for tracked-task work.
- Preserve ticket keys in branch and PR metadata.
- Translate Jira acceptance criteria into an implementation checklist.
- Report blockers, status changes, and review readiness in Jira-compatible language.

## Builder Notes

- Prefer this over the GitHub Issues fragment when Jira is the authoritative tracker for tracked-task intake.
- Prefer this over the GitHub Projects fragment only when Jira, not GitHub Projects, is the authoritative source of truth.
- If both Jira and GitHub Issues are used, define one as primary and the other as reference-only.
