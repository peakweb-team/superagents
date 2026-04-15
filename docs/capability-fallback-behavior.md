# Capability Fallback Behavior

This document defines the proposed contract for issue `#19`:

- [#19 Define unavailable-capability fallback behavior](https://github.com/peakweb-team/pw-agency-agents/issues/19)

It builds on:

- the external capability model in [`docs/external-capability-model.md`](./external-capability-model.md)
- the project integration declaration format in [`docs/project-integration-declaration-format.md`](./project-integration-declaration-format.md)
- the builder inventory workflow in [`docs/builder-inventory-workflow.md`](./builder-inventory-workflow.md)
- the builder questionnaire flow in [`docs/builder-questionnaire-flow.md`](./builder-questionnaire-flow.md)
- the first-wave task-system fragment set in [`docs/task-system-provider-fragment-set.md`](./task-system-provider-fragment-set.md)
- the generated-skill layout contract in [`docs/generated-skill-layout.md`](./generated-skill-layout.md)

## Why This Exists

The capability model defines what generated skills may rely on.

The integration declaration format defines which provider is expected to satisfy each capability.

That still leaves one important question:

What should Peakweb do when the capability is:

- unavailable
- only partially available
- or only realistically reachable through a human/manual workflow

This document defines that fallback contract for MVP.

## Goals

- define explicit fallback modes
- define when the builder should continue, warn, enter manual mode, or fail
- document how manual-mode expectations should appear in generated output
- keep generated skills honest about what is and is not automated

## Non-Goals

- implementing provider adapters
- auto-configuring missing integrations
- removing human approval from authorization-sensitive workflows
- defining every provider-specific exception in detail

## Core Principle

Generated skills must degrade explicitly, not silently.

If an expected capability is missing or partial, the generated output should make one of four states clear:

- safe to continue automatically
- continue, but warn the operator
- continue only in manual mode
- do not continue as if the capability exists

## Fallback Modes

The MVP fallback contract uses four modes.

### `continue`

Use when:

- the capability is optional for the current workflow
- or the missing automation does not materially change correctness

Behavior:

- proceed normally
- do not block workflow generation
- note the lower-confidence behavior only if it materially affects review

Example:

- `delivery-status.read` is absent in a repo where hosted delivery signals are informative but not required for completion

### `warn`

Use when:

- the workflow can still proceed safely
- but the missing or partial capability materially reduces visibility, convenience, or confidence

Behavior:

- continue generating the workflow
- record the warning in builder output
- make the generated skill call out the limitation where the operator needs to compensate

Example:

- `review-feedback.read` is partial, so the workflow can proceed with human PR review, but bot-review coverage may be incomplete

### `manual`

Use when:

- the workflow can still proceed
- but a meaningful step must be performed or verified by a human outside Peakweb automation

Behavior:

- continue generating the workflow
- mark the capability as manual-mode dependent
- include explicit manual expectations and handoff language

Example:

- `task-tracker.update` is only reachable through a human-managed Jira workflow outside the current toolchain

### `fail`

Use when:

- the workflow depends on the capability for correctness or truthfulness
- and no safe automatic or manual fallback has been established

Behavior:

- do not generate misleading instructions that assume the capability exists
- leave the relevant decision unresolved
- surface the blocking condition in builder output

Example:

- a tracked-task-only workflow without any usable `task-tracker.read`

## Decision Factors

Fallback mode should be chosen using three inputs together.

### 1. Capability Support Level

From `integrations.yaml`:

- `full`
- `partial`
- `unavailable`

### 2. Workflow Dependency Level

The builder should treat each capability as one of:

- `required`
- `important-but-optional`
- `optional`

This dependency level is determined by the selected intake mode, fragments, and workflow expectations.

### 3. Alternate Path Type

The builder should check whether a safe alternate path exists:

- `automatic`
- `manual`
- `none`

## Recommended Fallback Matrix

### Rule 1: Full Support Normally Continues

If support is `full`, fallback mode should normally be:

- `continue`

Unless:

- the workflow still depends on a human approval boundary that must be called out separately

### Rule 2: Partial Support Usually Warns Or Goes Manual

If support is `partial`:

- use `warn` when the missing surface reduces convenience or confidence but not core correctness
- use `manual` when the missing surface requires a human to complete or verify a workflow step
- use `fail` only when the unsupported portion makes the workflow misleading or unsafe

### Rule 3: Unavailable Support Requires Alternate Path Evaluation

If support is `unavailable`:

- use `continue` only when the capability is genuinely optional
- use `warn` when a safe automatic alternate path exists
- use `manual` when a safe human path exists and should be made explicit
- use `fail` when no safe path exists

## Warning vs Fail vs Continue Guidance

### Continue

Choose `continue` when:

- the workflow still means the same thing
- the capability is supplemental rather than foundational
- omission does not create a false claim about what Peakweb can do

### Warn

Choose `warn` when:

- the operator should know the workflow is degraded
- but the next safe step is still obvious
- the system can still produce honest instructions

Warnings should be visible in:

- `integrations.yaml`
- `decisions.yaml`
- `review.md`

### Manual

Choose `manual` when:

- a human must take a real action
- or a human must verify the outcome of an action that Peakweb cannot perform directly

Manual mode is not failure.

It is an explicit handoff state.

### Fail

Choose `fail` when:

- the generated workflow would otherwise claim unsupported behavior
- the workflow would lose its system of record or review-of-record truth
- or the operator would not know how to proceed safely

## Manual-Mode Expectations

Manual mode must be concrete enough that a human reviewer or operator knows what Peakweb did not do.

When a capability falls into manual mode, the generated output should include:

### 1. Clear Manual Boundary

State plainly that the capability is not automated in the current project configuration.

Example:

- `task-tracker.update` is manual for this project; post the final status update in Jira yourself.

### 2. Required Human Action

Describe the specific manual step.

Examples:

- post the ticket update
- request the reviewer manually
- verify hosted checks in the code host UI

### 3. Completion Semantics

State whether Peakweb may still proceed with the rest of the workflow before that manual step is complete.

Examples:

- continue implementation, but do not mark the task complete until the human update is posted
- continue PR preparation, but do not claim review has been requested automatically

### 4. Review Visibility

Manual-mode steps should appear in:

- `integrations.yaml`
- `review.md`
- generated skill instructions if the step is likely to recur in normal use

## Recommended Binding Fields In `integrations.yaml`

To support fallback reviewability, capability bindings may include:

### `fallback_mode`

- Type: enum string
- Allowed values:
  - `continue`
  - `warn`
  - `manual`
  - `fail`
- Purpose: record the selected fallback behavior for that capability in the current project

### `manual_steps`

- Type: array of strings
- Purpose: list concrete human actions required when `fallback_mode: manual`

### `warning`

- Type: string
- Purpose: short operator-facing warning when `fallback_mode: warn`

These fields extend the declaration format without changing its basic provider-binding structure.

## Family-Specific MVP Guidance

### Task Intake

- Missing `task-intake.direct-brief` in a tracked-task-only workflow may still be `continue`
- Missing `task-tracker.read` in a tracked-task-only workflow should usually be `fail`
- Missing tracked-task support in a dual-intake workflow may be `manual` or `warn` if direct-brief remains safe

### Task Tracker

- Missing `task-tracker.lookup` or `task-tracker.read` in a tracked-task-first workflow should usually be `fail`
- Missing `task-tracker.update` often becomes `manual` rather than `fail` if the rest of the tracked-task workflow is still usable

### Code Host / PR

- Missing `code-host.pr.open` in a PR-based workflow is usually `manual` if a human can open the PR safely
- Missing `code-host.pr.update` is often `warn` or `manual`
- Missing `code-host.pr.review-request` is often `manual`

### Review Feedback

- Partial `review-feedback.read` usually becomes `warn`
- Missing `review-feedback.respond` is often `manual`
- Completely missing review feedback in a review-driven workflow may become `fail` if no human-visible review queue remains

### Delivery And Validation

- Missing `delivery-status.read` is often `warn` unless hosted gates are mandatory
- Missing `validation-signal.read` is often `manual` when humans can still inspect CI or local validation output directly

## Builder Output Expectations

When fallback behavior matters, the builder should record it in multiple places.

### `integrations.yaml`

Record:

- support level
- fallback mode
- manual steps or warnings when applicable

### `decisions.yaml`

Record:

- why the fallback mode was chosen
- whether it was confirmed, assumed, or unresolved

### `review.md`

Highlight:

- degraded integrations
- manual steps required before completion
- any capabilities that block full workflow automation

## Example

```yaml
capability_bindings:
  task-tracker.update:
    provider_ref: jira
    support: unavailable
    decision_state: confirmed
    fallback_mode: manual
    manual_steps:
      - Post the final delivery update in Jira manually before marking the work complete.

  review-feedback.read:
    provider_ref: github
    support: partial
    decision_state: assumed
    fallback_mode: warn
    warning: Bot-review coverage is partial; confirm unresolved human PR feedback before closing the loop.

  task-tracker.read:
    provider_ref: jira
    support: unavailable
    decision_state: unresolved
    fallback_mode: fail
```

## MVP Boundary

This contract defines:

- fallback modes
- warning vs manual vs fail vs continue behavior
- manual-mode expectations
- how fallback state should surface in builder metadata

It does not define:

- provider-specific implementation details
- a full automation policy for every future workflow
- human authorization policy outside the capability scope itself
