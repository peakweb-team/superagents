# Superagents Runtime Guardrails

## Purpose

Control context and model cost in a mixed-tool workflow with Jira plus GitHub review loops.

## Rules

- Prefer targeted ticket/PR reads over broad repo scans.
- Keep implementation slices aligned to one acceptance milestone at a time.
- Escalate to stronger reasoning tier only for ambiguous cross-service changes.
- Re-check Jira and PR status surfaces before final completion summary.
