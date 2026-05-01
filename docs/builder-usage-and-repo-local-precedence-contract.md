# Builder Usage And Repo-Local Precedence Contract

This document defines the canonical user-facing contract for issue `#27`:

- [#27 Document builder usage and repo-local skill precedence](https://github.com/peakweb-team/pw-agency-agents/issues/27)

It aligns with:

- the generated-skill layout and precedence rules in [`docs/generated-skill-layout.md`](./generated-skill-layout.md)
- the install/packaging contract for reusable fragments in [`docs/install-packaging-skill-fragments-contract.md`](./install-packaging-skill-fragments-contract.md)
- the release versioning and generated-skill upgrade contract in [`docs/release-versioning-and-upgrade-contract.md`](./release-versioning-and-upgrade-contract.md)
- the Phase 3 packaging/adoption milestone in [`ROADMAP.md`](../ROADMAP.md)

## Why This Exists

After installation, teams need a single, practical answer to three questions:

1. How do we run the builder inside a target repository?
2. Which skill wins when user-level and repo-local skills both exist?
3. How should generated repo-local output be reviewed, versioned, and regenerated?

This contract answers those questions without changing existing install, layout, or release semantics.

## Scope

This contract covers:

- builder usage flow inside a target repository
- precedence between user-level reusable skills and repo-local generated skills
- review/versioning guidance for generated repo-local output
- configurable worktree isolation defaults and per-task override behavior

This contract does not cover:

- automatic integration provisioning
- provider-specific credential setup
- changes to generated output roots or schema

## Preconditions

Before running the builder in a repository:

1. Install Superagents at user level with:
   - `./scripts/install.sh --tool claude-code`
2. Confirm reusable builder source material exists at:
   - `~/.claude/skills/superagents-skill-builder/SKILL.md`
   - `~/.claude/skills/superagents-skill-builder/fragments/**/*.md`
3. Ensure any external tools you expect to use are already configured by your team.

The builder consumes configured capabilities. It does not auto-provision integrations.

## Builder Usage Flow In A Target Repository

Run the builder from the repository root that should receive generated skills.

### Step 1: Start In The Target Repository

- `cd /path/to/target-repo`

Builder output is repository-local, so running in the correct root is required.

### Step 2: Invoke The Installed Builder Skill

In your coding assistant session, invoke the installed `superagents-skill-builder` skill and ask it to generate Superagents project-local skills for the current repository.

The builder should:

- inventory repo signals
- ask focused follow-up questions when confidence is insufficient
- choose applicable fragments
- assemble generated project-local skills and metadata

Worktree isolation should be configured here as part of workflow behavior:

- repository default mode: `off`, `manual`, or `auto`
- whether task-level override is allowed

### Step 3: Confirm Generated Output Roots

After generation, confirm both repo-local roots exist:

- execution-facing generated skills:
  - `.claude/skills/superagents/`
- builder metadata bundle:
  - `.agency/skills/superagents/`

If only one root exists, treat the run as incomplete and regenerate.

### Step 4: Review Before Commit

Review generated artifacts as normal project files, including:

- generated `SKILL.md` and `skill.json` files under `.claude/skills/superagents/`
- metadata files under `.agency/skills/superagents/`
- `.agency/skills/superagents/review.md` for assumptions, unresolved decisions, compatibility notes, and warnings

Specifically verify worktree behavior in:

- `.agency/skills/peakweb/decisions.yaml` for `worktree_strategy_default` and `worktree_allow_task_override`
- generated workflow instructions for precedence and failure behavior

### Step 5: Commit Generated Output Together

Commit both roots in the same change:

- `.claude/skills/superagents/**`
- `.agency/skills/superagents/**`

Committing both preserves what will execute and why it was assembled that way.

### Step 6: Compare Against Reference Scenarios When Needed

When reviewing generated output for a new repository or unusual workflow mix, compare against the reference bundles in [`examples/generated-skills/`](../examples/generated-skills/README.md) for:

- GitHub-heavy dual-intake with layered review
- Jira-heavy mixed delivery with dual intake
- direct-brief-first bootstrap with explicit fallback/manual boundaries

## Precedence Rules (User-Level Vs Repo-Local)

Precedence is repository-scoped and deterministic.

1. Repo-local generated Superagents skills are authoritative for that repository.
2. User-level installed skills are reusable defaults and source material for generation.
3. If names overlap, the repo-local generated skill is the active one in that repository.
4. The `superagents-` namespace prevents accidental override of unrelated third-party skills.

Practical meaning:

- install updates improve reusable source material
- execution in a repo follows the generated files committed in that repo
- user-level installs do not silently overwrite repo-local generated files

## Repo-Local Review And Versioning Guidance

Generated skills are reviewable configuration, not disposable cache.

### Review Expectations Per Builder Run

Every generation or regeneration should include review of:

- the generated skill text (`SKILL.md`) and any behavior shifts
- `fragments.lock.yaml` changes (selected fragments and suppression/conflict outcomes)
- `decisions.yaml` updates (confirmed, assumed, unresolved)
- `review.md` warnings and manual follow-ups

### Versioning Expectations

- Keep generated artifacts in normal repository history.
- Use pull requests for generated output changes.
- Treat hand-edited generated files as valid local changes that require diff review on regeneration.

### Regeneration Triggers

Regenerate when:

- framework release notes mark regeneration as recommended or required
- project workflow/tooling choices materially change
- integration capability mappings change
- generated output is missing required metadata or compatibility context

Regeneration behavior and compatibility classification continue to follow [`docs/release-versioning-and-upgrade-contract.md`](./release-versioning-and-upgrade-contract.md).

### Regeneration Flow

For an interactive review-and-apply flow over an existing repo-local bundle — comparing the installed framework release, the project's `.agency/skills/superagents/manifest.yaml`, and (optionally) the latest superagents `origin/main` — invoke the `superagents-upgrade` skill instead of running the builder directly. The upgrade skill detects drift across contract versions, fragment lock, generated SKILL.md content, and devcontainer scaffold, classifies the result per the upgrade contract, prompts the operator per change with `apply | raise | skip | both`, and hands approved changes back to the skill-builder for regeneration.

## Worktree Strategy Resolution Contract

Worktree isolation is optional and repository-scoped by default.

Supported modes:

1. `off`: no worktree management
2. `manual`: emit operator instructions only
3. `auto`: create or reuse task-scoped worktrees

When task-level override is enabled, resolve in order:

1. task override (if valid)
2. repository default
3. safe fallback `off`

Generated workflow guidance should include deterministic naming/reuse rules and non-destructive failure remediation for `auto` mode.

## Relationship To Existing Contracts

This document is user-facing glue across existing contracts.

- Install and packaging define how reusable source material is delivered.
- Generated-skill layout defines output roots, naming, and metadata shape.
- Release/upgrade defines compatibility posture and regeneration expectations.

This contract does not replace those documents; it consolidates how teams should apply them in day-to-day repository usage.
