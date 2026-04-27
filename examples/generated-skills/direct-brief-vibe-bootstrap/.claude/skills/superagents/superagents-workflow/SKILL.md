# Superagents Workflow (Direct-brief vibe bootstrap)

## Mission

Start from a human brief, shape it into executable slices, and deliver review-ready changes without requiring a task tracker as a precondition.

## Intake Policy

1. Treat the incoming brief as authoritative initial scope.
2. Produce a checklist, assumptions list, and unresolved questions before coding.
3. Keep optional escalation path open for later tracked-task linkage if the team asks for durable ticketing.

## Workflow

1. Clarify goals, constraints, and success signals from the brief.
2. Pick smallest capable team (`solo` by default unless risk is high).
3. Resolve worktree mode (`off` default; task may override to `manual` or `auto`).
4. Implement in short slices with tight verification loops.
5. Open PR and route review in code host.
6. Capture follow-up work as local action items or optional tracker references.

## Worktree Strategy

- Default mode: `off`
- Task override allowed: yes (`off|manual|auto`)
- Resolution precedence: task override -> repository default -> `off`

In `manual`, emit explicit operator steps and wait for confirmation before changing files.
In `auto`, use deterministic task slug naming for branch/worktree, reuse valid task paths, and stop with remediation if path/branch context is ambiguous.

## Assumption Capture Rules

- Record assumptions in review artifacts before implementation proceeds.
- Mark unresolved decisions explicitly rather than hiding uncertainty.
- Reconcile assumptions after feedback or validation failures.

## Work Intake — Blocker Check

If the brief references a GitHub issue, read the issue body before proceeding. Check whether the body contains an open `## Blocked by` section.

- If a `## Blocked by` section is present and any listed blocker issue is still open, surface the blocker(s) to the operator and stop. Do not proceed with implementation until the operator confirms the blocker is resolved or explicitly overrides it.
- If the `## Blocked by` section is absent or all listed blockers are closed, proceed normally.

## Guardrails

- Do not claim tracker synchronization happened when no tracker is configured.
- Do not block implementation solely because external ticketing is absent.
- Keep handoff notes explicit when humans must complete external updates later.
