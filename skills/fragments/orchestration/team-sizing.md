# Fragment: Team Sizing

## Purpose

Select the smallest capable agent team for a task based on scope, risk, and domain breadth.

## Include When

- The project benefits from multi-agent execution instead of a single generalist.
- Work routinely spans implementation, review, and validation.
- The team wants explicit heuristics for when to stay solo versus coordinate specialists.

## Heuristics

- Solo: typo fixes, copy edits, tiny config changes, or isolated low-risk updates.
- Small team: one implementer, one reviewer, one verifier for most feature or bug work.
- Expanded team: add domain specialists when work spans frontend plus backend, infra plus security, or similar cross-cutting concerns.
- Escalate team size when acceptance criteria are numerous, the blast radius is high, or integration points are unclear.

## Builder Notes

- This fragment should usually be present in the primary orchestration skill.
- Combine with project-management and delivery fragments to make team decisions actionable.
