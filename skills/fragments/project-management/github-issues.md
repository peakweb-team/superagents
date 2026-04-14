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
