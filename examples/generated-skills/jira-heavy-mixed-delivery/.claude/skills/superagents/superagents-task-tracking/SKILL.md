# Superagents Task Tracking (Jira)

## Purpose

Use Jira as the tracked-task source of truth while allowing direct-brief bootstrap work to coexist.

## Behavior

- Resolve Jira keys and URLs before planning tracked-task work.
- Convert Jira acceptance fields into an implementation checklist.
- Record blockers and review readiness in Jira-compatible language.
- If direct brief starts without Jira key, track assumptions locally and mark Jira linkage unresolved.
- Require Jira completion update before claiming tracked-task flow is done.
