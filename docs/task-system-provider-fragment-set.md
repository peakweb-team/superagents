# First Task-System Provider Fragment Set

This document defines the proposed contract for issue `#20`:

- [#20 Add first task-system provider fragment set](https://github.com/peakweb-team/pw-agency-agents/issues/20)

It builds on:

- the canonical capabilities in [`docs/external-capability-model.md`](./external-capability-model.md)
- fallback behavior in [`docs/capability-fallback-behavior.md`](./capability-fallback-behavior.md)
- integration declaration mapping in [`docs/project-integration-declaration-format.md`](./project-integration-declaration-format.md)
- fragment metadata and composition contracts in [`docs/fragment-schema.md`](./fragment-schema.md) and [`docs/fragment-assembly-rules.md`](./fragment-assembly-rules.md)
- first-wave provider prioritization in [`docs/provider-matrix.md`](./provider-matrix.md)

## Why This Exists

Issue `#17` selected the first provider wave.

Issue `#20` turns that selection into explicit provider-fragment guidance for task systems.

This keeps task-system behavior capability-oriented and avoids mixing provider details into generic orchestration fragments.

## Scope Boundary

This document defines task-system provider fragments for:

- GitHub Issues
- Jira

It does not redefine code-host or review-system fragments.

Those remain covered by existing provider-matrix and capability docs.

## Core Rules

### Canonical Capability Mapping Is Required

Task-system provider fragments in this first set map only to canonical tracked-task capabilities:

- `task-tracker.lookup`
- `task-tracker.read`
- `task-tracker.update`

Provider-specific wording may differ, but fragment metadata and generated-skill output should always map behavior back to those capability ids.

### Human-Facing Task Updates Are External; Internal Coordination Is Local

Task-system fragments are for durable human-facing updates in the external system of record.

They are not the channel for internal agent or sub-agent coordination.

External task updates should include milestone-level progress, handoff outcomes, and completion summaries that matter to humans.

Internal planning details, agent handoffs, subtask chatter, and execution coordination should stay in the local runtime and generated workflow instructions.

### Task-System Fragments Are Optional Companions To Direct-Brief Intake

Task-system fragments are additive.

Generated skills must still support direct-brief-first or dual-intake paths when project decisions select them.

No repository should be forced to use an external task tracker as a precondition for useful generated skills.

## First-Wave Task-System Provider Fragments

| Fragment id | Provider | Fragment type | Layer | Canonical capabilities | Primary role |
| --- | --- | --- | --- | --- | --- |
| `project-management/github-issues` | GitHub Issues | `provider` | `project-management` | `task-tracker.lookup`, `task-tracker.read`, `task-tracker.update` | Resolve issue references, read issue context, and post durable status updates in GitHub Issues. |
| `project-management/jira` | Jira | `provider` | `project-management` | `task-tracker.lookup`, `task-tracker.read`, `task-tracker.update` | Resolve Jira keys/URLs, read Jira ticket context, and post durable status updates in Jira. |

Both fragments should use `composition.exclusive_within: primary-task-tracker` so assembly chooses at most one tracker-of-record path.

Both fragments may suggest direct-brief and assumption-capture fragments for dual-intake compatibility, but they should not require tracker-only intake.

## Provider Responsibilities By Capability

### GitHub Issues Fragment Responsibilities

- `task-tracker.lookup`
  - Accept issue number, issue URL, or repo-qualified references.
  - Normalize references into one canonical issue identity before downstream reads/updates.
- `task-tracker.read`
  - Read title, description/body, acceptance context (when present), status/labels, and delivery-relevant links.
- `task-tracker.update`
  - Post durable human-facing progress updates and completion summaries.
  - Keep updates milestone-oriented rather than mirroring every internal subtask.

### Jira Fragment Responsibilities

- `task-tracker.lookup`
  - Accept Jira key and URL references; normalize project-scoped key handling explicitly.
- `task-tracker.read`
  - Read summary, description, acceptance context, status/workflow state, and delivery-relevant links.
- `task-tracker.update`
  - Post durable human-facing progress updates and completion summaries.
  - Respect that transitions/permissions vary per project; do not assume uniform transition rights.

## Fallback Expectations For This Fragment Set

Fallback outcomes must follow [`docs/capability-fallback-behavior.md`](./capability-fallback-behavior.md).

Recommended behavior for first-wave task-system fragments:

| Capability | Support situation | Recommended fallback mode | Builder / generated-skill expectation |
| --- | --- | --- | --- |
| `task-tracker.lookup` | `partial` provider support or ambiguous reference format | `warn` | Continue with explicit reference constraints and ask for precise key/URL when needed. |
| `task-tracker.lookup` | `unavailable` for tracker-selected path | `fail` | Do not claim tracked-task workflow support when canonical lookup cannot be established. |
| `task-tracker.read` | `partial` but core ticket fields readable | `warn` | Continue with explicit note about missing structure and rely on assumption capture for gaps. |
| `task-tracker.read` | `unavailable` for tracker-selected path | `fail` | Block tracker-first path; switch to direct-brief mode only if project intake decision permits it. |
| `task-tracker.update` | readable but update path requires human/manual action | `manual` | Continue implementation flow, but require explicit human task update before marking workflow complete. |
| `task-tracker.update` | fully unavailable and no safe manual process agreed | `fail` | Do not present durable tracker synchronization as completed. |

## Integration Declaration Expectations

When a project uses this fragment set, `.agency/skills/peakweb/integrations.yaml` should:

- keep local direct-brief intake provider entries present when direct-brief mode is allowed
- map task-tracker capabilities to exactly one primary tracker provider (`github` or `jira`)
- mark any degraded capability support with explicit `support`, `decision_state`, and `fallback_mode`

Example (dual-intake with Jira tracker of record):

```yaml
providers:
  local-direct-brief:
    provider: local
    kind: local
    decision_state: confirmed

  jira:
    provider: jira
    kind: external
    decision_state: confirmed

capability_bindings:
  task-intake.direct-brief:
    provider_ref: local-direct-brief
    support: full
    decision_state: confirmed

  task-tracker.lookup:
    provider_ref: jira
    support: full
    decision_state: confirmed

  task-tracker.read:
    provider_ref: jira
    support: full
    decision_state: confirmed

  task-tracker.update:
    provider_ref: jira
    support: partial
    decision_state: confirmed
    fallback_mode: manual
    manual_steps:
      - Post milestone progress and completion status in Jira manually.
      - Add PR and validation links to the Jira ticket before closing.
```

## Builder Selection And Questionnaire Alignment

Inventory and questionnaire phases should keep these behaviors consistent with existing contracts:

- infer candidate tracker fragments from repository/task-reference signals
- ask follow-up questions when both GitHub Issues and Jira are plausible primary trackers
- preserve unresolved state instead of forcing a tracker winner when source-of-truth is unclear
- keep direct-brief path available when selected, even if a tracker fragment is also selected

## Non-Goals For This First Set

- full provider parity for Linear, Azure Boards, or GitLab Issues
- replacing provider-matrix asymmetry notes with optimistic generic behavior
- using external task systems as internal multi-agent coordination logs
- requiring external task trackers for greenfield/direct-brief generated skills
