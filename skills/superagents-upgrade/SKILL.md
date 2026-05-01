---
name: superagents-upgrade
description: Review, propose, apply, and feed back upgrades for a project's Superagents bundle. Compares the installed framework release, the project's generated skills under .claude/skills/superagents-* and metadata under .agency/skills/superagents/, and the latest superagents origin/main; classifies the delta per the upgrade contract; prompts the operator per change; and hands approved changes either to the skill-builder for local regeneration or to the upstream-feedback flow.
disable-model-invocation: false
argument-hint: "[optional-project-path]"
---

# Superagents Upgrade

Use this skill when an operator wants to bring a project's Superagents bundle in line with a newer installed framework release or the latest superagents `origin/main`. It is the project-local counterpart to the installed `superagents-skill-builder`: the builder generates, this skill reconciles.

This skill is **interactive and never silently applies changes**. Every detected difference must be approved by the operator before any file is written.

## Inputs

- Optional argument: project path. If omitted, use the current working directory.
- Optional environment overrides:
  - `SUPERAGENTS_HOST_CHECKOUT` — absolute path to a host superagents source checkout, used as a fallback when the installed bundle does not record its own framework release. Defaults to "(none)" — see [Phase 1](#phase-1-detect) for the resolution order.
  - `SUPERAGENTS_REMOTE` — origin URL used for the optional remote-fetch in Phase 1. Defaults to `https://github.com/peakweb-team/superagents`.
  - `SUPERAGENTS_FETCH_REMOTE` — set to `1` to opt in to the remote fetch. Default off.

## When To Use

Invoke this skill whenever any of the following is true:

- the operator has just updated the installed Superagents framework (via `~/.claude/skills/superagents-skill-builder/` and friends) and wants to know whether the project bundle needs regeneration
- the project's `.agency/skills/superagents/manifest.yaml` records a `framework_release` that is older than the installed framework
- the operator wants to surface drift between project-local generated skills and what the latest fragments would produce
- the operator wants to forward a noticed gap upstream as a superagents issue

Do **not** invoke this skill to perform the initial bootstrap of a project — for first-time generation use the installed `superagents-skill-builder` directly.

## Phase Map

This skill executes seven phases in order. Phases 1–5 are implemented in this skill. Phases 6 and 7 are deliberately stubbed: they reference dependent epic issues and surface the relevant prompts but do not act yet.

| Phase | Name | Status |
|-------|------|--------|
| 1 | Detect | implemented |
| 2 | Diff | implemented |
| 3 | Summarize | implemented |
| 4 | Decide | implemented |
| 5 | Apply locally | implemented |
| 6 | Devcontainer advisory | stub (deferred to issue #147) |
| 7 | Upstream feedback | stub (deferred to issue #146) |

The seven-phase contract maps to the six-step "Recommended Upgrade Flow" in [`docs/release-versioning-and-upgrade-contract.md`](../../docs/release-versioning-and-upgrade-contract.md): phases 1–2 implement step 2 (compare), phase 3 implements step 3 (surface), phase 4 implements step 5 (review) interactively per change, phase 5 implements step 4 (regenerate), phase 6 is the devcontainer-specific extension of step 5, and phase 7 is the upstream-feedback hand-off introduced for this skill.

## Phase 1 — Detect

Determine three pieces of state.

### 1.1 Installed framework release

Resolve in this order, stopping at the first source that yields a value:

1. **Installed `release.json` artifact.** If `~/.claude/skills/superagents-skill-builder/release.json` exists, read its `version` field as the installed framework release. This is the canonical source once releases ship the artifact alongside the bundle.
2. **Installed bundle frontmatter.** If the installed `~/.claude/skills/superagents-skill-builder/SKILL.md` carries a `framework_release` frontmatter key, use it.
3. **Host superagents checkout.** If `SUPERAGENTS_HOST_CHECKOUT` is set and points at a git checkout, run `git -C "$SUPERAGENTS_HOST_CHECKOUT" describe --tags --always --dirty` and use the result. Mirrors the fallback documented in `skills/skill-builder/SKILL.md` Phase 4.
4. **Unknown — degrade gracefully.** Record the framework release as the literal string `unknown` and surface a warning. Do not fail the skill — the operator can still review the diff against `origin/main`.

Log both the resolved value and the source so the operator can audit it.

> Note: the installed `release.json` (step 1) is the canonical source of the installed framework release once a release has shipped — `docs/release-process.md` defines that artifact and the install path is now configured to forward it into the bundle. Steps 2–4 are backward-compatibility fallbacks for installs that predate the release pipeline or are running directly off `main`. The four-step order above should be promoted into `docs/release-versioning-and-upgrade-contract.md` so consumers other than this skill can rely on it. See the "Open Questions" section at the bottom of this file.

### 1.2 Project bundle metadata

Read the project's manifest at `<project>/.agency/skills/superagents/manifest.yaml` and extract the upgrade-aware metadata fields required by [`docs/release-versioning-and-upgrade-contract.md`](../../docs/release-versioning-and-upgrade-contract.md) and produced by `skills/skill-builder/SKILL.md` Phase 4:

- `framework_release`
- `generated_at`
- `contract_versions.fragment_schema`
- `contract_versions.generated_skill_schema`
- `contract_versions.integration_declaration_schema`
- `compatibility.status` — one of `compatible | regeneration-recommended | regeneration-required`
- `compatibility.reason`
- `compatibility.manual_review_required`

If the manifest is missing entirely, treat the project as never bootstrapped: stop the upgrade flow and direct the operator at the installed `superagents-skill-builder`.

If individual fields are missing, treat each missing field as drift in Phase 2.

### 1.3 Origin/main delta (optional)

Only run when `SUPERAGENTS_FETCH_REMOTE=1` (or the operator explicitly opts in when prompted). All steps use the configured `$SUPERAGENTS_REMOTE` so fork or mirror setups work without code changes.

1. Derive `<owner>/<repo>` from `$SUPERAGENTS_REMOTE` (strip the `https://github.com/` prefix and any trailing `.git`). Use `gh release list --repo <owner>/<repo> --limit 1` to find the latest tagged release.
2. Use `gh api repos/<owner>/<repo>/compare/<latest-tag>...main --jq '.ahead_by'` to count commits on `main` ahead of the latest tag, and `--jq '.commits[].commit.message'` to enumerate them. Prefer this `gh api`-based approach over a clone — it is cheap and stays inside the container.
3. If `gh` is not available, fall back to a shallow clone into a temp directory (`git clone --depth 50 --filter=blob:none $SUPERAGENTS_REMOTE`). Inside the clone, fetch tags (`git fetch --tags --depth=1`) and derive `<latest-tag>` with `git describe --tags --abbrev=0 origin/main`. Then run `git rev-list <latest-tag>..origin/main --count`. Clean up the temp clone before exiting.

Surface the count and the short log so the operator can decide whether to compare against `origin/main` or only against the latest released tag.

## Phase 2 — Diff

Compare four surfaces. Each comparison produces a list of changes that feeds Phase 3.

### 2.1 `contract_versions`

For each of `fragment_schema`, `generated_skill_schema`, `integration_declaration_schema`, compute `installed - project`. Any positive delta is upgrade drift. Any negative delta means the project bundle was generated against a newer framework than the one installed — surface this as an explicit warning ("project bundle is ahead of installed framework"), do not classify it as compatible-to-upgrade.

### 2.2 `fragments.lock.yaml`

Read `<project>/.agency/skills/superagents/fragments.lock.yaml` and compare line-by-line against what the installed builder would produce given the same inventory. The diff that matters is fragment additions, removals, and version bumps; suppression-reason changes are advisory.

If the project bundle does not record a fragment lock, treat the entire fragment set as drift.

### 2.3 Generated `SKILL.md` content

Diff the generated execution-facing files. Their location depends on the layout the project committed under:

- For projects following `docs/generated-skill-layout.md` (current canonical layout), look under `<project>/.claude/skills/superagents/<skill-name>/SKILL.md`.
- For projects updated through issue #135's standardization, additionally check `<project>/.claude/skills/superagents-<function>/SKILL.md`.

For each generated `SKILL.md`, do a textual diff against the file the current installed skill-builder would produce given the locked fragments. Three signals matter:

- **Fragment-driven drift** — content differs because new fragments are selected. Phase 5 can regenerate this cleanly.
- **Manual edits** — content differs from the builder's deterministic output even though the fragment set is unchanged. The operator hand-edited the file. This must be surfaced explicitly per Phase 3.
- **Both** — the file is hand-edited *and* fragments have moved. This is the highest-risk case.

Detect manual edits heuristically: a manual edit is present when the committed `SKILL.md` content cannot be explained by the recorded fragment lock (for example, prose that does not appear in any selected fragment, or sections out of the order the builder emits). The MVP skill-builder does not currently expose a deterministic dry-run mode, so this detection is best-effort, not authoritative — surface a single warning per file rather than line-level attribution. When the skill-builder grows a deterministic dry-run/non-interactive mode (see Open Questions at the bottom of this file), upgrade this step to a strict diff against the dry-run output.

### 2.4 Devcontainer scaffold

Compare the project's `.devcontainer/` files against the templates the installed `superagents-devcontainer-bootstrap` skill would currently emit. Files to compare (sourced from the bootstrap skill's templates):

- `.devcontainer/devcontainer.json`
- `.devcontainer/Dockerfile`
- `.devcontainer/post-create-superagents.sh`
- `.devcontainer/scaffold-devcontainer.sh`
- `.devcontainer/smoke-test-superagents.sh`

A diff in any of these triggers the Phase 6 advisory but does **not** trigger Phase 5 regeneration — devcontainer rebuilds are host-side.

## Phase 3 — Summarize

Print a single, reviewable summary block before any prompt. The summary must include:

### 3.1 Per-surface change counts

```text
Upgrade summary
  Installed framework release: <value> (source: <release.json | bundle frontmatter | host checkout | unknown>)
  Project framework release:   <value>
  Origin/main commits ahead of latest tag: <N or 'not checked'>

  Contract version drift:
    fragment_schema:                <project> -> <installed>
    generated_skill_schema:         <project> -> <installed>
    integration_declaration_schema: <project> -> <installed>

  Fragment lock changes: +<added> / -<removed> / ~<changed>
  Generated SKILL.md changes: <N> file(s) with fragment-driven drift, <M> file(s) with manual edits
  Devcontainer scaffold changes: <K> file(s)
```

### 3.2 Compatibility classification

Compute the project bundle's effective upgrade posture using the rules in `docs/release-versioning-and-upgrade-contract.md` § "Upgrade Classification Rules":

- `compatible` — no contract version delta, no fragment lock changes, no generated content drift beyond noise.
- `regeneration-recommended` — additive contract version delta (minor) or new fragments/providers; no breaking change; old bundle still truthful but no longer ideal.
- `regeneration-required` — at least one breaking signal: a contract version moved in a way the contract calls breaking, or a manifest field that older bundles cannot interpret was added.

Use the `release.json` `regeneration_status` from the installed framework when available — its values map onto the per-bundle `compatibility.status` per `docs/release-process.md` § "regeneration_status vs the manifest's compatibility.status":

| `release.json` `regeneration_status` | Bundle `compatibility.status` |
|---|---|
| `compatible-no-regeneration-needed` | `compatible` |
| `compatible-regeneration-recommended` | `regeneration-recommended` |
| `breaking-regeneration-required` | `regeneration-required` |

Print the classification verbatim — `compatible`, `regeneration-recommended`, or `regeneration-required` — together with the one-line `reason` that should land in the regenerated manifest's `compatibility.reason`.

### 3.3 Manual-edit warnings

When Phase 2.3 detects manual edits, print a warning per the contract's "Manual Edit Expectations During Upgrade":

```text
WARNING: <relative-path-to-SKILL.md>
  This file appears to have been hand-edited since the last builder run.
  Applying this change will overwrite the manual edits.
  Recommended: move durable changes back into fragments or builder inputs
  before re-running this upgrade.
```

The warning is informational; the operator still gets to choose `apply` / `raise` / `skip` / `both` in Phase 4.

## Phase 4 — Decide

For **each** detected change, prompt the operator with a four-way choice. Never apply silently — even when the classification is `regeneration-required`, the operator must approve each change.

Use a structured per-change prompt. The four options are exactly:

- **`apply`** — regenerate this portion locally in Phase 5
- **`raise`** — record the change as an upstream-feedback candidate (Phase 7 stub records it; the upstream issue is not opened in this PR)
- **`skip`** — do nothing for this change in this run
- **`both`** — apply locally **and** record an upstream-feedback candidate

Ask the questions one at a time and group them by surface (contract drift first, then fragment lock, then generated SKILL.md, then devcontainer). For each question:

1. Show the relevant diff or change summary.
2. Show the manual-edit warning if applicable.
3. Show the four options with one-line explanations.
4. Wait for the operator's response.
5. Record the choice in an in-memory plan keyed by change id.

The structured-prompt pattern this codebase uses elsewhere (notably the AskUserQuestion-style flows in the installed skill-builder questionnaire) applies here. Treat each per-change prompt as a single question with a four-option multiple choice.

A "no choice" answer (the operator skips the prompt or terminates the session) defaults to `skip` for that change. Never default to `apply`.

When all changes have a recorded choice, print the plan back to the operator for a final confirmation before Phase 5 begins:

```text
Plan:
  apply:   <N> change(s)
  raise:   <M> change(s)
  skip:    <K> change(s)
  both:    <L> change(s)
Proceed? [y/N]
```

A `N` (or no answer) terminates the skill cleanly without writing files. A `y` proceeds to Phase 5.

## Phase 5 — Apply locally

For every change marked `apply` or `both`:

1. **Hand off to the installed skill-builder.** Do **not** invoke any CLI. Hand off by invoking the `superagents-skill-builder` skill with a context describing the regeneration intent. Pass:
   - the project root
   - the list of approved change ids (advisory only — see scoping note below)
   - the `regeneration-recommended` / `regeneration-required` posture
   - any unresolved decisions captured in `decisions.yaml` so the builder does not re-ask them

   **Scoping note:** the MVP skill-builder regenerates the whole bundle in a single run. It does not yet promise scoped regeneration, deterministic dry-run, or a fully non-interactive replay from `fragments.lock.yaml` plus `decisions.yaml`. Phase 5 therefore depends only on the whole-bundle path: pass the change-id list as advisory context for the builder's review summary, regenerate the whole bundle, and let the operator review the resulting diff in normal git history. If the operator approved only a subset of changes, the resulting diff will include changes the operator did not explicitly approve — surface that fact in the final summary so the operator can selectively `git restore` portions before committing. Tightening this hand-off (deterministic dry-run, scoped regeneration) is tracked under Open Questions at the bottom of this file.

2. **Outputs land at the canonical roots:**
   - `<project>/.claude/skills/superagents/` — the execution-facing root described in `docs/generated-skill-layout.md`. For projects following the `superagents-<function>` standardization from issue #135, generated skills also land at `<project>/.claude/skills/superagents-<function>/`.
   - `<project>/.agency/skills/superagents/` — the metadata bundle root.

3. **Verify the regenerated manifest.** After the builder finishes, run `tests/test-manifest-upgrade-metadata.sh` from the project's superagents source checkout (or the host checkout) against the regenerated `<project>/.agency/skills/superagents/manifest.yaml` if the test supports out-of-tree fixture paths; otherwise, re-validate the required-field set inline:
   - `framework_release` is non-empty
   - `generated_at` parses as ISO-8601
   - `contract_versions` contains all three required keys
   - `compatibility.status` is one of the three allowed values
   - `compatibility.reason` is non-empty
   - `compatibility.manual_review_required` is a boolean

   If validation fails, **stop and surface the failure**. Do not pretend the upgrade succeeded.

4. **Print the final diff summary.** List every file that was created, modified, or deleted under both roots so the operator can stage and review with normal `git diff`.

## Phase 6 — Devcontainer advisory (stub)

This phase is **deliberately stubbed** in this skill version. Full implementation is tracked under issue #147 (epic #148).

When Phase 2.4 detected differences in any of `.devcontainer/devcontainer.json`, `.devcontainer/Dockerfile`, `.devcontainer/post-create-superagents.sh`, `.devcontainer/scaffold-devcontainer.sh`, or `.devcontainer/smoke-test-superagents.sh`:

1. Print:
   ```text
   Devcontainer scaffold has changed. A host-side rebuild is required.
   Phase 6 (devcontainer rebuild advisory) is deferred to issue #147 — see epic #148.
   For the rebuild command and detach-VS-Code-first reminder, see the
   superagents-devcontainer skill, "Rebuild" section.
   ```
2. Reference the `superagents-devcontainer` skill's "Rebuild" section as the operational source.
3. **Do not** invoke `devcontainer` or `docker` from inside this skill. The skill runs inside the devcontainer; rebuilds happen on the host.
4. Move on. Phase 6 must not block phases that already executed.

## Phase 7 — Upstream feedback (stub)

This phase is **deliberately stubbed** in this skill version. Full implementation is tracked under issue #146 (epic #148).

For every change the operator marked `raise` or `both`:

1. Print:
   ```text
   Upstream feedback for this change is deferred to issue #146 — see epic #148.
   Selection recorded.
   ```
2. Append a structured selection record to `<project>/.agency/skills/superagents/upstream-feedback-pending.log` so the future #146 implementation can pick the records up. Each record is one line, key:value pairs separated by `;`:
   ```text
   ts:<ISO-8601>; surface:<contract|fragments|skill-md|devcontainer>; change_id:<id>; choice:<raise|both>; summary:<one-line>
   ```
   Create the file if it does not exist; append otherwise. Never overwrite.
3. **Do not** call `gh issue create`. The upstream issue creation is exclusively #146's territory.

## Error Handling

- **Manifest missing** → stop with a clear message; direct the operator at the installed skill-builder for first-time generation. Do not pretend to upgrade a project that has not been bootstrapped.
- **Installed framework release unresolved** → continue with `unknown` and warn; the diff against `origin/main` is still useful.
- **Network unavailable for Phase 1.3** → skip the origin/main delta silently; the rest of the flow continues.
- **Builder hand-off fails in Phase 5** → leave the project in its pre-Phase-5 state. The skill-builder is responsible for atomic writes; if it left a partial bundle, surface that with a message asking the operator to revert.
- **Manifest validation fails after regeneration** → stop and surface the failure. Do not let the operator commit a manifest the upgrade-metadata test would reject.

## Stopping Conditions

The skill stops cleanly (without applying changes) when:

- the project has no `.agency/skills/superagents/manifest.yaml` (project never bootstrapped)
- the operator declines the Phase 4 plan confirmation
- every detected change is marked `skip`
- the installed framework release equals the project's `framework_release` *and* every Phase 2 surface is empty (nothing to upgrade)

The skill stops with an error when:

- the manifest exists but is malformed (cannot be parsed as YAML)
- Phase 5 hand-off to the builder fails or produces an invalid manifest

## Success Criteria

- Detection logged the installed framework release, the project framework release, and (when opted in) the origin/main commit count, with sources for each.
- The summary block printed all four diff surfaces with counts.
- The classification matches the upgrade contract's three states verbatim.
- Manual-edit warnings, when applicable, named the file path and the consequence.
- Every detected change received a per-change `apply | raise | skip | both` decision from the operator.
- For changes marked `apply` or `both`, the regenerated bundle's `manifest.yaml` validates against the upgrade-metadata field set.
- For changes marked `raise` or `both`, an entry was appended to `upstream-feedback-pending.log`.
- For devcontainer-scaffold changes, the operator saw the host-side rebuild advisory and was pointed at the `superagents-devcontainer` skill.

## Reference

- Authoritative upgrade contract: [`docs/release-versioning-and-upgrade-contract.md`](../../docs/release-versioning-and-upgrade-contract.md)
- Release artifact and pipeline: [`docs/release-process.md`](../../docs/release-process.md), [`docs/schemas/release.schema.json`](../../docs/schemas/release.schema.json)
- Generated layout this skill operates on: [`docs/generated-skill-layout.md`](../../docs/generated-skill-layout.md)
- The skill-builder this skill hands off to in Phase 5: [`skills/skill-builder/SKILL.md`](../skill-builder/SKILL.md)
- Companion devcontainer skill referenced from Phase 6: [`skills/superagents-devcontainer/SKILL.md`](../superagents-devcontainer/SKILL.md)
- Manifest validation harness used in Phase 5 verification: [`tests/test-manifest-upgrade-metadata.sh`](../../tests/test-manifest-upgrade-metadata.sh)

## Open Questions

These are surfaced for the operator and for follow-up work; they are not blocking.

- **Promote Phase 1.1 resolution order into the contract.** The installed `release.json` is canonical when present; the other three steps (bundle frontmatter, host-checkout `git describe`, literal `unknown`) are backward-compatibility fallbacks for installs that predate the release pipeline. `docs/release-versioning-and-upgrade-contract.md` does not yet record this ordering — it should, so other consumers can rely on the same resolution.
- **Builder hand-off contract for Phase 5 and Phase 2.3.** Phase 2.3's manual-edit detection is best-effort heuristic and Phase 5's hand-off regenerates the whole bundle, because the installed `superagents-skill-builder` does not yet promise three behaviors this skill would benefit from: (1) deterministic re-run from `fragments.lock.yaml` plus `decisions.yaml` without re-prompting, (2) a `--dry-run` mode that emits the would-be output without writing files, (3) a `--scope` / `--change-ids` mode that regenerates only a subset of skills. Adding those behaviors to `skills/skill-builder/SKILL.md` is a follow-up; until then, this skill stays on the whole-bundle-regenerate path and on heuristic manual-edit detection. See `skills/skill-builder/SKILL.md` Phase 4 for the current contract.
- **Phase 7 record format.** The `upstream-feedback-pending.log` line format above is provisional. Issue #146 will define the canonical record shape; until then the line-based format is forward-compatible and easy to grep.
