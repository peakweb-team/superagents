# Superagents Workflow (GitHub-heavy dual intake)

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
3. Resolve worktree mode (`auto` default; task may override to `off` or `manual`).
4. Implement in bounded slices.
5. Validate locally before review handoff.
6. Open/update PR and request review path.
7. Resolve review feedback and refresh status summaries.

## Worktree Strategy

- Default mode: `auto`
- Task override allowed: yes (`off|manual|auto`)
- Resolution precedence: task override -> repository default -> `off`

Use deterministic naming for task worktrees/branches. Reuse an existing path only when it maps to the same task context. If path or branch context is ambiguous, stop and emit remediation instead of continuing in-place.

## Work Intake — Blocker Check

After reading the issue, check whether the body contains an open `## Blocked by` section.

- If a `## Blocked by` section is present and any listed blocker issue is still open, surface the blocker(s) to the operator and stop. Do not proceed with implementation until the operator confirms the blocker is resolved or explicitly overrides it.
- If the `## Blocked by` section is absent or all listed blockers are closed, proceed normally.

Example stop message:

```
Issue #N is blocked by #M — <one-line reason>.
Resolve #M first or confirm an override before proceeding.
```

## Tracked-Task Responsibilities

- Read issue context before coding when tracked-task intake is selected.
- Apply the blocker check above before any implementation work begins.
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
