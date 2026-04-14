# Fragment: Jira

## Purpose

Use Jira as the planning and delivery source of truth while keeping implementation behavior aligned with ticket discipline.

## Include When

- The team references Jira issue keys in branch names, commits, or PR titles.
- The repository or docs mention Jira workflows, statuses, or ceremonies.
- Delivery requires explicit traceability back to Jira tickets.

## Expected Behaviors

- Resolve the active Jira issue before making implementation decisions.
- Preserve ticket keys in branch and PR metadata.
- Translate Jira acceptance criteria into an implementation checklist.
- Report blockers, status changes, and review readiness in Jira-compatible language.

## Builder Notes

- Prefer this over the GitHub Issues fragment when Jira is the authoritative tracker.
- If both Jira and GitHub Issues are used, define one as primary and the other as reference-only.
