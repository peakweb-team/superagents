# Generated Skill Layout And Precedence Rules

This document defines the proposed contract for issue `#12`:

- [#12 Define generated skill layout and precedence rules](https://github.com/peakweb-team/pw-agency-agents/issues/12)

It builds on:

- the Claude-first MVP direction from issue `#29`
- the fragment metadata contract in [`docs/fragment-schema.md`](./fragment-schema.md)
- the fragment assembly contract in [`docs/fragment-assembly-rules.md`](./fragment-assembly-rules.md)
- the builder inventory workflow in [`docs/builder-inventory-workflow.md`](./builder-inventory-workflow.md)
- the builder questionnaire flow in [`docs/builder-questionnaire-flow.md`](./builder-questionnaire-flow.md)
- the orchestration tiering rubric in [`docs/orchestration-execution-rubric.md`](./orchestration-execution-rubric.md)
- the role and handoff contract in [`docs/orchestration-role-handoff-contract.md`](./orchestration-role-handoff-contract.md)
- the runtime context-budgeting and repo-reading contract in [`docs/runtime-context-budgeting-and-repo-reading.md`](./runtime-context-budgeting-and-repo-reading.md)
- the project integration declaration format in [`docs/project-integration-declaration-format.md`](./project-integration-declaration-format.md)
- the capability fallback contract in [`docs/capability-fallback-behavior.md`](./capability-fallback-behavior.md)
- the release versioning and upgrade contract in [`docs/release-versioning-and-upgrade-contract.md`](./release-versioning-and-upgrade-contract.md)
- the user-level install and packaging contract for reusable fragments in [`docs/install-packaging-skill-fragments-contract.md`](./install-packaging-skill-fragments-contract.md)
- the user-facing builder usage and precedence contract in [`docs/builder-usage-and-repo-local-precedence-contract.md`](./builder-usage-and-repo-local-precedence-contract.md)
- the batch spec planning and artifact model in [`docs/spec-batch-planning-contract.md`](./spec-batch-planning-contract.md)
- the roadmap direction toward a workflow operating system instead of a loose prompt library

## Why This Exists

The builder can only be trustworthy if its output lands in a predictable place, uses stable names, and is reviewable like normal project code.

For the Claude-first MVP, the layout should feel natural for repo-local Claude usage while still preserving Superagents-specific assembly metadata for humans.

This document defines:

- where generated project-local skills live
- how generated skills are named
- how generated repo-local skills interact with installed user-level skills
- what non-skill artifacts the builder should write for review and versioning

## Design Goals

- keep generated skills project-local and easy to commit
- align the execution-facing path with Claude-style repo-local skill loading
- make repo-local Superagents output the authoritative layer for that repository
- preserve enough builder metadata for review, debugging, and regeneration
- avoid name collisions with user-authored or third-party skills
- prevent runtime-entrypoint mismatches by requiring an explicit runtime target before assembly

## Runtime Target Decision

Before writing any execution-facing files, the builder should resolve and record a `runtime_target` decision in `decisions.yaml`.

- if confidence is high, the builder may confirm the target from repo evidence
- if confidence is below high and output layout would change, the builder should ask a focused follow-up question before writing files
- if runtime target remains unresolved, do not publish execution-facing skill files

For the current Claude-first MVP, the required canonical mapping is (execution-facing output is defined only for `claude-code`):

| runtime_target | Execution root | Primary entrypoint |
|---|---|---|
| `claude-code` | `.claude/skills/superagents/<skill-name>/` | `SKILL.md` |

Invariant for Claude mode:

- do not publish the primary skill as `.claude/skills/superagents/<name>.md`
- each generated skill folder must contain `SKILL.md`
- only `runtime_target = claude-code` may publish execution-facing output; any other `runtime_target` must remain unresolved and must not publish execution-facing files until a canonical output-root and entrypoint contract is defined.

## Output Roots

The builder should write generated output under two project-local roots.

### 1. Execution-Facing Skill Root (Claude Mode)

When `runtime_target` is `claude-code`, the primary skill output root is:

- `.claude/skills/superagents/`

This is the directory that should contain generated skills in the shape the Claude-first MVP is expected to consume directly.

Each generated skill lives in its own folder under that root and must contain `SKILL.md` as the runtime entrypoint.

Examples:

- `.claude/skills/superagents/superagents/`
- `.claude/skills/superagents/superagents-pr-review/`
- `.claude/skills/superagents/superagents-runtime-guardrails/`

### 2. Builder Metadata Root

The builder should also write a repo-local metadata bundle under:

- `.agency/skills/superagents/`

This metadata root is Superagents-specific and exists so the generated skills stay reviewable and reproducible without polluting the execution-facing skill folders.

The metadata bundle should be committed alongside the generated skills.

### Related Spec-Builder Artifacts

Spec-builder artifacts are a separate contract surface from generated skill artifacts.

When pre-implementation spec generation is used:

- single-item canonical specs live under `.agency/specs/<slug>.md` per [`docs/spec-builder-contract.md`](./spec-builder-contract.md)
- batch planning runs may add grouped bundle artifacts under `.agency/specs/batches/...` per [`docs/spec-batch-planning-contract.md`](./spec-batch-planning-contract.md)
- portfolio-to-spec planning runs should expose an operator-facing batch index under the grouped bundle per [`docs/portfolio-to-spec-decomposition-workflow.md`](./portfolio-to-spec-decomposition-workflow.md)

These paths should remain reviewable repository artifacts and should be treated like other committed workflow configuration/output docs when teams opt into spec-first planning.

## Naming Conventions

Generated skill names should be deterministic, human-readable, and namespaced.

### Skill Folder Prefix

Every generated skill folder should begin with:

- `superagents-`

This avoids collisions with:

- installed user-level skills
- hand-authored project-local skills
- future non-Superagents repo-local skills

### Primary Skill Name

The builder should generate one primary orchestration skill named:

- `superagents`

This is the canonical entry point invoked as `/superagents` in every project.

### Companion Skill Names

Companion skills should use short capability-oriented suffixes rather than provider names when possible.

Examples:

- `superagents-pr-review`
- `superagents-task-tracking`
- `superagents-runtime-guardrails`
- `superagents-release-handoff`

Provider-specific naming is acceptable only when the behavior is genuinely provider-bound and the generic name would hide an important distinction.

Example:

- `superagents-jira-task-tracking`

### Slug Rules

Generated skill folder names should:

- use lowercase kebab-case
- start with `superagents-`
- stay stable across regenerations unless the fragment set materially changes
- avoid repository-name prefixes in the skill folder itself

The repository identity belongs in metadata, not in every skill name.

## Generated Skill Contents

Each generated skill folder under `.claude/skills/superagents/` should contain:

- `SKILL.md`
  - the assembled skill instructions intended for direct use
- `skill.json`
  - lightweight machine-readable metadata for the generated skill

The `skill.json` file should include at minimum:

- `name`
- `generated_by`
- `generated_at`
- `framework_release`
- `schema_version`
- `repository`
- `role`
- `selected_fragments`
- `contract_versions`
- `source_manifest`

The goal is not to create a heavy runtime format. The goal is to make each generated skill independently understandable and traceable.

Example `skill.json`:

```json
{
  "name": "superagents",
  "generated_by": "skill-builder",
  "generated_at": "2026-04-15T00:00:00Z",
  "framework_release": "v1.0.0",
  "schema_version": 1,
  "repository": "github.com/peakweb-team/pw-agency-agents",
  "role": "primary orchestration",
  "selected_fragments": [
    "orchestration/team-sizing",
    "project-management/github-issues",
    "delivery/pull-request-review"
  ],
  "contract_versions": {
    "generated_skill_layout": 1,
    "fragment_schema": 1,
    "integration_declaration": 1
  },
  "source_manifest": ".agency/skills/superagents/manifest.yaml"
}
```

## Required Builder Metadata Output

Besides the skill content itself, the builder should write a metadata bundle under `.agency/skills/superagents/`.

The MVP metadata bundle should include:

- `manifest.yaml`
  - top-level summary of the builder run, generated skills, framework release, compatibility status, and schema versions
- `integrations.yaml`
  - repo-local declaration of which configured integration satisfies each external capability
- `inventory.yaml`
  - normalized signals, evidence sources, and confidence levels from the inventory phase
- `decisions.yaml`
  - confirmed, assumed, unresolved, and not-applicable decisions from the questionnaire phase
- `fragments.lock.yaml`
  - exact selected fragments, suppression reasons, exclusivity winners, emitted behavior blocks, and fragment versions or source refs
- `review.md`
  - human-readable summary of why the skills were generated this way and what should be reviewed manually

These files make generated output reviewable, diffable, and regenerable.

### Worktree Strategy Metadata

Worktree isolation strategy should be recorded in `decisions.yaml` as runtime-relevant workflow configuration.

Recommended decision keys:

- `worktree_strategy_default`
  - allowed values: `off`, `manual`, `auto`
  - purpose: repository-level default for task execution isolation
- `worktree_allow_task_override`
  - allowed values: `true`, `false`
  - purpose: whether task-level override is permitted
- `worktree_root_strategy` (optional)
  - examples: `sibling`, `custom-path`
  - purpose: explain expected path-root strategy for deterministic worktree placement
- `runtime_target`
  - examples: `claude-code`, `cursor`, `codex`, `gemini-cli`, `antigravity`, `other`
  - purpose: binds generated execution-facing output paths and entrypoint filename contract
  - unresolved behavior: if `runtime_target` is unresolved/empty, apply `safe_to_proceed: false` (from questionnaire flow) and do not publish execution-facing files

Task-level override resolution should follow the precedence contract in [`docs/orchestration-execution-rubric.md`](./orchestration-execution-rubric.md).

The release/upgrade rules that interpret this metadata now live in [`docs/release-versioning-and-upgrade-contract.md`](./release-versioning-and-upgrade-contract.md).

The rules that produce this lock file now live in [`docs/fragment-assembly-rules.md`](./fragment-assembly-rules.md).

When integrations are degraded, the metadata bundle should make fallback mode, warnings, and manual steps reviewable rather than burying them in prose.

## Precedence Rules

Generated repo-local skills are the authoritative Superagents layer for the current repository.

### Rule 1: Repo-Local Generated Skills Beat Installed Superagents Skills

If a generated repo-local Superagents skill and an installed user-level Superagents skill both satisfy the same need, the repo-local generated skill wins.

Reason:

- the generated skill reflects repository evidence and confirmed project choices
- the installed skill is only a reusable default

### Rule 2: Exact Local Name Match Shadows User-Level Match

If a repo-local generated skill and a user-level installed skill have the same skill name, the repo-local one should be treated as the active version for that repository.

This is the cleanest override rule and should be the builder's default assumption.

### Rule 3: Generated Skills Should Not Intentionally Shadow Unrelated Third-Party Skills

The `superagents-` prefix exists so Superagents-generated output does not accidentally override unrelated local skills such as a hand-written `jira-helper` or `review-checklist`.

Generated skills should override Superagents defaults through namespace ownership, not through generic names.

### Rule 4: Hand-Edited Repo-Local Generated Skills Remain Authoritative Until Regenerated

If a repository owner edits a generated `SKILL.md` locally, that edited repo-local file remains authoritative for the repository until the builder is run again and overwrites or replaces it.

The builder should therefore surface regeneration and review expectations clearly instead of pretending generated output is immutable.

## Versioning And Review Expectations

Generated skills are not throwaway cache files. They are project configuration and should be treated like other reviewed repository assets.

### Commit Expectations

The following should be committed together:

- generated skill folders under `.claude/skills/superagents/`
- the builder metadata bundle under `.agency/skills/superagents/`

Committing both roots preserves the execution artifact and the reasoning behind it.

### Review Expectations

Every builder run should produce a `review.md` file that highlights:

- what changed from the previous generation
- which decisions were assumed instead of confirmed
- any unresolved decisions still affecting the generated skill set
- fragments that were added, removed, or replaced
- fragments that were suppressed by exclusivity or explicit conflicts
- any warnings introduced by degraded or fallback-aware assembly
- the chosen orchestration tier (`solo`, `sub-agent`, or `agent-team`) and why that sizing was selected
- any handoff contract exceptions, blocked handoffs, or unresolved role-ownership questions that require manual follow-up
- the selected runtime operating mode (`small-task` or `large-repo/multi-package`) and the evidence used to choose it
- any context-budget escalations (for example `narrow` -> `medium` or `wide`) and the trigger for each escalation
- whether execution followed the staged runtime sequence (`discover` -> `select` -> `deepen` -> `execute` -> `verify`) and any stage skips with rationale
- candidate-file budget ranges used per execution slice and reasons for any widened ranges
  - for `solo`, report one aggregate slice for the full task (or explicitly note no per-slice breakdown)
  - for `sub-agent` and `agent-team`, report per specialist/role slice
- any model-tier escalations (for example `economy` -> `balanced` -> `strong`) and why lower tiers were insufficient
- any reasoning-effort and token-budget profile changes (for example effort `low` -> `medium` -> `high`, profile `lean` -> `standard` -> `expanded`) and what triggered escalation or de-escalation
- any delegation boundary choices that affected overlap risk, context reuse, or decision to stay in `solo` vs escalate
- the repository default worktree strategy and whether task-level override was enabled
- for each executed task, the resolved worktree mode (`off`, `manual`, or `auto`) and any fallback/remediation applied

This review file should make doc-only PR review practical.

### Regeneration Expectations

Regeneration is expected when:

- repository workflow evidence materially changes
- the builder questionnaire answers change
- fragment contract or builder schema versions change
- the team intentionally wants to revise project-local operating behavior

The builder should aim for deterministic output so regenerations produce clean diffs.

When the generating Superagents release changes, regeneration review should also surface whether the bundle is merely behind, regeneration-recommended, or regeneration-required under the release upgrade contract.

### Manual Edit Expectations

Manual edits to generated `SKILL.md` files are allowed in MVP because human reviewability is a core product goal.

However:

- direct edits should be treated as temporary unless reflected into fragments or builder inputs
- the metadata bundle should record the builder run that last generated the files
- reviewers should expect later regenerations to overwrite untracked manual drift

## Example Generated Layout

```text
.claude/
  skills/
    superagents/
      superagents/
        SKILL.md
        skill.json
      superagents-pr-review/
        SKILL.md
        skill.json
      superagents-runtime-guardrails/
        SKILL.md
        skill.json

.agency/
  skills/
    superagents/
      manifest.yaml
      integrations.yaml
      inventory.yaml
      decisions.yaml
      fragments.lock.yaml
      review.md
```

## Reference Scenarios

For complete, reviewable example bundles that follow this layout contract, see:

- [`examples/generated-skills/github-heavy-dual-intake-coderabbit/`](../examples/generated-skills/github-heavy-dual-intake-coderabbit/)
- [`examples/generated-skills/jira-heavy-mixed-delivery/`](../examples/generated-skills/jira-heavy-mixed-delivery/)
- [`examples/generated-skills/direct-brief-vibe-bootstrap/`](../examples/generated-skills/direct-brief-vibe-bootstrap/)

## MVP Boundary

This contract is intentionally narrow for v1.

It does not require:

- a cross-platform generated-skill layout for every AI tool
- a binary cache format
- automatic migration of manual edits back into fragments
- support for unlimited companion skills

It does require:

- deterministic repo-local output
- predictable Superagents namespacing
- clear repo-local precedence over installed Superagents defaults
- enough metadata to review and regenerate generated skills safely
