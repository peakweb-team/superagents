---
schema_version: 1
id: project-management/github-projects
title: GitHub Projects
fragment_type: provider
layer: project-management
summary: Use GitHub Projects as the tracked-task system of record for org-level and cross-repo delivery workflows.
provider: github
capabilities:
  - task-tracker.read
  - task-tracker.update
selection:
  evidence_any:
    - forge.github
    - task_tracker.github_projects
    - repo.monorepo
    - repo.no_individual_repo_issues
  evidence_all: []
  evidence_none: []
  requires_confirmation:
    - forge.github_without_confirmed_projects_workflow
  preference: 88
composition:
  requires: []
  suggests:
    - orchestration/team-sizing
    - delivery/pull-request-review
    - runtime/context-and-model-routing
  conflicts:
    - project-management/github-issues
    - project-management/jira
  exclusive_within:
    - primary-task-tracker
  emits:
    - task-intake
    - task-status-updates
    - cross-repo-spec
  order: 20
---

# Fragment: GitHub Projects

## Purpose

Use GitHub Projects as the tracked-task system of record when the team coordinates delivery at org level or across multiple repositories.

## Include When

- The repository uses GitHub and delivery is tracked primarily in GitHub Projects instead of per-repo Issues.
- Work commonly spans multiple repositories or packages with one shared planning board.
- The team needs project-item status updates that respect dynamic field and option IDs.

## Expected Behaviors

### Field And Option ID Discovery Is Mandatory Before Status Writes

Before any status write, discover node IDs at runtime for the specific project:

1. Run `gh project field-list <N> --owner <org> --format json`.
2. Resolve the status field id (`PVF_*`).
3. Resolve the status option id (`PVSO_*`) for the target value.
4. Resolve item id (`PVTI_*`) and project id (`PVT_*`) from item/project context.

Do not hardcode or cross-session cache GitHub Projects node IDs.

### Cross-Repo Spec Extraction

When item content includes this canonical shape:

- `## Repos`
- repo-scoped bullets
- `## Acceptance Criteria`

extract one scoped implementation spec per repository before routing execution.

When the shape is missing, infer scope from the item title/body and surface the inferred scope to a human reviewer before implementation starts.

### Draft Item And Linked-Issue Handling

- Linked issue item: read both the project item and the linked issue before planning.
- Draft item: rely on project item title/body only and do not attempt to follow issue URLs.

### Degraded Mode For Status Updates

If metadata discovery fails, do not block implementation.

- Surface exact commands for manual recovery:
  - `gh project list --owner <org> --format json`
  - `gh project item-list <N> --owner <org> --format json`
  - `gh project field-list <N> --owner <org> --format json`
  - `gh project item-edit --id <PVTI_*> --field-id <PVF_*> --project-id <PVT_*> --single-select-option-id <PVSO_*>`
- Continue implementation cycle without automated status write.
- Mark status update as degraded/manual in review metadata.

## CLI Reference

Use these commands as the baseline GitHub Projects workflow:

- `gh project list --owner <org> --format json`
- `gh project item-list <N> --owner <org> --format json`
- `gh project field-list <N> --owner <org> --format json`
- `gh project item-edit --id <PVTI_*> --field-id <PVF_*> --project-id <PVT_*> --single-select-option-id <PVSO_*>`
- `gh project item-create <N> --owner <org> --title "<title>"`

## Builder Notes

- Prefer this fragment over `project-management/github-issues` when signals indicate monorepo/cross-repo delivery with no authoritative per-repo issue workflow.
- Pair with orchestration and review fragments so cross-repo scoped specs become executable handoffs.
