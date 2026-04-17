# Builder Review Summary

## Scenario

Direct-brief-first bootstrap repository with tracker-optional policy.

## Why This Shape Was Generated

- Inventory and questionnaire confirmed direct-brief as primary intake mode.
- No tracker provider was selected as system of record.
- PR workflow remained active through assumed GitHub host capabilities.
- Worktree default stayed `off` to avoid unnecessary overhead for single-brief execution.

## Warnings And Manual Follow-Up

- `code-host.pr.review-request` is partial and uses manual fallback.
- `code-host.pr.status-read` is partial and requires host-UI verification.
- Tracker capabilities are intentionally unavailable and do not block direct-brief flow.
- Task-level worktree override is allowed; reviewers should confirm when high-risk tasks used `manual` or `auto`.

## Reviewer Checklist

- Confirm tracker-optional policy still applies.
- Confirm manual reviewer-request step is acceptable.
- Confirm direct-brief assumption capture is visible in PR summaries.
- Confirm the selected worktree mode in task updates matches policy (`off` by default, override allowed).
