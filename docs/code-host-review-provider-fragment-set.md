# First Code-Host And Review Provider Fragment Set

This document defines the proposed contract for issue `#21`:

- [#21 Add first code-host and review provider fragment set](https://github.com/peakweb-team/pw-agency-agents/issues/21)

It builds on:

- the canonical capabilities in [`docs/external-capability-model.md`](./external-capability-model.md)
- fallback behavior in [`docs/capability-fallback-behavior.md`](./capability-fallback-behavior.md)
- integration declaration mapping in [`docs/project-integration-declaration-format.md`](./project-integration-declaration-format.md)
- fragment metadata and composition contracts in [`docs/fragment-schema.md`](./fragment-schema.md) and [`docs/fragment-assembly-rules.md`](./fragment-assembly-rules.md)
- first-wave provider prioritization in [`docs/provider-matrix.md`](./provider-matrix.md)
- first-wave task-system provider fragments in [`docs/task-system-provider-fragment-set.md`](./task-system-provider-fragment-set.md)

## Why This Exists

Issue `#17` selected the first provider wave.

Issue `#20` defined first-wave task-system fragments.

Issue `#21` defines the matching first-wave code-host and review fragment set so PR creation, review routing, and review-loop behavior are explicit and capability-oriented.

## Scope Boundary

This document defines code-host and review provider fragments for:

- GitHub Pull Requests with native host review as the review system of record
- CodeRabbit as optional layered review automation on top of native review

It does not redefine task-intake mode selection or task-system source-of-truth behavior.

Those stay governed by [`docs/task-system-provider-fragment-set.md`](./task-system-provider-fragment-set.md), [`docs/external-capability-model.md`](./external-capability-model.md), and [`docs/provider-matrix.md`](./provider-matrix.md).

## Core Rules

### Canonical Capability Mapping Is Required

Code-host and review provider fragments in this first set map behavior to canonical capabilities:

- `code-host.pr.open`
- `code-host.pr.update`
- `code-host.pr.review-request`
- `code-host.pr.status-read`
- `review-feedback.read`
- `review-feedback.respond`

They may also declare bounded contribution to:

- `delivery-status.read`
- `validation-signal.read`

Provider-specific wording may differ, but fragment metadata and generated-skill output should always map behavior back to canonical capability ids.

### Human-Facing Review State Is External; Internal Agent Coordination Is Local

Code-host and review fragments are for durable human-facing review and status updates in external systems of record.

They are not the channel for local multi-agent or sub-agent coordination.

External review/system-of-record updates should include reviewer-visible progress, response-to-feedback outcomes, and final review-ready context.

Internal planning, subtask routing, handoffs between local agents, and execution-level chatter should remain in local runtime coordination.

Role ownership and local handoff payload expectations for that coordination are defined in [`docs/orchestration-role-handoff-contract.md`](./orchestration-role-handoff-contract.md).

### Native Review Is Baseline Record; Layered Automation Is Additive

Native code-host review remains the baseline review system of record in this first set.

Layered automation such as CodeRabbit is additive review input.

Do not claim parity where it does not exist:

- CodeRabbit does not replace `code-host.pr.*` ownership.
- CodeRabbit findings may enrich review queues and validation signals.
- Final review-of-record state still comes from native host review and host status surfaces.

### Code-Host And Review Fragments Are Optional Companions To Intake Mode

Code-host/review fragments are additive to selected intake and tracker fragments.

Generated skills must still support direct-brief-first and dual-intake paths when those are selected.

No repository should be forced into tracker-first intake as a prerequisite for PR/review guidance.

## First-Wave Code-Host And Review Provider Fragments

| Fragment id | Provider | Fragment type | Layer | Canonical capabilities | Primary role |
| --- | --- | --- | --- | --- | --- |
| `delivery/github-pull-requests` | GitHub | `provider` | `delivery` | `code-host.pr.open`, `code-host.pr.update`, `code-host.pr.review-request`, `code-host.pr.status-read`, `review-feedback.read`, `review-feedback.respond` | Open and maintain PRs in GitHub, route review requests, read host-native review and status, and keep visible review follow-through in the PR system of record. |
| `delivery/coderabbit-layered-review` | CodeRabbit | `provider` | `delivery` | `review-feedback.read`, `review-feedback.respond` (both additive/partial) | Add automated review findings to the review loop while keeping host-native review as authoritative record. |

Recommended composition behavior:

- `delivery/github-pull-requests` should participate in `composition.exclusive_within: primary-code-host-review`.
- `delivery/coderabbit-layered-review` should not replace the primary code-host/review fragment; it should compose as an optional layered companion.

## Provider Responsibilities By Capability

### GitHub Pull Requests Fragment Responsibilities

- `code-host.pr.open`
  - Create PRs with reviewer-ready summary context and links to tracked task or direct brief artifacts when available.
- `code-host.pr.update`
  - Keep PR title/body/metadata aligned with current implementation and verification state.
- `code-host.pr.review-request`
  - Route the PR into the expected reviewer path (maintainers/teams and repo-specific review flow).
- `code-host.pr.status-read`
  - Read review state, check outcomes, and merge-readiness state from host-native surfaces.
- `review-feedback.read`
  - Read unresolved human review comments and relevant automation comments visible in the PR.
- `review-feedback.respond`
  - Post visible follow-up responses in the PR conversation and resolve review threads where host behavior supports it.

### CodeRabbit Layered Review Responsibilities

- `review-feedback.read` (additive)
  - Surface actionable CodeRabbit findings as layered review input.
  - Preserve uncertainty when findings are partial or when coverage is unavailable for parts of a change.
- `review-feedback.respond` (additive)
  - Support visible follow-up acknowledgments where project policy expects bot-feedback handling.
  - Do not present bot-response paths as equivalent to host-native reviewer approvals.

Capability boundaries for layered review:

- `code-host.pr.open`, `code-host.pr.update`, `code-host.pr.review-request`, and `code-host.pr.status-read` remain owned by the primary code host fragment.
- `delivery-status.read` and `validation-signal.read` may receive useful contribution from layered review findings, but should still be sourced from host checks and CI/deploy evidence as primary completion signals.

## Fallback Expectations For This Fragment Set

Fallback outcomes must follow [`docs/capability-fallback-behavior.md`](./capability-fallback-behavior.md).

Recommended behavior for first-wave code-host/review fragments:

| Capability | Support situation | Recommended fallback mode | Builder / generated-skill expectation |
| --- | --- | --- | --- |
| `code-host.pr.open` | unavailable from configured automation path but human can open PR | `manual` | Continue implementation, require explicit human PR creation before claiming review-ready delivery path. |
| `code-host.pr.update` | partial metadata update support | `warn` | Continue with explicit note that some PR metadata updates are manual. |
| `code-host.pr.review-request` | unavailable or policy-routed outside automation | `manual` | Continue with explicit human review-request step before claiming review-loop handoff is complete. |
| `code-host.pr.status-read` | partial status/readback visibility | `warn` | Continue with warning and require explicit host-UI verification for missing status surfaces. |
| `review-feedback.read` | partial layered coverage with native review still available | `warn` | Continue using native review queue as baseline; treat bot findings as additive. |
| `review-feedback.respond` | unavailable for layered automation while native responses remain available | `manual` | Continue with manual response path for layered findings if project policy requires bot-thread follow-up. |
| `delivery-status.read` | no dependable external delivery signal source | `warn` | Do not over-claim delivery certainty; require explicit reviewer/operator verification of delivery gates. |
| `validation-signal.read` | partial validation signal visibility | `warn` | Continue with explicit validation visibility warning and rely on local/CI evidence collection. |

## Integration Declaration Expectations

When a project uses this fragment set, `.agency/skills/peakweb/integrations.yaml` should:

- keep direct-brief intake bindings present when direct-brief mode is selected
- map `code-host.pr.*` capabilities to one primary code-host provider (`github` in first-wave scope)
- map `review-feedback.*` either to native host review or to layered provider entries with explicit additive boundaries
- use `support`, `decision_state`, and `fallback_mode` to avoid parity overclaims for layered automation
- keep `delivery-status.read` / `validation-signal.read` bound to the best available source, with warnings when coverage is degraded

Example (GitHub primary review-of-record with CodeRabbit layered input):

```yaml
providers:
  local-direct-brief:
    provider: local
    kind: local
    decision_state: confirmed

  github:
    provider: github
    kind: external
    decision_state: confirmed

  coderabbit:
    provider: coderabbit
    kind: external
    decision_state: assumed
    notes: Layered review automation is additive to native GitHub review.

capability_bindings:
  task-intake.direct-brief:
    provider_ref: local-direct-brief
    support: full
    decision_state: confirmed

  code-host.pr.open:
    provider_ref: github
    support: full
    decision_state: confirmed

  code-host.pr.update:
    provider_ref: github
    support: full
    decision_state: confirmed

  code-host.pr.review-request:
    provider_ref: github
    support: full
    decision_state: confirmed

  code-host.pr.status-read:
    provider_ref: github
    support: full
    decision_state: confirmed

  review-feedback.read:
    provider_ref: coderabbit
    support: partial
    decision_state: assumed
    fallback_mode: warn
    warning: Use native GitHub review queue as baseline; CodeRabbit coverage is additive.

  review-feedback.respond:
    provider_ref: github
    support: full
    decision_state: confirmed
```

## Builder Selection And Questionnaire Alignment

Inventory, questionnaire, and assembly phases should keep these behaviors consistent with existing contracts:

- infer candidate code-host/review fragments from forge, PR, and review-automation signals
- ask follow-up questions when native-only and layered-review paths are both plausible but policy expectations are unclear
- preserve unresolved state instead of forcing parity assumptions for layered automation
- keep direct-brief and task-system intake decisions independent from code-host/review fragment selection

## Non-Goals For This First Set

- full first-wave parity for GitLab or Bitbucket code-host fragments
- treating CodeRabbit as a standalone system of record for PR state or human approval
- mirroring local sub-agent coordination into external PR comments as default behavior
- requiring task-system fragments as a prerequisite for code-host/review fragment inclusion
