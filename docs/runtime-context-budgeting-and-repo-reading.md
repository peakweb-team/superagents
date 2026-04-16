# Runtime Context-Budgeting, Repo-Reading, And Model-Routing Rules

This document defines the proposed contracts for issues:

- [#24 Define context-budgeting and repo-reading rules](https://github.com/peakweb-team/pw-agency-agents/issues/24)
- [#25 Define model-routing and subtask-splitting heuristics](https://github.com/peakweb-team/pw-agency-agents/issues/25)
- [#55 Define reasoning-effort and token-budget heuristics](https://github.com/peakweb-team/pw-agency-agents/issues/55)

It builds on:

- the runtime-efficiency direction in [`ROADMAP.md`](../ROADMAP.md)
- the orchestration tiering rubric in [`docs/orchestration-execution-rubric.md`](./orchestration-execution-rubric.md)
- the role and handoff contract in [`docs/orchestration-role-handoff-contract.md`](./orchestration-role-handoff-contract.md)
- the builder inventory contract in [`docs/builder-inventory-workflow.md`](./builder-inventory-workflow.md)
- the builder questionnaire contract in [`docs/builder-questionnaire-flow.md`](./builder-questionnaire-flow.md)
- the fragment assembly contract in [`docs/fragment-assembly-rules.md`](./fragment-assembly-rules.md)
- the generated-skill layout contract in [`docs/generated-skill-layout.md`](./generated-skill-layout.md)

## Why This Exists

Generated skills need one provider-neutral runtime policy for how much context to load, how to read repositories efficiently, how to split subtasks, how to route model strength, and how to tune reasoning effort when the runtime exposes that control.

Without this contract, large repos risk wasteful full-repo reading, small tasks risk unnecessary orchestration overhead, and model or effort selection becomes inconsistent and costly.

## Goals

- define context-budgeting guidance that works across `solo`, `sub-agent`, and `agent-team`
- define repo-reading heuristics for small tasks and large multi-package repositories
- define file-discovery and selective-reading behavior before deep file ingestion
- define progressive context-expansion rules that are deterministic and reviewable
- define provider-neutral model-routing heuristics for each collaboration tier
- define provider-neutral reasoning-effort heuristics that complement model routing without replacing it
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

Each stage should produce one explicit output before moving to the next:

- `discover`: bounded map of relevant directories/packages and likely entry points
- `select`: candidate-file list with priorities and exclusions
- `deepen`: focused notes from full reads of selected files and immediate dependencies
- `execute`: implementation or doc edits limited to current scope
- `verify`: evidence summary (tests/checks/manual review) plus pass/block status

Generated skills should treat stage outputs as local checkpoints.
If a stage output is missing, execution should not silently skip to later stages.

#### Stage Output Recording

Stage outputs should be recorded in a lightweight structured format so checkpoint validation is explicit.

Recommended stage output shapes:

- `discover`
  - bounded map keyed by directory/package, with likely entry points and short provenance notes
- `select`
  - prioritized candidate-file list with include/exclude rationale
- `deepen`
  - per-file focused notes, dependency links, and read status
- `execute`
  - scoped change payload describing touched files and intended acceptance criteria
- `verify`
  - evidence bundle with checks performed plus pass/block outcome

Recommended storage locations:

- local execution logs
- handoff payloads (required for non-trivial `sub-agent` and `agent-team` transitions)
- builder metadata artifacts when available

Before advancing stages, one validator (lead, owner-of-record, or equivalent runtime check) should confirm the current stage output is complete enough for the next stage.
If stage output is missing or incomplete, halt progression and request clarification or escalate explicitly.

### Smallest Useful Read Wins

Agents should read the minimum material required to make the next correct decision.

When uncertainty remains high after selective reading, widen scope deliberately and record why.

### Cheapest Capable Model Wins

Generated skills should route to the least expensive model tier that can still satisfy correctness and delivery-risk needs for the current step.

Escalate model strength only when explicit triggers fire, and record escalation reasons in review metadata.

### Lowest Sufficient Effort Wins

When a provider exposes an explicit reasoning-effort control, generated skills should start with the lowest effort setting likely to satisfy the task and escalate only when task risk, ambiguity, or prior failure signals justify spending more.

Effort selection should complement model-tier routing and context budgeting rather than override them.

### Provider-Neutral Budgeting

Budgets should be expressed as behavior constraints, not provider-specific token promises.

Examples of acceptable constraints:

- number of files deeply read before first implementation attempt
- number of directories scanned before escalating to broader discovery
- maximum re-read loops before requesting clarification

## Deterministic Progressive-Loading Rules

Generated skills should enforce the following default runtime algorithm:

1. run one discovery pass before any deep file reads
2. derive a bounded candidate-file set from discovery evidence
3. deep-read only candidate files and immediate dependencies
4. execute one scoped implementation pass
5. verify against explicit acceptance criteria
6. escalate context only when escalation triggers are met

Deterministic guardrails:

- do not deep-read files outside the candidate set unless escalation is triggered
- do not add a new package/domain during `execute`; return to `discover` first
- do not run more than two `select` -> `deepen` loops without either escalating or requesting clarification
- do not mark `verify` complete when unresolved ambiguity still affects correctness claims

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

## Candidate-File Discovery Budgets

Candidate-file budgets keep selective reading bounded and reviewable while staying provider-neutral.
In this contract, an execution `slice` means one owner-of-record work portion:

- `solo`: one aggregate slice for the task
- `sub-agent`: one slice per specialist
- `agent-team`: one slice per owner-of-record role

Default discovery budgets:

- `solo` + `narrow`: start with 3-8 candidate files
- `solo` + `medium`: start with 8-15 candidate files
- `sub-agent` lead: 8-20 candidate files across shared context
- `sub-agent` specialist: 3-10 candidate files per specialist slice
- `agent-team` owner-of-record role: 5-15 candidate files per role slice

Escalation rule:

- if evidence remains insufficient after the current budget is exhausted, escalate one budget level and record:
  - trigger condition
  - newly added directories/packages
  - revised candidate-file ceiling

These ranges are guidance ceilings for first-pass selection, not mandatory deep-read targets.
Reading fewer files is preferred when confidence is already sufficient.

## Model-Tier Vocabulary

Generated guidance should use provider-neutral model tiers:

- `economy`: lowest-cost reliable tier for routine and low-risk work
- `balanced`: default tier for most implementation and integration work
- `strong`: highest-reasoning tier for ambiguity, high risk, and cross-domain synthesis

Generated skills may map local/provider model names onto these tiers, but runtime behavior should reason in terms of these tier semantics.

## Reasoning-Effort Tier Vocabulary

Generated guidance should use provider-neutral effort tiers that are independent from provider parameter names:

- `low`
  - minimal deliberate reasoning overhead; best for clear, low-risk, bounded steps
- `medium`
  - default effort for most implementation and verification work
- `high`
  - deeper deliberate reasoning for ambiguous, high-risk, or cross-domain synthesis

Effort-tier rules:

- effort tier is a runtime-budget lever, not a quality guarantee by itself
- higher effort does not replace missing context or weak acceptance criteria
- model tier and effort tier should be selected together, but escalated independently when triggers differ

## Token-Budget Profiles

Generated skills should use provider-neutral token-budget profiles as qualitative operating intent:

- `lean`
  - prioritize lower cost/latency with concise reasoning and tighter retries
- `standard`
  - default profile balancing quality, latency, and cost
- `expanded`
  - allow broader reasoning/verification loops for correctness-critical synthesis

Token-budget profiles should guide behavior (retry depth, synthesis breadth, and escalation tolerance), not promise exact provider token counts.

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

## Reasoning-Effort And Token-Budget Defaults By Task Category

Generated skills should apply the following default heuristics before custom project overrides:

- drafting
  - default: effort `low`, token profile `lean`, model tier `economy` or `balanced`
  - escalate when requirements are contradictory or audience constraints are high-risk
- planning
  - default: effort `low`, token profile `lean`, model tier `economy`
  - escalate to effort `medium` when decomposition has non-trivial dependencies or risk
- implementation
  - default: effort `medium`, token profile `standard`, model tier `balanced`
  - downgrade to effort `low` for straightforward edits with tight tests
  - escalate to effort `high` only when correctness depends on deep algorithmic or cross-domain reasoning
- debugging
  - default: effort `medium`, token profile `standard`, model tier `balanced`
  - escalate to effort `high` when root cause remains unresolved after one focused hypothesis/test pass
- review
  - default: effort `medium`, token profile `standard`, model tier `balanced`
  - escalate to effort `high` for contentious, security-sensitive, or architecture-level findings
- validation
  - default: effort `medium`, token profile `standard`, model tier `balanced`
  - escalate to effort `high` and token profile `expanded` only for release-gating ambiguity or conflicting evidence
- synthesis
  - default: effort `medium`, token profile `standard`, model tier `balanced`
  - escalate to effort `high` with model tier `strong` when reconciling conflicting outputs across slices/domains

Guidance alignment rules:

- escalate model tier first when failure signals indicate capability limits rather than reasoning-depth limits
- escalate effort first when model tier is already appropriate but reasoning depth appears insufficient
- escalate token profile only when evidence quality requires broader reasoning or validation loops

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

Candidate-selection stop rule:

- stop adding files once the current budget range is met unless a defined escalation trigger is already present
- record intentionally skipped siblings so later reviewers can verify boundary decisions

Example escalation-trigger exception:

- validation uncovers cross-package coupling after the budget limit is reached
- continue adding only files needed for the coupled package
- record skipped siblings and the trigger evidence
- formally escalate and re-run `discover` and `select`

### Deep-Reading Phase

Perform full-content reads only for files in the current candidate set and immediate dependencies.

Escalate to broader reading only when one of the following occurs:

- repeated ambiguity after two focused passes
- evidence of cross-package coupling that can affect correctness
- risk signals indicate high blast radius

When escalating, record what triggered broader reading and which new areas were added.

Re-read limits:

- do not deep-read the same file more than twice per execution cycle (one complete `discover` -> `select` -> `deepen` -> `execute` -> `verify` cycle) unless new evidence changed assumptions
- if repeated re-reads are required, escalate and document what new dependency or ambiguity was introduced

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

### Wider Context Escalation (`narrow` -> `medium` -> `wide`)

Escalate context budget level only when at least one trigger is true:

- two focused `select` -> `deepen` passes failed to resolve implementation ambiguity
- verification failed due to missing cross-package or cross-domain evidence
- reviewer/validator identified a potential correctness issue outside the current scope boundary
- handoff payloads repeatedly request context outside assigned ownership boundaries

Escalation discipline:

- escalate one level at a time
- re-run `discover` and `select` after each escalation before further deep reads
- if `wide` still fails to resolve correctness-critical ambiguity, request explicit clarification instead of continuing blind

### Higher Effort Escalation (`low` -> `medium` -> `high`)

Escalate effort tier when at least one trigger is true:

- one focused pass at the current effort tier fails due to unresolved reasoning ambiguity
- reviewer/validator feedback indicates logic quality gaps rather than missing context
- risk is `high` and completion claims require stronger argument quality
- cross-slice synthesis repeatedly produces conflicting conclusions

Escalation discipline:

- do not jump directly from `low` to `high` unless risk is already `high`
- do not escalate effort to compensate for missing discovery/select/deepen steps
- record the trigger and failed prior attempt in handoff or review metadata

### Effort And Budget De-Escalation Triggers

De-escalate effort tier and/or token-budget profile when one of the following is true:

- two consecutive slices pass validation without ambiguity at the current elevated setting
- the task phase shifts from ambiguity-heavy synthesis to routine bounded edits
- reviewer/validator confirms risk has dropped from `high` to `medium` or `low`

De-escalation discipline:

- step down one level at a time (`high` -> `medium` -> `low`; `expanded` -> `standard` -> `lean`)
- preserve elevated settings for unresolved high-risk slices while de-escalating routine slices
- record de-escalation rationale so reviewers can confirm budget intent

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

Use task type, not only task size, to route model tiers, effort tiers, and token-budget profiles.

- planning
  - default: model `economy`, effort `low`, token profile `lean`
  - escalate: model `balanced` and effort `medium` when decomposition is high-risk or ambiguous
- implementation
  - default: model `balanced`, effort `medium`, token profile `standard`
  - downgrade: model `economy` and effort `low` for straightforward refactors with clear acceptance tests
  - escalate: model `strong` and effort `high` for tricky algorithms, migrations, or cross-domain coupling
- debugging
  - default: model `balanced`, effort `medium`, token profile `standard`
  - escalate: model `strong` and effort `high` when one focused root-cause pass fails
- review/validation
  - default: model `balanced`, effort `medium`, token profile `standard`
  - escalate: model `strong`, effort `high`, and token profile `expanded` for conflicting evidence or release-gate findings
- synthesis/integration
  - default: lead at model `balanced`, effort `medium`, token profile `standard`
  - escalate: lead at model `strong` and effort `high` when conflicting slice outputs need deep reconciliation
- ambiguity/risk triage
  - default: lead at model `balanced`, effort `medium`, token profile `standard`
  - escalate: model `strong` and effort `high` when unresolved ambiguity can affect correctness or safety claims

## Providers Without Explicit Effort Controls

When a provider/runtime lacks an explicit effort parameter:

- keep provider-neutral effort-tier selection in generated guidance (`low`/`medium`/`high`)
- implement effort intent via adjacent levers:
  - context-stage strictness (`discover`/`select`/`deepen` breadth)
  - model-tier routing (`economy`/`balanced`/`strong`)
  - validation depth (number and strictness of checks before completion claims)
  - bounded retry/clarification loops
- record in metadata that effort intent was applied indirectly due to provider surface limits

Generated skills should not claim "effort unsupported" and skip reasoning-budget discipline entirely.

## Provider Mapping Examples (Non-Normative)

These examples are implementation guidance only.
Core generated contract text should remain provider-neutral.

- Claude example
  - effort tiers: `low` -> `effort: low`, `medium` -> `effort: medium`, `high` -> `effort: high`
  - token profile intent remains independent; profile changes should still be reflected in context breadth and verification depth
- Provider with no effort knob example
  - effort tiers remain in runtime metadata
  - map `low`/`medium`/`high` primarily through model tier and validation-depth controls
- Future-provider example
  - if provider exposes a differently named reasoning parameter, map it to `low`/`medium`/`high` semantics in provider adapter notes
  - do not rename core tiers per provider

## File-Discovery And Selective-Reading Rules

Generated skills should include these explicit runtime rules:

1. Start with path discovery (`rg --files`, workspace manifests, top-level docs) before content-heavy reads.
2. Use targeted search (`rg`) to locate symbols/phrases before opening whole files.
3. Read headings/sections first for long docs; deep-read only relevant sections unless contradiction appears.
4. For code, read call sites and tests nearest to the change before reading transitive dependencies.
5. Stop broad discovery once enough evidence exists to pick a bounded execution slice.
6. Re-open previously read files only when new evidence invalidates earlier assumptions.
7. Keep one candidate-file ledger per execution slice to avoid duplicate broad discovery across specialists.

### Candidate-File Ledger Format

Each execution slice ledger should track:

- `files_in_candidate_set`
  - all files currently selected for the slice
- `files_deeply_read`
  - subset that received full-content reads
- `budget_range`
  - active discovery budget for the slice (for example `3-8`)
- `escalation_count`
  - number of context-budget escalations for the slice

Ledger flow in collaborative tiers:

- lead shares initial ledger state in delegation handoff payloads
- specialists update slice ledgers during execution
- specialists return updated ledgers in completion handoffs
- lead merges ledgers for integration and review reporting

After escalation, update both `budget_range` and `escalation_count` before adding new files.
This ledger complements `context_scope.read` from the handoff contract: `context_scope.read` captures what was read, while the ledger captures selection boundaries, deep-read subset, and escalation history.

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
- select a bounded candidate set for the current budget level
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

### Anti-Pattern: Unbounded Candidate Creep

- candidate-file set keeps growing during execution without explicit escalation

Why this is bad:

- hides scope drift
- defeats selective-reading guarantees
- makes evidence and review metadata hard to trust

### Anti-Pattern: Correctness-Critical Team Pinning

- workflow correctness assumes static per-agent model assignments in `agent-team`

Why this is bad:

- current implementations may ignore static team model assignments
- creates hidden reliability risk in high-stakes paths
- violates the advisory-only team assignment caveat

## Integration With Existing Contracts

This document is the canonical runtime contract for context budgeting, repo reading, model routing, reasoning-effort budgeting, and subtask splitting.

Related docs should reference it rather than redefining these rules:

- orchestration tiering for collaboration-tier selection triggers
- role/handoff contract for ownership, payload shape, and risk escalation semantics
- builder inventory/questionnaire contracts for runtime signal and decision capture
- fragment assembly for deterministic runtime block composition
- generated-skill layout/review metadata for documenting escalation and assumptions
