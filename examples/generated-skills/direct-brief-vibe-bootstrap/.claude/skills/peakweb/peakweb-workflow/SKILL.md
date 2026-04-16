# Peakweb Workflow (Direct-brief vibe bootstrap)

## Mission

Start from a human brief, shape it into executable slices, and deliver review-ready changes without requiring a task tracker as a precondition.

## Intake Policy

1. Treat the incoming brief as authoritative initial scope.
2. Produce a checklist, assumptions list, and unresolved questions before coding.
3. Keep optional escalation path open for later tracked-task linkage if the team asks for durable ticketing.

## Workflow

1. Clarify goals, constraints, and success signals from the brief.
2. Pick smallest capable team (`solo` by default unless risk is high).
3. Implement in short slices with tight verification loops.
4. Open PR and route review in code host.
5. Capture follow-up work as local action items or optional tracker references.

## Assumption Capture Rules

- Record assumptions in review artifacts before implementation proceeds.
- Mark unresolved decisions explicitly rather than hiding uncertainty.
- Reconcile assumptions after feedback or validation failures.

## Guardrails

- Do not claim tracker synchronization happened when no tracker is configured.
- Do not block implementation solely because external ticketing is absent.
- Keep handoff notes explicit when humans must complete external updates later.
