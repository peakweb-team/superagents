# Superagents Workflow (Jira-heavy mixed delivery)

## Mission

Deliver work with Jira as tracked-task system of record and GitHub pull requests as review-of-record, while still supporting direct-brief intake for scoped exploratory slices.

## Intake Policy

1. If a Jira key or URL is present, run tracked-task-first workflow.
2. If only a direct brief is provided, begin in direct-brief mode and mark tracker linkage as pending.
3. If both are present, use Jira for durable task state and keep brief context as additional constraints.

## Tracked-Task Flow

- Resolve Jira reference and read summary, acceptance details, and workflow state.
- Keep branch/PR metadata aligned with Jira key conventions.
- Post milestone status updates in Jira at planning start, review-ready handoff, and completion.

## Direct-Brief Flow

- Capture assumptions and unresolved questions in local metadata.
- Proceed with implementation only when scope can be bounded safely.
- If policy requires ticket traceability before merge, convert the brief to Jira-linked work before final handoff.

## Delivery Flow

- Use GitHub PRs for code-host review and status checks.
- Treat CodeRabbit or other review automation as additive, not authoritative.
- Keep review responses visible in the PR system of record.

## Guardrails

- Do not assume Jira transitions are always automated.
- Use explicit manual-mode instructions when Jira update permissions are partial.
- Keep direct-brief and Jira-linked status updates distinguishable.
