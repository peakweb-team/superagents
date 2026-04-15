# Provider Matrix For Delivery Platforms And Review Systems

This document defines the proposed contract for issue `#17`:

- [#17 Draft provider matrix for major delivery platforms and review tools](https://github.com/peakweb-team/pw-agency-agents/issues/17)

It builds on:

- the canonical capability model in [`docs/external-capability-model.md`](./external-capability-model.md)
- the orchestration execution rubric in [`docs/orchestration-execution-rubric.md`](./orchestration-execution-rubric.md)
- fallback behavior in [`docs/capability-fallback-behavior.md`](./capability-fallback-behavior.md)
- the project integration declaration contract in [`docs/project-integration-declaration-format.md`](./project-integration-declaration-format.md)
- the first-wave task-system fragment contract in [`docs/task-system-provider-fragment-set.md`](./task-system-provider-fragment-set.md)
- the first-wave code-host/review fragment contract in [`docs/code-host-review-provider-fragment-set.md`](./code-host-review-provider-fragment-set.md)
- the delivery-platform coverage goals in [`ROADMAP.md`](../ROADMAP.md)

## Why This Exists

Issue `#13` defines the capability vocabulary.

Issue `#17` adds an initial provider coverage view so Phase 2 can prioritize where to implement first instead of assuming every provider should land at once.

This matrix is intentionally capability-oriented:

- rows are providers or review patterns
- columns are canonical capability ids from `docs/external-capability-model.md`
- support is marked as `full`, `partial`, or `unavailable`

Execution-tier choices (`solo`, `sub-agent`, `agent-team`) are intentionally out of scope for this matrix and are defined in [`docs/orchestration-execution-rubric.md`](./orchestration-execution-rubric.md).

## Canonical Capability Subset Used In This Matrix

Task intake is always available through local paths (`task-intake.direct-brief`, `task-intake.assumption-capture`) and is therefore omitted from provider rows below.

The provider matrix focuses on external-provider capabilities:

- tracked task: `task-tracker.lookup`, `task-tracker.read`, `task-tracker.update`
- code host + PR: `code-host.pr.open`, `code-host.pr.update`, `code-host.pr.review-request`, `code-host.pr.status-read`
- review feedback: `review-feedback.read`, `review-feedback.respond`
- downstream signals: `delivery-status.read`, `validation-signal.read`

## Task System Matrix

| Task system | task-tracker.lookup | task-tracker.read | task-tracker.update | Notes on asymmetry |
| --- | --- | --- | --- | --- |
| GitHub Issues | full | full | full | Strong parity when GitHub is also the code host; lighter structured workflow fields than enterprise ticketing systems. |
| Jira | full | full | full | Rich workflows and custom fields; project-specific workflows and permissions increase mapping complexity. |
| Linear | full | full | full | Fast and consistent core ticket API; enterprise workflow depth is usually narrower than Jira/Azure. |
| Azure Boards | partial | full | full | Read/update are strong, but lookup normalization (URLs, keys, numeric ids) is often less uniform across org conventions. |
| GitLab Issues | full | full | full | Best parity when GitLab Issues and GitLab MRs are paired in the same host. |

## Code Host / PR Matrix

| Code host | code-host.pr.open | code-host.pr.update | code-host.pr.review-request | code-host.pr.status-read | review-feedback.read | review-feedback.respond | Notes on asymmetry |
| --- | --- | --- | --- | --- | --- | --- | --- |
| GitHub | full | full | full | full | full | full | Strongest default surface and ecosystem breadth for PR + automation workflows. |
| GitLab | full | full | partial | full | full | full | MR flows are strong; reviewer assignment and enterprise policy surfaces vary more by edition/self-hosting model. |
| Bitbucket | full | partial | partial | partial | partial | partial | Core PR flows exist, but metadata/review/status surfaces are less uniform across Bitbucket Cloud/Server patterns. |

## Review-System Matrix

`delivery-status.read` and `validation-signal.read` are often sourced from code-host checks + CI/deploy systems, so this matrix calls out contribution level rather than pretending a review tool is the single source of truth.

Contribution scoring:

- `full`: capability coverage is reliable and directly actionable in normal workflows.
- `partial`: useful signals exist, but external systems or manual reconciliation are commonly still required.
- `unavailable`: no meaningful or dependable capability signal is expected from that review system alone.

| Review system | review-feedback.read | review-feedback.respond | code-host.pr.status-read contribution | delivery-status.read contribution | validation-signal.read contribution | Notes on asymmetry |
| --- | --- | --- | --- | --- | --- | --- |
| Native review (host-only) | full | full | full | partial | partial | Most reliable baseline; delivery/validation depth depends on connected CI/deploy tooling. |
| CodeRabbit | partial | partial | partial | unavailable | partial | Adds high-value automated findings, but depends on host integration and should be layered, not treated as sole review source. |
| Layered automation (native + bots + checks) | full | full | full | full | full | Highest coverage, but highest operational complexity and policy drift risk. |

## First-Wave Recommendation Criteria

The first provider wave should maximize delivery value while minimizing adapter complexity.

Use these criteria together:

1. End-to-end workflow coverage per provider (task + PR + review loop).
2. Probability of strong fit for Claude-first MVP users.
3. Capability-surface consistency (fewer per-tenant/per-edition edge cases).
4. Lower risk of misleading fallback behavior in Phase 2.
5. Ability to validate quickly in real repositories without bespoke setup.

## Recommended First Provider Set

### In For First Wave

1. GitHub as combined task + code host + native review provider.
2. Jira as additional task-system provider for mixed Jira/GitHub organizations.
3. CodeRabbit as optional layered review provider on top of native host review.
4. Local direct-brief intake remains always-on baseline (`task-intake.*`), independent of external systems.

First-wave provider-fragment guidance is split into:

- task-system fragments in [`docs/task-system-provider-fragment-set.md`](./task-system-provider-fragment-set.md)
- code-host and review fragments in [`docs/code-host-review-provider-fragment-set.md`](./code-host-review-provider-fragment-set.md)

### Out Of First Wave (Defer)

1. Linear.
2. Azure Boards.
3. GitLab Issues + GitLab MRs.
4. Bitbucket PR workflows.
5. Generalized layered-automation bundles that require multi-provider policy orchestration from day one.

## Rationale And Tradeoffs

### Why First-Wave In

- GitHub gives the broadest single-provider coverage across `task-tracker.*`, `code-host.pr.*`, and `review-feedback.*`.
- Jira adds high-demand enterprise tracker coverage without forcing full non-GitHub code-host parity in v1.
- CodeRabbit captures the most common "native + automated reviewer" pattern while still allowing native-review fallback.

### Why First-Wave Out

- Linear, Azure Boards, GitLab, and Bitbucket each add meaningful value, but each also expands provider-specific ambiguity in lookup semantics, review routing, or status/readback behavior.
- Deferring these keeps early fallback behavior honest and reduces risk of pretending parity where behavior is only partially mapped.

### Explicit Tradeoff

The proposed first wave intentionally optimizes for depth and honesty over breadth:

- deeper, more reliable behavior for fewer providers now
- faster expansion later with clearer capability and fallback contracts

## Capability Asymmetries To Preserve In Declarations

When writing `.agency/skills/peakweb/integrations.yaml`, preserve these as explicit support/fallback metadata instead of flattening them:

1. Tracker lookup semantics vary more than tracker read/update semantics.
2. Review-request routing is less uniform than PR open/update.
3. Bot-review systems are usually additive to native review, not substitutes.
4. Delivery and validation signals are often cross-provider (code host + CI + deploy), so mappings should avoid single-provider overclaims.

That keeps generated skills aligned with the external capability and fallback contracts instead of encoding optimistic assumptions.
