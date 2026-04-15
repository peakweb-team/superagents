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
- the roadmap direction toward a workflow operating system instead of a loose prompt library

## Why This Exists

The builder can only be trustworthy if its output lands in a predictable place, uses stable names, and is reviewable like normal project code.

For the Claude-first MVP, the layout should feel natural for repo-local Claude usage while still preserving Peakweb-specific assembly metadata for humans.

This document defines:

- where generated project-local skills live
- how generated skills are named
- how generated repo-local skills interact with installed user-level skills
- what non-skill artifacts the builder should write for review and versioning

## Design Goals

- keep generated skills project-local and easy to commit
- align the execution-facing path with Claude-style repo-local skill loading
- make repo-local Peakweb output the authoritative layer for that repository
- preserve enough builder metadata for review, debugging, and regeneration
- avoid name collisions with user-authored or third-party skills

## Output Roots

The builder should write generated output under two project-local roots.

### 1. Execution-Facing Skill Root

The primary skill output root is:

- `.claude/skills/peakweb/`

This is the directory that should contain generated skills in the shape the Claude-first MVP is expected to consume directly.

Each generated skill lives in its own folder under that root.

Examples:

- `.claude/skills/peakweb/peakweb-workflow/`
- `.claude/skills/peakweb/peakweb-pr-review/`
- `.claude/skills/peakweb/peakweb-runtime-guardrails/`

### 2. Builder Metadata Root

The builder should also write a repo-local metadata bundle under:

- `.agency/skills/peakweb/`

This metadata root is Peakweb-specific and exists so the generated skills stay reviewable and reproducible without polluting the execution-facing skill folders.

The metadata bundle should be committed alongside the generated skills.

## Naming Conventions

Generated skill names should be deterministic, human-readable, and namespaced.

### Skill Folder Prefix

Every generated skill folder should begin with:

- `peakweb-`

This avoids collisions with:

- installed user-level skills
- hand-authored project-local skills
- future non-Peakweb repo-local skills

### Primary Skill Name

The builder should generate one primary orchestration skill named:

- `peakweb-workflow`

This is the default entry point for project-specific execution behavior.

### Companion Skill Names

Companion skills should use short capability-oriented suffixes rather than provider names when possible.

Examples:

- `peakweb-pr-review`
- `peakweb-task-tracking`
- `peakweb-runtime-guardrails`
- `peakweb-release-handoff`

Provider-specific naming is acceptable only when the behavior is genuinely provider-bound and the generic name would hide an important distinction.

Example:

- `peakweb-jira-task-tracking`

### Slug Rules

Generated skill folder names should:

- use lowercase kebab-case
- start with `peakweb-`
- stay stable across regenerations unless the fragment set materially changes
- avoid repository-name prefixes in the skill folder itself

The repository identity belongs in metadata, not in every skill name.

## Generated Skill Contents

Each generated skill folder under `.claude/skills/peakweb/` should contain:

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
  "name": "peakweb-workflow",
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
  "source_manifest": ".agency/skills/peakweb/manifest.yaml"
}
```

## Required Builder Metadata Output

Besides the skill content itself, the builder should write a metadata bundle under `.agency/skills/peakweb/`.

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

The release/upgrade rules that interpret this metadata now live in [`docs/release-versioning-and-upgrade-contract.md`](./release-versioning-and-upgrade-contract.md).

The rules that produce this lock file now live in [`docs/fragment-assembly-rules.md`](./fragment-assembly-rules.md).

When integrations are degraded, the metadata bundle should make fallback mode, warnings, and manual steps reviewable rather than burying them in prose.

## Precedence Rules

Generated repo-local skills are the authoritative Peakweb layer for the current repository.

### Rule 1: Repo-Local Generated Skills Beat Installed Peakweb Skills

If a generated repo-local Peakweb skill and an installed user-level Peakweb skill both satisfy the same need, the repo-local generated skill wins.

Reason:

- the generated skill reflects repository evidence and confirmed project choices
- the installed skill is only a reusable default

### Rule 2: Exact Local Name Match Shadows User-Level Match

If a repo-local generated skill and a user-level installed skill have the same skill name, the repo-local one should be treated as the active version for that repository.

This is the cleanest override rule and should be the builder's default assumption.

### Rule 3: Generated Skills Should Not Intentionally Shadow Unrelated Third-Party Skills

The `peakweb-` prefix exists so Peakweb-generated output does not accidentally override unrelated local skills such as a hand-written `jira-helper` or `review-checklist`.

Generated skills should override Peakweb defaults through namespace ownership, not through generic names.

### Rule 4: Hand-Edited Repo-Local Generated Skills Remain Authoritative Until Regenerated

If a repository owner edits a generated `SKILL.md` locally, that edited repo-local file remains authoritative for the repository until the builder is run again and overwrites or replaces it.

The builder should therefore surface regeneration and review expectations clearly instead of pretending generated output is immutable.

## Versioning And Review Expectations

Generated skills are not throwaway cache files. They are project configuration and should be treated like other reviewed repository assets.

### Commit Expectations

The following should be committed together:

- generated skill folders under `.claude/skills/peakweb/`
- the builder metadata bundle under `.agency/skills/peakweb/`

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
- any context-budget escalations (for example `narrow` -> `medium` or `wide`) and the trigger for each escalation
- whether execution followed the staged runtime sequence (`discover` -> `select` -> `deepen` -> `execute` -> `verify`) and any stage skips with rationale
- candidate-file budget ranges used per execution slice and reasons for any widened ranges
- any model-tier escalations (for example `economy` -> `balanced` -> `strong`) and why lower tiers were insufficient
- any delegation boundary choices that affected overlap risk, context reuse, or decision to stay in `solo` vs escalate

This review file should make doc-only PR review practical.

### Regeneration Expectations

Regeneration is expected when:

- repository workflow evidence materially changes
- the builder questionnaire answers change
- fragment contract or builder schema versions change
- the team intentionally wants to revise project-local operating behavior

The builder should aim for deterministic output so regenerations produce clean diffs.

When the generating Peakweb release changes, regeneration review should also surface whether the bundle is merely behind, regeneration-recommended, or regeneration-required under the release upgrade contract.

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
    peakweb/
      peakweb-workflow/
        SKILL.md
        skill.json
      peakweb-pr-review/
        SKILL.md
        skill.json
      peakweb-runtime-guardrails/
        SKILL.md
        skill.json

.agency/
  skills/
    peakweb/
      manifest.yaml
      integrations.yaml
      inventory.yaml
      decisions.yaml
      fragments.lock.yaml
      review.md
```

## MVP Boundary

This contract is intentionally narrow for v1.

It does not require:

- a cross-platform generated-skill layout for every AI tool
- a binary cache format
- automatic migration of manual edits back into fragments
- support for unlimited companion skills

It does require:

- deterministic repo-local output
- predictable Peakweb namespacing
- clear repo-local precedence over installed Peakweb defaults
- enough metadata to review and regenerate generated skills safely
