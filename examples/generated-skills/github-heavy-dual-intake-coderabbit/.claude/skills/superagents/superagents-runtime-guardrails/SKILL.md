# Superagents Runtime Guardrails

## Purpose

Constrain context and model usage so GitHub-heavy delivery loops remain efficient.

## Rules

- Start with narrow context and expand only when blocked.
- Prefer lower-cost model tiers for discovery and scaffolding.
- Escalate model strength only for ambiguous architecture or high-risk review.
- Split work into non-overlapping slices before delegating.
- Re-check merge readiness before claiming completion.
