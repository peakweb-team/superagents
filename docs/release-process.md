# Superagents Release Process

This document describes how Superagents framework releases are cut. It is the operational companion to the authoritative [`docs/release-versioning-and-upgrade-contract.md`](./release-versioning-and-upgrade-contract.md). Where this document and the contract disagree, the contract wins.

## Cadence

Releases are ad-hoc. There is no fixed schedule. A release is cut when a maintainer decides the changes on `main` are worth tagging — typically when a contract or schema version moves, when new fragments or providers ship, or when a notable bug fix lands.

## Who Cuts Releases

Anyone with `peakweb-team/superagents` maintainer permissions (i.e., merge access to `main`) may cut a release. Tag pushes are not automated.

## Versioning

Superagents follows semantic versioning. The release-versioning contract defines the exact scope rules. They are reproduced here verbatim.

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

Major releases should be used when Superagents changes behavior or metadata in ways that can make existing generated bundles misleading or unsafe.

Examples:

- changing contract meaning rather than only extending it
- requiring new metadata fields for correct interpretation
- changing precedence or upgrade semantics in a breaking way
- making older generated bundle assumptions no longer trustworthy

Expected behavior:

- the release notes must call out the breaking change explicitly
- repo-local generated bundles should be treated as requiring regeneration or migration review
- Superagents should not pretend an older generated bundle is safely current

## Tag Naming

- Format: `vMAJOR.MINOR.PATCH` (for example, `v0.1.0`, `v1.2.3`).
- The `v` prefix is part of the tag name. The `version` field inside `release.json` carries the bare semver string (`0.1.0`), without the `v`.
- No leading-zero or pre-release suffix support in the MVP. Tags like `v01.0.0`, `v1.0.0-rc1`, or `v1.0.0+build.42` are out of scope and will be rejected by the workflow.

## The `release.json` Artifact

Every release ships a machine-readable artifact called `release.json` so downstream tooling (notably the planned `/superagents-upgrade` skill) can decide whether a project's generated bundle is compatible with the installed framework release.

- **Schema:** [`docs/schemas/release.schema.json`](./schemas/release.schema.json) (JSON Schema draft 2020-12).
- **Where it lives at tag time:** `releases/<version>.json` at the repo root, committed in the same commit (or an earlier commit on `main`) that the tag points at. For example, `v0.1.0` reads `releases/0.1.0.json`.
- **What the workflow does with it:** validates against the schema and uploads it as a release asset on the GitHub release. If validation fails, the release run fails and the GitHub release is not created.

The schema requires the following fields. All are required; `additionalProperties: false`.

| Field | Type | Notes |
| --- | --- | --- |
| `version` | string | Semver `MAJOR.MINOR.PATCH` with no leading `v`. Must match the tag's bare version. |
| `release_type` | enum | `patch` \| `minor` \| `major`. |
| `contract_versions` | object | Required keys: `fragment_schema`, `generated_skill_schema`, `integration_declaration_schema`. Each is an integer >= 1. |
| `regeneration_status` | enum | `compatible-no-regeneration-needed` \| `compatible-regeneration-recommended` \| `breaking-regeneration-required`. |
| `changelog_url` | string (uri) | Absolute URL to the human-readable release notes. Typically the GitHub release URL. |
| `commit_sha` | string | Full 40-character lowercase hex SHA the tag points at. |

### `regeneration_status` vs the manifest's `compatibility.status`

The manifest under `.agency/skills/superagents/manifest.yaml` carries a per-bundle `compatibility.status` field with values `compatible` / `regeneration-recommended` / `regeneration-required`. The `release.json` `regeneration_status` enum uses different wording on purpose: the manifest records a specific generated bundle's state, while `release.json` declares the release-wide intent. See the contract's "Recommended status wording" section for the canonical mapping.

## Release Notes Template

GitHub release notes (the human-readable description on the release) should include an upgrade section at minimum. Use this template:

```
## Framework Release Version

vX.Y.Z

## Release Type

patch | minor | major

## Regeneration Posture

compatible-no-regeneration-needed | compatible-regeneration-recommended | breaking-regeneration-required

State whether project-local generated bundles under `.claude/skills/superagents/`
and `.agency/skills/superagents/` need to be regenerated.

## Contract / Schema Version Changes

- fragment_schema: <previous> -> <current> (or "unchanged")
- generated_skill_schema: <previous> -> <current> (or "unchanged")
- integration_declaration_schema: <previous> -> <current> (or "unchanged")

## Manual Review Expectations

- Whether repos with hand-edited generated SKILL.md files need targeted review.
- Whether any breaking change requires the operator to read a specific section of
  the contract before regenerating.

## Highlights

- Bullet-list of notable changes.
```

## Cutting A Release

The maintainer-side workflow:

1. **Decide the version.** Apply the patch / minor / major rules above. Write down the new version string.

2. **Author `releases/<version>.json`** at the repo root, conforming to [`docs/schemas/release.schema.json`](./schemas/release.schema.json). Set `commit_sha` to the SHA of the commit that will be tagged.

3. **Open a PR** containing only the new `releases/<version>.json` file (and any release-note adjustments). Land it through normal review.

4. **Tag the merge commit and push the tag.** From a clean checkout of `main` at the merge commit:

   ```bash
   git fetch --all --tags
   git checkout main
   git pull --ff-only
   git tag -a vX.Y.Z -m "Superagents vX.Y.Z"
   git push origin vX.Y.Z
   ```

5. **The release workflow takes over.** On tag push matching `v[0-9]+.[0-9]+.[0-9]+`, [`.github/workflows/release.yml`](../.github/workflows/release.yml):
   - reads `releases/<bare-version>.json` from the tagged commit
   - validates it against the schema and asserts that the `version` field matches the tag and `commit_sha` matches the tagged commit SHA
   - creates a GitHub release for the tag, with the validated `release.json` attached as an asset (uploaded as `release.json`)
   - fails the run, and does not create the release, if validation fails

6. **Edit the GitHub release description** to add the human-readable release notes using the template above. (The workflow does not author prose.)

If the workflow run fails, fix the `releases/<version>.json` file on `main`, delete the tag locally and on the remote, and re-tag at the new fixing commit. Do not amend the original tag.

## Out Of Scope For MVP

- Auto-bumping version numbers from commit messages (semantic-release-style).
- Multi-channel releases (alpha / beta / rc / nightly).
- Attaching migration scripts as release assets.
- Mirroring releases to other registries.

These are explicitly listed as out-of-scope in [issue #144](https://github.com/peakweb-team/superagents/issues/144).
