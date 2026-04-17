# Orchestration Execution Rubric: Solo, Sub-Agent, And Agent-Team

This document defines the proposed contract for issue `#22`:

- [#22 Define solo, sub-agent, and agent-team heuristics](https://github.com/peakweb-team/pw-agency-agents/issues/22)

Related runtime routing follow-ons:

- [#25 Define model-routing and subtask-splitting heuristics](https://github.com/peakweb-team/pw-agency-agents/issues/25)
- [#55 Define reasoning-effort and token-budget heuristics](https://github.com/peakweb-team/pw-agency-agents/issues/55)

It builds on:

- the roadmap orchestration direction in [`ROADMAP.md`](../ROADMAP.md)
- the fragment schema contract in [`docs/fragment-schema.md`](./fragment-schema.md)
- the assembly contract in [`docs/fragment-assembly-rules.md`](./fragment-assembly-rules.md)
- the builder inventory and confidence model in [`docs/builder-inventory-workflow.md`](./builder-inventory-workflow.md)
- the builder questionnaire flow in [`docs/builder-questionnaire-flow.md`](./builder-questionnaire-flow.md)
- the generated-skill layout contract in [`docs/generated-skill-layout.md`](./generated-skill-layout.md)
- the role and handoff contract in [`docs/orchestration-role-handoff-contract.md`](./orchestration-role-handoff-contract.md)
- the runtime context-budgeting and repo-reading contract in [`docs/runtime-context-budgeting-and-repo-reading.md`](./runtime-context-budgeting-and-repo-reading.md)
- the Claude-first MVP constraints and implementation reality in [`docs/claude-first-mvp-strategy.md`](./claude-first-mvp-strategy.md)

## Why This Exists

The current contracts reference team sizing, but they do not yet define one canonical three-tier rubric for generated skills.

This document fills that gap and sets one consistent policy:

- prefer the smallest capable execution mode
- keep `sub-agent` as the default middle-tier escalation path for bounded parallel work
- reserve `agent-team` for cases where richer peer coordination materially improves outcomes

## Three-Tier Execution Model

Generated skills should classify task execution into exactly one of:

1. `solo`
2. `sub-agent`
3. `agent-team`

### `solo`

Use one primary agent end-to-end when the task is narrow and coordination overhead would exceed any parallelism benefit.

### `sub-agent`

Use one lead agent plus bounded delegated sub-agents for mostly independent slices.

This is the default escalation path once work no longer fits cleanly in `solo`.

### `agent-team`

Use a coordinated team pattern only when outcomes improve because agents must actively collaborate, share evolving state, or iterate jointly across boundaries.

This tier has the highest overhead and should be explicitly justified.

## Trigger Dimensions

Sizing decisions should evaluate five dimensions together:

1. scope
2. risk
3. ambiguity
4. domain breadth
5. coordination cost

The default move is upward only when one or more dimensions cross the next tier boundary and expected delivery quality improves.

## Tier Triggers

### `solo` Triggers

Default to `solo` when most of the following are true:

- scope: one bounded deliverable or a single linear implementation path
- risk: low blast radius and easy rollback/recovery
- ambiguity: requirements and acceptance criteria are mostly clear
- domain breadth: one primary domain (for example, one service or one doc contract)
- coordination cost: introducing multiple agents would create more overhead than value

### `sub-agent` Triggers (Default Middle Tier)

Escalate from `solo` to `sub-agent` when bounded parallel work is available and most of the following are true:

- scope: multiple work slices can progress in parallel with clear ownership boundaries
- risk: moderate risk that benefits from focused verification or specialist checks
- ambiguity: manageable uncertainty that can be isolated per slice
- domain breadth: two or more adjacent domains, but weak coupling between slices
- coordination cost: handoffs are lightweight and can be coordinated by a lead agent without persistent peer-to-peer discussion

Default rule:

- if the task is too large for `solo` but can still be decomposed into bounded, mostly independent subtasks, use `sub-agent` before considering `agent-team`

### `agent-team` Triggers (Constrained Use)

Escalate from `sub-agent` to `agent-team` only when richer peer coordination is materially beneficial and at least one of the following is true:

- scope: multiple slices require continuous co-design, not just parallel execution
- risk: high-impact changes where cross-checking and iterative peer review are part of correctness
- ambiguity: requirements are materially unclear and need multi-perspective synthesis while executing
- domain breadth: broad multi-domain coupling where local optimizations can conflict without active peer alignment
- coordination cost: higher coordination overhead is justified by lower rework risk or better final quality

`agent-team` should not be selected just because a task is "large." If bounded decomposition is viable, prefer `sub-agent`.

## Model-Assignment Caveat

When generated guidance references per-agent model assignment in `agent-team` setups, it must be framed as:

- best-effort
- forward-compatible guidance
- not guaranteed behavior in current implementations

Generated skills should avoid promising strict static per-agent model enforcement for `agent-team` execution.

## Worktree Isolation Strategy (Configurable)

Worktree isolation should be configurable, not universally forced.

Generated guidance should support exactly three modes:

1. `off`
2. `manual`
3. `auto`

### `off`

- do not create or manage worktrees
- execute in the current repository checkout
- default choice when no strong parallel-work signal exists

### `manual`

- do not create worktrees automatically
- emit explicit operator instructions for creating or selecting the task worktree
- continue only after the operator confirms the expected branch/worktree context

### `auto`

- create or reuse a task-scoped worktree automatically
- create or switch to the task branch in that worktree
- keep concurrent tasks isolated by branch and filesystem path

## Worktree Strategy Precedence

Worktree strategy resolution should be deterministic:

1. task-level override (if provided and valid)
2. repository default from generated metadata
3. safe fallback default: `off`

Generated review output should report both:

- the configured repository default
- the resolved per-task mode used for execution

## Deterministic Naming And Reuse Rules

When `auto` mode is active, generated guidance should use stable naming and reuse rules:

- derive a `task_slug` from issue/ticket id when available; otherwise use a sanitized short task label
- branch naming should stay deterministic for the same task input (for example `feat/<task_slug>`)
- worktree path should stay deterministic for the same task input under a configured root
- if the deterministic path already exists and points to the expected branch/task context, reuse it
- if the path exists but maps to a different task context, fail safely with clear remediation steps

The exact path root may vary by environment, but generated behavior should avoid ad hoc per-run naming that creates accidental collisions.

## Failure Handling Expectations

Worktree handling must be non-destructive.

Generated guidance should treat common failures explicitly:

- missing Git worktree support
- permission denied while creating worktree paths
- path conflict with unrelated existing directory
- branch conflict or detached `HEAD` ambiguity

Failure behavior by mode:

- `off`: continue normally (no worktree operations attempted)
- `manual`: emit operator actions and pause until context is corrected
- `auto`: either recover by reusing a valid existing task worktree or fail with actionable instructions; do not silently continue in an ambiguous checkout

## Example Task Classifications

### `solo` Examples

- update one contract document section with clear acceptance criteria
- implement a small bug fix in one service with localized tests
- adjust a single CI check message or script behavior without workflow redesign

### `sub-agent` Examples

- implement a feature with independent backend and frontend slices plus a bounded test/update slice
- update multiple docs/contracts where each file has distinct ownership and low coupling
- run parallel review/remediation passes for separate PR feedback clusters with one lead integrator

### `agent-team` Examples

- redesign a cross-cutting architecture that requires iterative tradeoffs across runtime, delivery, and integration contracts
- resolve a high-risk migration with intertwined data, API, and workflow changes requiring ongoing peer challenge
- coordinate a complex incident-response hardening effort where findings in one area continuously reshape work in others

## Integration With Existing Contracts

This rubric is the canonical sizing source for:

- orchestration fragment behavior (`orchestration/team-sizing`)
- builder decisions about execution defaults
- generated review metadata that explains why a tier was chosen
- role and handoff behavior that follows the selected tier (see [`docs/orchestration-role-handoff-contract.md`](./orchestration-role-handoff-contract.md))

Model-tier routing, reasoning-effort and token-budget heuristics, progressive context loading (`discover` -> `select` -> `deepen` -> `execute` -> `verify`), candidate-file budgeting, and bounded subtask-splitting heuristics are canonical in [`docs/runtime-context-budgeting-and-repo-reading.md`](./runtime-context-budgeting-and-repo-reading.md). This rubric should define tier selection, while runtime guidance defines how work is routed inside the selected tier.

Related contracts should reference this document rather than redefining tier boundaries independently.

## Contract Expectations For Generated Skills

Generated skills should:

- document the selected tier and short rationale in human-readable output
- keep escalation incremental (`solo` -> `sub-agent` -> `agent-team`)
- treat `sub-agent` as the default middle tier for bounded parallel work
- require explicit rationale before `agent-team` selection
- preserve the model-assignment caveat for `agent-team`
- apply context budgets progressively using the runtime contract instead of front-loading full-repo reads
- record repository-default worktree mode and honor valid task-level overrides using deterministic precedence

Generated skills should not:

- default to `agent-team` for generic "complexity" labels alone
- imply that higher agent count is always better
- promise guaranteed per-agent model pinning in team mode
- force worktree usage when repository policy is `off` or when task-level override selects `off`
