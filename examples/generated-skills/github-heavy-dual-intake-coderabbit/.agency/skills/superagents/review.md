# Builder Review Summary

## Scenario

GitHub-heavy repository with CodeRabbit layered review and dual intake support.

## Why This Shape Was Generated

- GitHub Issues evidence was strong and confirmed as primary tracked-task system.
- Direct brief remained enabled because the team explicitly allows exploratory work to start without an issue.
- CodeRabbit was included as additive review input, not review-of-record replacement.

## Warnings And Manual Follow-Up

- `review-feedback.read` is partial for CodeRabbit and marked `warn`; unresolved GitHub review threads remain the baseline queue.
- No manual-only capability bindings are active in this scenario.

## Reviewer Checklist

- Confirm direct-brief and tracked-task coexistence is still policy.
- Confirm CodeRabbit usage is additive and does not bypass human approval rules.
- Confirm runtime budget assumptions remain appropriate for current repo size.
