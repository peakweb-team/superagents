# Builder Review Summary

## Scenario

Jira-heavy task tracking with GitHub PR delivery and dual intake support.

## Why This Shape Was Generated

- Jira key evidence and workflow docs strongly indicated Jira as tracker of record.
- GitHub remained the delivery review-of-record path.
- Direct-brief intake was preserved for exploratory work and early discovery slices.
- Worktree default was set to `manual` to preserve operator control in mixed-permission enterprise repos.

## Warnings And Manual Follow-Up

- `task-tracker.update` is marked `manual` due partial Jira update permissions.
- Reviewers should confirm every tracked-task completion includes explicit Jira update evidence.
- Task-level worktree override remains enabled for cases where `auto` isolation is safe and preferred.

## Reviewer Checklist

- Confirm Jira remains tracker of record for durable delivery tasks.
- Confirm manual Jira-update step is acceptable for this team.
- Confirm direct-brief work is still allowed before ticket linkage.
- Confirm task updates show resolved worktree mode and any manual setup steps used.
