# Runtime Context-Budgeting And Repo-Reading Rules

This document defines the proposed contract for issue `#24`:

- [#24 Define context-budgeting and repo-reading rules](https://github.com/peakweb-team/pw-agency-agents/issues/24)

It builds on:

- the runtime-efficiency direction in [`ROADMAP.md`](../ROADMAP.md)
- the orchestration tiering rubric in [`docs/orchestration-execution-rubric.md`](./orchestration-execution-rubric.md)
- the role and handoff contract in [`docs/orchestration-role-handoff-contract.md`](./orchestration-role-handoff-contract.md)
- the builder inventory contract in [`docs/builder-inventory-workflow.md`](./builder-inventory-workflow.md)
- the builder questionnaire contract in [`docs/builder-questionnaire-flow.md`](./builder-questionnaire-flow.md)
- the fragment assembly contract in [`docs/fragment-assembly-rules.md`](./fragment-assembly-rules.md)

## Why This Exists

Generated skills need one provider-neutral runtime policy for how much context to load, how to read repositories efficiently, and when to expand scope.

Without this contract, large repos risk wasteful full-repo reading while small tasks risk unnecessary orchestration overhead.

## Goals

- define context-budgeting guidance that works across `solo`, `sub-agent`, and `agent-team`
- define repo-reading heuristics for small tasks and large multi-package repositories
- define file-discovery and selective-reading behavior before deep file ingestion
- define progressive context-expansion rules that are deterministic and reviewable
- include concrete examples and anti-patterns for generated execution behavior

## Non-Goals

- prescribing provider-specific model APIs or token limits
- requiring one static budget number for every runtime/provider
- replacing tier-selection or handoff contracts

## Core Policy

### Progressive Context First

Generated execution should load context in stages instead of front-loading full repositories.

Default sequence:

1. discover
2. select
3. deepen
4. execute
5. verify

### Smallest Useful Read Wins

Agents should read the minimum material required to make the next correct decision.

When uncertainty remains high after selective reading, widen scope deliberately and record why.

### Provider-Neutral Budgeting

Budgets should be expressed as behavior constraints, not provider-specific token promises.

Examples of acceptable constraints:

- number of files deeply read before first implementation attempt
- number of directories scanned before escalating to broader discovery
- maximum re-read loops before requesting clarification

## Context Budget Levels

Generated skills should use these qualitative budget levels:

- `narrow`
  - single-scope changes, low ambiguity, one primary subsystem
- `medium`
  - bounded multi-file or cross-layer changes with moderate ambiguity
- `wide`
  - multi-package, multi-domain, or high-ambiguity work requiring broader synthesis

Budget selection should align with the orchestration tier:

- `solo`: start `narrow`, escalate to `medium` only with explicit trigger
- `sub-agent`: lead may use `medium`; specialists should usually start `narrow`
- `agent-team`: allow `medium` to `wide`, but require explicit ownership boundaries and scoped handoff payloads

## Repo-Reading Heuristics

### Discovery Phase

Before opening many files, gather structural signals:

- top-level directory map
- workspace/package manifests
- build/test/tooling entry points
- task-relevant docs and ownership hints
- recent files touched in the current task context when available

Discovery should prefer fast listing/search operations over broad file-body reads.

### Selective-Reading Phase

After discovery, select a bounded candidate set.

Selection priorities:

1. files directly named by issue/task acceptance criteria
2. files referenced by tests failing for the target behavior
3. files imported or called by candidate implementation entry points
4. contract docs that define constraints for the target area

Avoid deep-reading unrelated sibling packages during this phase.

### Deep-Reading Phase

Perform full-content reads only for files in the current candidate set and immediate dependencies.

Escalate to broader reading only when one of the following occurs:

- repeated ambiguity after two focused passes
- evidence of cross-package coupling that can affect correctness
- risk signals indicate high blast radius

When escalating, record what triggered broader reading and which new areas were added.

## Small Task Vs Large Repo Behavior

### Small Task Behavior

Expected shape:

- start in `solo` with `narrow` budget
- discover at repo root and target package only
- deeply read only task-local files plus nearest tests
- implement and verify before expanding scope

Example:

- issue asks to clarify one contract section in `docs/orchestration-role-handoff-contract.md`
- discovery finds no code coupling requirements
- read target doc and directly linked contracts only
- produce focused edit and coherence check

### Large Repo / Multi-Package Behavior

Expected shape:

- start with `medium` budget and explicit discovery boundaries
- map packages/apps before selecting candidate files
- route independent slices to `sub-agent` specialists when bounded decomposition is clear
- keep each specialist on a narrow file subset; lead integrates and resolves cross-slice risk

Example:

- issue requires API contract change plus CLI integration plus docs updates in a monorepo
- lead maps impacted packages (`apps/api`, `apps/cli`, `docs`)
- specialists own disjoint slices with explicit acceptance criteria
- lead escalates to wider reading only when integration tests reveal cross-package assumptions

## File-Discovery And Selective-Reading Rules

Generated skills should include these explicit runtime rules:

1. Start with path discovery (`rg --files`, workspace manifests, top-level docs) before content-heavy reads.
2. Use targeted search (`rg`) to locate symbols/phrases before opening whole files.
3. Read headings/sections first for long docs; deep-read only relevant sections unless contradiction appears.
4. For code, read call sites and tests nearest to the change before reading transitive dependencies.
5. Stop broad discovery once enough evidence exists to pick a bounded execution slice.
6. Re-open previously read files only when new evidence invalidates earlier assumptions.

## Progressive-Context Escalation Triggers

Escalate from `narrow` to `medium` or `wide` only when at least one trigger is true:

- unresolved ambiguity blocks safe implementation
- validation evidence conflicts with current assumptions
- ownership boundaries reveal hidden cross-domain dependency
- reviewer/validator finds a correctness risk requiring broader synthesis

Generated review metadata should summarize these escalations in human-readable form.

## Good Patterns

### Good Pattern: Bounded Discovery Before Editing

- list repo structure and search for target symbols
- select 3-8 candidate files
- deep-read only selected files
- implement, verify, and stop

Why this is good:

- minimizes context waste
- keeps reasoning traceable
- scales to large repos

### Good Pattern: Lead-Wide, Specialist-Narrow

- lead reads medium-scope architecture context
- specialists receive scoped handoffs with explicit file boundaries
- specialists avoid full-repo rereads

Why this is good:

- preserves coherence without redundant context loading
- aligns with `sub-agent` and `agent-team` handoff contracts

## Anti-Patterns

### Anti-Pattern: Full Repo Slurp Up Front

- agent reads broad directory trees and dozens of full files before identifying target slice

Why this is bad:

- high cost and latency
- increases stale-context risk
- obscures which evidence actually mattered

### Anti-Pattern: Blind Narrowness

- agent refuses to widen context even after repeated validation failures

Why this is bad:

- creates false confidence
- misses cross-package coupling
- can produce regressions in large repositories

### Anti-Pattern: Duplicate Multi-Agent Reading

- each specialist independently re-discovers the whole repo

Why this is bad:

- multiplies context cost with little quality gain
- undermines lead ownership and structured handoffs

## Integration With Existing Contracts

This document is the canonical runtime context-budgeting and repo-reading contract for generated execution.

Related docs should reference it rather than redefining these rules:

- builder inventory/questionnaire contracts for runtime signal and decision capture
- fragment assembly for deterministic runtime block composition
- orchestration tiering and handoff contracts for tier-compatible execution behavior
- generated-skill layout/review metadata for documenting escalation and assumptions
