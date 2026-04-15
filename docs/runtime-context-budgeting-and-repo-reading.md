# Runtime Context-Budgeting, Repo-Reading, And Model-Routing Rules

This document defines the proposed contracts for issues:

- [#24 Define context-budgeting and repo-reading rules](https://github.com/peakweb-team/pw-agency-agents/issues/24)
- [#25 Define model-routing and subtask-splitting heuristics](https://github.com/peakweb-team/pw-agency-agents/issues/25)

It builds on:

- the runtime-efficiency direction in [`ROADMAP.md`](../ROADMAP.md)
- the orchestration tiering rubric in [`docs/orchestration-execution-rubric.md`](./orchestration-execution-rubric.md)
- the role and handoff contract in [`docs/orchestration-role-handoff-contract.md`](./orchestration-role-handoff-contract.md)
- the builder inventory contract in [`docs/builder-inventory-workflow.md`](./builder-inventory-workflow.md)
- the builder questionnaire contract in [`docs/builder-questionnaire-flow.md`](./builder-questionnaire-flow.md)
- the fragment assembly contract in [`docs/fragment-assembly-rules.md`](./fragment-assembly-rules.md)
- the generated-skill layout contract in [`docs/generated-skill-layout.md`](./generated-skill-layout.md)

## Why This Exists

Generated skills need one provider-neutral runtime policy for how much context to load, how to read repositories efficiently, how to split subtasks, and how to route model strength.

Without this contract, large repos risk wasteful full-repo reading, small tasks risk unnecessary orchestration overhead, and model selection becomes inconsistent and costly.

## Goals

- define context-budgeting guidance that works across `solo`, `sub-agent`, and `agent-team`
- define repo-reading heuristics for small tasks and large multi-package repositories
- define file-discovery and selective-reading behavior before deep file ingestion
- define progressive context-expansion rules that are deterministic and reviewable
- define provider-neutral model-routing heuristics for each collaboration tier
- define bounded subtask-splitting rules that minimize overlap and duplicate context loading
- include concrete examples and anti-patterns for generated execution behavior

## Non-Goals

- prescribing provider-specific model APIs, model names, or token limits
- requiring one static budget number for every runtime/provider
- replacing tier-selection or handoff contracts
- assuming static per-agent model pinning is guaranteed in `agent-team`

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

### Cheapest Capable Model Wins

Generated skills should route to the least expensive model tier that can still satisfy correctness and delivery-risk needs for the current step.

Escalate model strength only when explicit triggers fire, and record escalation reasons in review metadata.

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

## Model-Tier Vocabulary

Generated guidance should use provider-neutral model tiers:

- `economy`: lowest-cost reliable tier for routine and low-risk work
- `balanced`: default tier for most implementation and integration work
- `strong`: highest-reasoning tier for ambiguity, high risk, and cross-domain synthesis

Generated skills may map local/provider model names onto these tiers, but runtime behavior should reason in terms of these tier semantics.

## Model-Routing Heuristics By Collaboration Tier

### `solo`

Default routing:

- planning for clear tasks: `economy`
- implementation in one bounded area: `balanced`
- validation and basic regression checks: `balanced`

Escalate to `strong` only when explicit escalation triggers are met.

### `sub-agent`

Default routing:

- lead planning/integration and ambiguity resolution: `balanced` (or `strong` when high risk)
- specialist implementation slices: `economy` or `balanced` depending on complexity
- specialist validation/reviewer slices: `balanced`, escalate to `strong` for contentious findings

Sub-agent routing should prioritize bounded task-type fit over uniform model assignment.

### `agent-team`

Default routing:

- use only when tier triggers in [`docs/orchestration-execution-rubric.md`](./orchestration-execution-rubric.md) justify richer coordination
- treat per-agent model assignment as advisory metadata, not a correctness guarantee
- require at least one owner-of-record (typically lead) to run at `strong` when correctness depends on cross-role synthesis

Advisory-only caveat:

- generated skills must not rely on static per-agent model pinning in `agent-team` for correctness-critical behavior
- if correctness would fail without strict pinning, route through `sub-agent` with explicit bounded handoffs instead

## Subtask-Splitting And Delegation Rules

### Bounded Split Rules

Generated delegation should satisfy all of the following before splitting:

1. each subtask has one owner-of-record and concrete acceptance criteria
2. in-scope and out-of-scope boundaries are explicit
3. write targets are disjoint or merge order is explicit
4. shared dependencies are identified before execution starts
5. each subtask can be validated without full-repo re-read

If these conditions are not met, keep work in `solo` or reduce split count.

### Duplicate-Context Minimization Rules

To reduce overlap and wasted loading:

1. lead performs shared discovery once and hands off scoped context payloads
2. specialists should not repeat broad repo discovery unless escalation is requested
3. each specialist receives a bounded candidate-file set and dependency hints
4. cross-slice context expansion requires lead approval and trigger evidence
5. integration synthesis belongs to lead or designated integrator, not every specialist

### Delegation Stop Conditions

Do not split further when any of the following is true:

- subtasks would overlap the same hot files without clear ownership sequencing
- coordination cost exceeds expected parallelism benefit
- ambiguity is global rather than slice-local
- validation requires shared reasoning that cannot be isolated safely

When stop conditions apply, prefer `solo` or a smaller `sub-agent` plan.

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

## Escalation Triggers

Escalation should be explicit and incremental across both context and model/tier dimensions.

### Stronger Model Escalation (`economy` -> `balanced` -> `strong`)

Escalate model tier when at least one trigger is true:

- unresolved ambiguity persists after one focused clarification pass
- implementation attempts fail validation for non-trivial reasoning causes
- risk is `high` under the handoff contract or correctness impact is broad
- synthesis requires reconciling conflicting evidence across domains
- reviewer/validator returns blocking findings that indicate reasoning depth gaps

### Heavier Collaboration Escalation (`solo` -> `sub-agent` -> `agent-team`)

Escalate collaboration tier when at least one trigger is true and lower tiers are insufficient:

- independent bounded slices exist and delivery speed/quality benefits from parallel work (`solo` -> `sub-agent`)
- correctness requires active ongoing peer coordination across coupled domains (`sub-agent` -> `agent-team`)
- integration churn shows that bounded hub-and-spoke delegation is no longer stabilizing outcomes

If `sub-agent` remains viable with explicit bounded handoffs, do not escalate to `agent-team`.

## Small Task Vs Large Repo Behavior

### Small Task Behavior

Expected shape:

- start in `solo` with `narrow` budget
- route planning with `economy` and implementation/validation with `balanced`
- discover at repo root and target package only
- deeply read task-local files and nearest tests
- implement and verify before expanding scope

Example:

- issue asks to clarify one contract section in `docs/orchestration-role-handoff-contract.md`
- discovery finds no code coupling requirements
- read target doc and directly linked contracts only
- no delegation needed; produce focused edit and coherence check

### Large Repo / Multi-Package Behavior

Expected shape:

- start with `medium` budget and explicit discovery boundaries
- map packages/apps before selecting candidate files
- route independent slices to `sub-agent` specialists when bounded decomposition is clear
- keep each specialist on a narrow file subset; lead integrates and resolves cross-slice risk
- escalate lead to `strong` only when ambiguity/risk crosses triggers

Example:

- issue requires API contract change plus CLI integration plus docs updates in a monorepo
- lead maps impacted packages (`apps/api`, `apps/cli`, `docs`)
- specialists own disjoint slices with explicit acceptance criteria
- lead escalates to wider reading only when integration tests reveal cross-package assumptions

## Sub-Agent Routing By Task Type

Use task type, not only task size, to route model tiers.

- planning
  - default: `economy` for clear bounded planning
  - escalate: `balanced` or `strong` when decomposition is high-risk or ambiguous
- implementation
  - default: `balanced`
  - downgrade: `economy` for straightforward refactors with clear acceptance tests
  - escalate: `strong` for tricky algorithms, migrations, or cross-domain coupling
- validation
  - default: `balanced`
  - escalate: `strong` for flaky/conflicting evidence or high-impact release gates
- synthesis/integration
  - default: lead at `balanced`
  - escalate: lead at `strong` when conflicting slice outputs need deep reconciliation
- ambiguity/risk triage
  - default: lead at `balanced`
  - escalate: `strong` when unresolved ambiguity can affect correctness or safety claims

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

### Good Pattern: Cheapest Capable Routing

- use `economy` for routine planning and low-risk setup
- route implementation/validation to `balanced` by default
- escalate selected slices to `strong` only on explicit triggers

Why this is good:

- controls cost without reducing correctness discipline
- keeps escalation evidence reviewable

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

### Anti-Pattern: Correctness-Critical Team Pinning

- workflow correctness assumes static per-agent model assignments in `agent-team`

Why this is bad:

- current implementations may ignore static team model assignments
- creates hidden reliability risk in high-stakes paths
- violates the advisory-only team assignment caveat

## Integration With Existing Contracts

This document is the canonical runtime contract for context budgeting, repo reading, model routing, and subtask splitting.

Related docs should reference it rather than redefining these rules:

- orchestration tiering for collaboration-tier selection triggers
- role/handoff contract for ownership, payload shape, and risk escalation semantics
- builder inventory/questionnaire contracts for runtime signal and decision capture
- fragment assembly for deterministic runtime block composition
- generated-skill layout/review metadata for documenting escalation and assumptions
