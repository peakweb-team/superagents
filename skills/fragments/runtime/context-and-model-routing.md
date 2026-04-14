# Fragment: Context And Model Routing

## Purpose

Guide agents to use context windows, tools, and model capability intentionally instead of wasting budget on every step.

## Include When

- The repository is large, multi-package, or otherwise expensive to load wholesale.
- The team uses different models for planning, coding, and review.
- The workflow depends on parallel agents or bounded specialist tasks.

## Expected Behaviors

- Read only the files needed to answer the current question.
- Prefer cheap discovery before expensive deep reasoning.
- Escalate to stronger models only for ambiguous architecture, high-risk review, or synthesis-heavy tasks.
- Keep subtasks narrow so composed teams do not duplicate effort.

## Builder Notes

- This fragment is especially useful for monorepos and multi-agent execution.
- It complements team sizing by preventing oversized teams from also becoming oversized context consumers.
