# Fragment Schema And Metadata Contract

This document defines the canonical fragment contract for issue `#11`:

- [#11 Define fragment schema and metadata contract](https://github.com/peakweb-team/pw-agency-agents/issues/11)

It is intentionally shaped by:

- the Claude-first MVP stance from issue `#29`
- the external capability model from issue `#13`
- the workflow-discipline lessons from issue `#31`
- the product direction in [`ROADMAP.md`](../ROADMAP.md)
- the assembly contract in [`docs/fragment-assembly-rules.md`](./fragment-assembly-rules.md)

The goal is not to make fragments abstract for abstraction's sake. The goal is to give Peakweb a small, deterministic contract that can support:

- a Claude-first MVP
- workflow operating system behavior instead of a loose prompt library
- adaptive specialist-team assembly instead of a fixed swarm
- human-readable, repo-local generated skills

## Design Intent

Fragments are reusable units of workflow behavior that the builder can select and compose into project-local skills.

Each fragment should do two things at once:

1. Expose enough metadata for the builder to select it predictably.
2. Preserve readable guidance that humans can review, edit, and version.

This follows the same general discipline that makes Anthropic-style skills and `superpowers`-style workflows useful:

- small composable units
- explicit triggers
- predictable inclusion rules
- strong operational guidance

Peakweb differs in one important way: fragments are not the end product. They are source material for generating a project-specific operating layer.

## Canonical File Shape

Each fragment is a Markdown file with two parts:

1. YAML frontmatter for machine-readable metadata
2. Markdown body for human-readable behavior guidance

The canonical shape is:

```md
---
schema_version: 1
id: orchestration/team-sizing
title: Team Sizing
fragment_type: generic
layer: orchestration
summary: Select the smallest capable team for a task.
capabilities:
  - orchestration.team-sizing
selection:
  evidence_any:
    - repo.multi_area_delivery
  preference: 60
composition:
  suggests:
    - delivery/pull-request-review
  order: 40
---

# Fragment: Team Sizing

## Purpose
...
```

The frontmatter is the contract the builder reads.

The body is the contract a human reviewer reads.

## Required Metadata

Every fragment must define the following fields.

### `schema_version`

- Type: integer
- Required: yes
- Purpose: version the fragment metadata contract
- MVP value: `1`

### `id`

- Type: string
- Required: yes
- Purpose: stable unique identifier
- Format: path-like and repo-relative in spirit, such as `project-management/github-issues`

### `title`

- Type: string
- Required: yes
- Purpose: human-readable label for docs and generated-skill explanations

### `fragment_type`

- Type: enum
- Required: yes
- Allowed values:
  - `generic`
  - `provider`
- Purpose: distinguish workflow-logic fragments from vendor-bound fragments

### `layer`

- Type: enum string
- Required: yes
- Initial values:
  - `task-intake`
  - `project-management`
  - `delivery`
  - `orchestration`
  - `runtime`
- Purpose: place the fragment in the builder's composition model

### `summary`

- Type: string
- Required: yes
- Purpose: one-sentence description of the fragment's job

### `capabilities`

- Type: array of strings
- Required: yes
- Purpose: describe the workflow capability this fragment adds
- Example values:
  - `task-intake.direct-brief`
  - `task-intake.assumption-capture`
  - `task-tracker.lookup`
  - `task-tracker.read`
  - `task-tracker.update`
  - `code-host.pr.open`
  - `code-host.pr.review-request`
  - `review-feedback.read`
  - `validation-signal.read`
  - `delivery.pr-review`
  - `orchestration.team-sizing`
  - `runtime.context-routing`

This is the main place where Peakweb stays capability-oriented instead of hardcoding vendor logic everywhere.

The canonical capability semantics live in [`docs/external-capability-model.md`](./external-capability-model.md).

### `selection`

- Type: object
- Required: yes
- Purpose: define the minimum builder-readable applicability contract

Required `selection` fields:

- `evidence_any`
  - Type: array of strings
  - Meaning: at least one signal should be present for the fragment to be considered a natural fit
- `preference`
  - Type: integer
  - Meaning: relative selection weight for deterministic tie-breaking

The `evidence_any` field may be an empty array for broad baseline fragments, but it must still be present so the shape stays consistent.

### `composition`

- Type: object
- Required: yes
- Purpose: define the minimum builder-readable composition contract

Required `composition` fields:

- `order`
  - Type: integer
  - Meaning: stable sort order when assembling generated output
- `suggests`
  - Type: array of fragment ids
  - Meaning: fragments commonly paired with this one

The `suggests` field may be empty, but it must be present.

## Optional Metadata

These fields are optional in v1, but they are the preferred extension points when a fragment needs tighter applicability or composition rules.

### Top-Level Optional Fields

#### `provider`

- Type: string
- Allowed only for `fragment_type: provider`
- Example values:
  - `github`
  - `jira`
  - `gitlab`

#### `status`

- Type: enum string
- Suggested values:
  - `active`
  - `experimental`
  - `deprecated`
- Default assumption when omitted: `active`

#### `owners`

- Type: array of strings
- Purpose: identify maintainers or stewarding teams for larger fragment libraries

#### `tags`

- Type: array of strings
- Purpose: lightweight discovery metadata for docs or tooling

### Optional `selection` Fields

#### `evidence_all`

- Type: array of strings
- Meaning: every listed signal should be present before the fragment is selected confidently

#### `evidence_none`

- Type: array of strings
- Meaning: if any listed signal is present, the fragment should be excluded

#### `requires_confirmation`

- Type: array of strings
- Meaning: signals that should trigger a questionnaire prompt instead of an automatic decision

#### `confidence`

- Type: enum string
- Suggested values:
  - `low`
  - `medium`
  - `high`
- Meaning: how safe auto-selection is when repository evidence is incomplete

### Optional `composition` Fields

#### `requires`

- Type: array of fragment ids
- Meaning: fragments that should already be present for this fragment to make sense

#### `conflicts`

- Type: array of fragment ids
- Meaning: incompatible fragments that should not be assembled into the same primary operating path

#### `exclusive_within`

- Type: array of strings
- Meaning: exclusivity buckets where the builder should choose one primary fragment
- Example values:
  - `primary-task-tracker`
  - `primary-pr-review-system`

#### `emits`

- Type: array of strings
- Meaning: named behavior blocks the fragment contributes to generated skills
- Example values:
  - `issue-intake`
  - `review-loop`
  - `team-sizing-rules`

This gives the builder a way to reason about overlap without requiring full assembly logic in v1.

The full v1 assembly behavior now lives in [`docs/fragment-assembly-rules.md`](./fragment-assembly-rules.md).

## Generic vs Provider Fragments

This distinction must stay explicit.

### Generic Fragments

Generic fragments define reusable workflow behavior that should survive provider changes.

Examples:

- `orchestration/team-sizing`
- `runtime/context-and-model-routing`
- future planning, validation, or handoff fragments

Generic fragments should:

- express capabilities in neutral workflow language
- describe heuristics, sequencing, and operating rules
- avoid assuming a specific vendor surface unless the body is explicitly calling out an optional example

Generic fragments should not:

- require `provider`
- hardcode GitHub, Jira, or other vendor instructions into the metadata contract

### Provider Fragments

Provider fragments bind workflow behavior to an actual configured system.

Examples:

- `project-management/github-issues`
- `project-management/jira`
- future GitLab review or CodeRabbit delivery fragments

Provider fragments should:

- define `provider`
- declare the capabilities they satisfy for the builder
- explain vendor-specific operating expectations in the body
- use composition metadata to show which generic fragments they pair with or exclude

Provider fragments should not:

- become the place where all orchestration logic lives
- replace generic runtime, validation, or team-sizing behavior that belongs in reusable workflow fragments

## Minimum Deterministic Selection Contract

Issue `#11` does not define the full assembly engine, but it does define the fragment metadata that the assembly engine depends on.

The builder must be able to do the following from metadata alone:

1. Identify candidate fragments by `layer`.
2. Filter candidates with `selection.evidence_any`, `selection.evidence_all`, and `selection.evidence_none`.
3. Recognize when ambiguous evidence should trigger a follow-up question through `selection.requires_confirmation`.
4. Prefer one fragment over another using `selection.preference`.
5. Prevent invalid combinations using `composition.conflicts` and `composition.exclusive_within`.
6. Assemble output in a stable order using `composition.order`, then `id` as the final tie-breaker.

That is enough for MVP selection discipline.

The corresponding selection, suppression, exclusivity, and emitted-block rules are defined in [`docs/fragment-assembly-rules.md`](./fragment-assembly-rules.md).

## Body Structure Expectations

The Markdown body remains flexible, but fragments should usually include:

- `## Purpose`
- `## Include When`
- `## Expected Behaviors` or `## Heuristics`
- `## Builder Notes`

This keeps fragments readable and aligned with the current repo style while letting metadata carry the machine-facing burden.

## Example Definitions

The examples below show the recommended difference between a generic orchestration fragment and a provider-specific task-tracker fragment.

### Example: Generic Fragment

```md
---
schema_version: 1
id: orchestration/team-sizing
title: Team Sizing
fragment_type: generic
layer: orchestration
summary: Select the smallest capable specialist team for the task.
capabilities:
  - orchestration.team-sizing
selection:
  evidence_any:
    - repo.multi_step_delivery
    - repo.cross_functional_changes
  evidence_all: []
  evidence_none: []
  preference: 70
composition:
  requires: []
  suggests:
    - delivery/pull-request-review
    - runtime/context-and-model-routing
  conflicts: []
  exclusive_within: []
  emits:
    - team-sizing-rules
  order: 40
---
```

Why it is generic:

- it expresses specialist-team behavior without naming a vendor
- it supports Peakweb's adaptive-team model directly
- it can pair with GitHub, Jira, or future task-system fragments

### Example: Generic Intake Fragment

```md
---
schema_version: 1
id: task-intake/direct-brief
title: Direct Brief Intake
fragment_type: generic
layer: task-intake
summary: Allow work to begin from a freeform prompt instead of requiring an external ticket.
capabilities:
  - task-intake.direct-brief
selection:
  evidence_any:
    - input.direct_brief
    - workflow.task_tracker_optional
  preference: 70
composition:
  suggests:
    - orchestration/team-sizing
    - runtime/context-and-model-routing
  order: 10
---
```

Why it is generic:

- it models how work enters the system without naming a vendor
- it supports greenfield and vibe-coding flows directly
- it can coexist with or replace tracker-backed intake depending on project needs

### Example: Provider Fragment

```md
---
schema_version: 1
id: project-management/github-issues
title: GitHub Issues
fragment_type: provider
layer: project-management
summary: Use GitHub Issues as the tracked-task system of record for delivery work.
provider: github
capabilities:
  - task-tracker.read
  - task-tracker.update
selection:
  evidence_any:
    - forge.github
    - task_tracker.github_issues
  evidence_all: []
  evidence_none:
    - task_tracker.jira_primary
  requires_confirmation:
    - forge.github_without_issue_usage
  preference: 85
composition:
  requires: []
  suggests:
    - orchestration/team-sizing
    - delivery/pull-request-review
  conflicts:
    - project-management/jira
  exclusive_within:
    - primary-task-tracker
  emits:
    - task-intake
    - task-status-updates
  order: 20
---
```

Why it is provider-specific:

- it binds task-tracker behavior to GitHub specifically
- it satisfies provider-backed capabilities
- it participates in exclusivity with alternative task-tracker providers

## MVP Guidance

To stay aligned with issues `#29` and `#31`, v1 fragments should optimize for a Claude-first workflow without becoming Claude-locked in the wrong layer.

That means:

- generated skills may be Claude-centric in tone and execution assumptions
- fragment metadata should stay capability-oriented where possible
- workflow discipline should be explicit enough to support planning, handoffs, validation, and review loops
- team behavior should stay adaptive, with the smallest capable specialist set as the default

In short: Peakweb should borrow the composability and workflow discipline of the best Claude-forward systems, while keeping its fragment contract clean, reviewable, and portable enough to evolve.
