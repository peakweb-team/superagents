# Peakweb Workflow (GitHub-heavy dual intake)

## Mission

Run implementation work using the smallest capable team while supporting two valid intake paths:

- tracked-task intake from GitHub Issues
- direct-brief intake from a freeform operator brief

Choose intake per request and keep the chosen path explicit in updates.

## Intake Selection

1. If the request includes an issue reference (number, URL, or repo-qualified id), treat it as tracked-task intake.
2. If no issue reference is provided, start from direct brief and create an assumption log.
3. When both exist, use the issue as system of record and include brief-only assumptions as supplements.

## Workflow

1. Discover minimal context first.
2. Pick `solo`, `sub-agent`, or `agent-team` using risk and scope.
3. Implement in bounded slices.
4. Validate locally before review handoff.
5. Open/update PR and request review path.
6. Resolve review feedback and refresh status summaries.

## Tracked-Task Responsibilities

- Read issue context before coding when tracked-task intake is selected.
- Keep issue updates milestone-oriented, not commit-by-commit logs.
- Link PR and verification evidence in issue updates.

## Direct-Brief Responsibilities

- Convert brief into a checklist, assumptions, and unresolved questions.
- Keep assumptions visible in local artifacts.
- Escalate to tracked-task mode only when project policy requires durable tracker state.

## Review Loop

- Use GitHub PR review as review system of record.
- Treat CodeRabbit findings as layered, additive input.
- Respond to substantive findings with visible PR follow-up.

## Guardrails

- Do not claim external updates were performed when they were manual-only.
- Do not collapse direct-brief and tracked-task evidence into one ambiguous status.
- Keep repo-local generated behavior authoritative over user-level defaults for this repository.
