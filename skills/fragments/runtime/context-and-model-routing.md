---
schema_version: 1
id: runtime/context-and-model-routing
title: Context And Model Routing
fragment_type: generic
layer: runtime
summary: Guide agents to use context windows, tools, and model capability intentionally instead of wasting budget on every step.
capabilities:
  - runtime.context-routing
  - runtime.model-routing
selection:
  evidence_any:
    - repo.large
    - repo.monorepo
    - workflow.parallel_agents
    - workflow.model_budget_matters
  evidence_all: []
  evidence_none: []
  preference: 65
composition:
  requires: []
  suggests:
    - orchestration/team-sizing
    - delivery/pull-request-review
  conflicts: []
  exclusive_within: []
  emits:
    - context-budgeting
    - model-routing-rules
  order: 80
---

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
