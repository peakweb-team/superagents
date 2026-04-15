# Release Versioning And Generated-Skill Upgrade Contract

This document defines the proposed contract for issue `#48`:

- [#48 Define release versioning and generated-skill upgrade contract](https://github.com/peakweb-team/pw-agency-agents/issues/48)

It builds on:

- the generated output contract in [`docs/generated-skill-layout.md`](./generated-skill-layout.md)
- the fragment metadata contract in [`docs/fragment-schema.md`](./fragment-schema.md)
- the fragment assembly contract in [`docs/fragment-assembly-rules.md`](./fragment-assembly-rules.md)
- the project integration declaration format in [`docs/project-integration-declaration-format.md`](./project-integration-declaration-format.md)
- the capability fallback contract in [`docs/capability-fallback-behavior.md`](./capability-fallback-behavior.md)
- the roadmap direction toward repo-local, reviewable generated skills in [`ROADMAP.md`](../ROADMAP.md)

## Why This Exists

Peakweb no longer behaves like a pure "copy files into `~/.claude/agents`" package.

It introduces:

- framework releases
- versioned contracts and schemas
- repo-local generated skills under `.claude/skills/peakweb/`
- repo-local metadata under `.agency/skills/peakweb/`

That means upgrades cannot be treated as blind replacement of installed files.

The system needs an explicit answer to three questions:

1. What version changed?
2. Is the generated repo-local bundle still compatible?
3. Should the user continue, regenerate, or stop for manual review?

## Goals

- tie framework distribution cleanly to GitHub releases
- distinguish framework release version from contract/schema version
- make generated bundle compatibility explicit in repo-local metadata
- define breaking vs non-breaking upgrade behavior
- define a safe regeneration path for existing project-local generated skills
- keep direct installation simple without hiding upgrade risk

## Non-Goals

- implementing an auto-updater in this contract
- auto-merging manual edits back into fragments
- supporting every future package manager or installer format now
- requiring generated skills to self-update at runtime

## Core Principle

Installed Peakweb files and repo-local generated skills are two different upgrade surfaces.

The installed framework may update through GitHub releases.

The repo-local generated bundle must be evaluated against that release instead of being silently assumed current.

## Version Layers

Peakweb should make three layers visible.

### 1. Framework Release Version

This is the version published through GitHub releases for the distributable Peakweb framework.

Recommended format:

- semantic versioning such as `v1.2.0`

This version answers:

- what installed framework release the user is running
- what release notes and migration guidance apply

### 2. Contract And Schema Versions

These are the version numbers attached to specific contracts or file shapes.

Examples:

- fragment metadata `schema_version`
- generated skill metadata `schema_version`
- integration declaration `schema_version`

These versions answer:

- whether a specific file shape or contract meaning changed
- whether generated metadata can still be interpreted safely

Contract versions must not be collapsed into the framework release number.

Multiple framework releases may share the same contract versions.

### 3. Generated Bundle Version Context

Each generated repo-local bundle should record the framework and contract context it was produced from.

This version context answers:

- which framework release last generated the bundle
- which contract versions the bundle expects
- whether an installed release and a repo-local bundle are compatible

## Release Semantics

Peakweb framework releases should use semantic versioning with upgrade expectations tied to user-visible impact.

### Patch Release

Patch releases should be used for:

- docs fixes
- bug fixes
- clarification that does not change contract meaning
- implementation fixes that do not require generated bundle regeneration

Expected behavior:

- installed framework may update in place
- existing generated bundles are normally still compatible
- regeneration is optional unless the patch specifically fixes generated output quality

### Minor Release

Minor releases should be used for additive change such as:

- new optional metadata fields
- new fragments or providers
- expanded non-breaking contract guidance
- new builder behavior that older generated bundles can still coexist with

Expected behavior:

- existing generated bundles may remain usable
- the release notes should say whether regeneration is recommended
- additive metadata should not force a stop-the-world migration

### Major Release

Major releases should be used when Peakweb changes behavior or metadata in ways that can make existing generated bundles misleading or unsafe.

Examples:

- changing contract meaning rather than only extending it
- requiring new metadata fields for correct interpretation
- changing precedence or upgrade semantics in a breaking way
- making older generated bundle assumptions no longer trustworthy

Expected behavior:

- the release notes must call out the breaking change explicitly
- repo-local generated bundles should be treated as requiring regeneration or migration review
- Peakweb should not pretend an older generated bundle is safely current

## Required Release Notes For GitHub Releases

GitHub release notes should include an upgrade section that is explicit enough for humans and later tooling.

At minimum each release should state:

- framework release version
- release type: `patch`, `minor`, or `major`
- whether repo-local generated bundles are still compatible
- whether regeneration is optional, recommended, or required
- any manual-review expectations for repositories with hand-edited generated skills
- any contract/schema versions introduced or changed

Recommended status wording:

- `compatible-no-regeneration-needed`
- `compatible-regeneration-recommended`
- `breaking-regeneration-required`

## Required Generated Metadata For Upgrade Safety

The generated repo-local bundle should carry enough metadata to compare itself against the installed framework release.

At minimum the generated metadata bundle should record:

- `framework_release`
  - the Peakweb GitHub release that generated the bundle
- `generated_at`
  - when the bundle was generated
- `contract_versions`
  - the relevant schema or contract versions used for generation
- `compatibility`
  - the builder's recorded upgrade posture at generation time

Recommended `compatibility` fields:

- `status`
  - one of:
    - `compatible`
    - `regeneration-recommended`
    - `regeneration-required`
- `reason`
  - short explanation of why that status applies
- `manual_review_required`
  - boolean to make high-risk upgrades obvious

These fields should live in repo-local metadata so the bundle can be reviewed and diffed in normal project history.

## Upgrade Classification Rules

When the installed framework release and the repo-local generated bundle differ, Peakweb should classify the situation into one of three states.

### `compatible`

Use when:

- the installed release can still interpret the repo-local bundle safely
- no contract meaning changed in a breaking way

Expected behavior:

- continue using the existing repo-local bundle
- regeneration may still be offered, but it is not required

### `regeneration-recommended`

Use when:

- the newer release adds useful behavior or metadata
- the old bundle is still truthful, but no longer ideal

Expected behavior:

- warn the user that the repo-local bundle is behind
- offer regeneration with normal diff review
- do not present the repository as broken

### `regeneration-required`

Use when:

- the older generated bundle may now be misleading
- the installed framework expects contract meaning or metadata the bundle does not carry
- a major release or explicitly breaking change invalidates silent continuation

Expected behavior:

- tell the user that the repo-local bundle must be regenerated or migrated
- require explicit review of generated output changes
- call out manual review when generated files were previously hand-edited

## Manual Edit Expectations During Upgrade

Manual edits to generated `SKILL.md` files remain allowed.

However, upgrades must treat them as review-sensitive drift, not as safe text to overwrite silently.

When regeneration is recommended or required:

- existing repo-local generated skills should be diffed like normal project files
- release notes and repo-local review output should warn that manual edits may be overwritten
- the preferred long-term path is to move durable changes back into fragments, builder inputs, or confirmed decisions

This keeps human reviewability intact without promising automatic merge of local customizations.

## Recommended Upgrade Flow

The MVP upgrade flow should be explicit and reviewable.

### 1. Install Or Select New Framework Release

The user updates Peakweb through the GitHub-release-based distribution path.

### 2. Compare Installed Release To Repo-Local Metadata

Peakweb checks the repo-local generated bundle metadata under `.agency/skills/peakweb/`.

It should compare:

- installed `framework_release`
- generated bundle `framework_release`
- relevant `contract_versions`

### 3. Surface Upgrade State Clearly

Peakweb should tell the user whether the repository is:

- compatible
- regeneration recommended
- regeneration required

### 4. Regenerate Repo-Local Skills When Needed

If regeneration is chosen or required, rerun the builder and rewrite:

- `.claude/skills/peakweb/`
- `.agency/skills/peakweb/`

### 5. Review The Resulting Diff

Review should focus on:

- changed generated instructions
- changed compatibility metadata
- changed fragment set or provider bindings
- warnings about overwritten manual edits

### 6. Confirm Breaking-Change Follow-Through

If the release is breaking, the review output should explicitly call out:

- why regeneration was required
- what changed materially
- whether any manual follow-up remains

## Relationship To Existing Generated Output

This contract extends the generated-skill layout contract rather than replacing it.

It means:

- generated `skill.json` metadata should reference the generating framework release
- `.agency/skills/peakweb/manifest.yaml` should summarize bundle release and compatibility state
- `review.md` should call out upgrade-sensitive changes during regeneration

It does not require a full installer or migration engine in MVP.

## MVP Boundary

This contract requires:

- GitHub-release-compatible framework versioning
- explicit separation of framework release version from contract/schema versions
- generated metadata that makes compatibility reviewable
- clear distinction between compatible, recommended-regeneration, and required-regeneration upgrades
- explicit warning for breaking changes and manual-edit review risk

It does not require:

- automatic one-click migration
- background update checks
- automatic reconciliation of hand-edited generated files
