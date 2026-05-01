---
name: superagents-upgrade
description: Review, propose, apply, and feed back upgrades for a project's Superagents bundle. Compares the installed framework release, the project's generated skills under .claude/skills/superagents-* and metadata under .agency/skills/superagents/, and the latest superagents origin/main; classifies the delta per the upgrade contract; prompts the operator per change; and hands approved changes either to the skill-builder for local regeneration or to the upstream-feedback flow.
disable-model-invocation: false
argument-hint: "[feedback] [optional-project-path]"
---

# Superagents Upgrade

Use this skill when an operator wants to bring a project's Superagents bundle in line with a newer installed framework release or the latest superagents `origin/main`. It is the project-local counterpart to the installed `superagents-skill-builder`: the builder generates, this skill reconciles.

This skill is **interactive and never silently applies changes**. Every detected difference must be approved by the operator before any file is written.

## Inputs

- Optional first argument: subcommand. Today exactly one subcommand is recognised:
  - `feedback` — enter the Phase 7 upstream-feedback flow directly without running phases 1–6. Equivalent to `/superagents-upgrade feedback [optional-project-path]`. See "Phase 7 — Upstream feedback" below.
  - any other first argument is treated as the project path (back-compat with the original single-argument form).
- Optional positional argument: project path. If omitted, use the current working directory.
- Optional environment overrides:
  - `SUPERAGENTS_HOST_CHECKOUT` — absolute path to a host superagents source checkout, used as a fallback when the installed bundle does not record its own framework release. Defaults to "(none)". The resolution order is described in the "Phase 1 — Detect" section below.
  - `SUPERAGENTS_REMOTE` — origin URL used for the optional remote-fetch in Phase 1. Defaults to `https://github.com/peakweb-team/superagents`.
  - `SUPERAGENTS_FETCH_REMOTE` — set to `1` to opt in to the remote fetch. Default off.
  - `SUPERAGENTS_FEEDBACK_REPO` — `owner/repo` slug used by Phase 7 when calling `gh issue create`. Defaults to `peakweb-team/superagents`. Override only when running against a fork or staging mirror.

## When To Use

Invoke this skill whenever any of the following is true:

- the operator has just updated the installed Superagents framework (via `~/.claude/skills/superagents-skill-builder/` and friends) and wants to know whether the project bundle needs regeneration
- the project's `.agency/skills/superagents/manifest.yaml` records a `framework_release` that is older than the installed framework
- the operator wants to surface drift between project-local generated skills and what the latest fragments would produce
- the operator wants to forward a noticed gap upstream as a superagents issue

Do **not** invoke this skill to perform the initial bootstrap of a project — for first-time generation use the installed `superagents-skill-builder` directly.

## Phase Map

This skill executes seven phases in order, plus a 5b "in-container update" branch that runs in parallel with phase 5 when scaffold files are unchanged. All seven phases (and phase 5b) are implemented in this skill. Phase 7 is also reachable as a standalone shortcut via `/superagents-upgrade feedback` — see the Phase 7 section for details.

| Phase | Name | Status |
|-------|------|--------|
| 1 | Detect | implemented |
| 2 | Diff | implemented |
| 3 | Summarize | implemented |
| 4 | Decide | implemented |
| 5 | Apply locally | implemented |
| 5b | In-container update path | implemented (issue #149) |
| 6 | Devcontainer advisory | implemented |
| 7 | Upstream feedback | implemented (also reachable standalone) |

The phase contract maps to the six-step "Recommended Upgrade Flow" in [`docs/release-versioning-and-upgrade-contract.md`](../../docs/release-versioning-and-upgrade-contract.md): phases 1–2 implement step 2 (compare), phase 3 implements step 3 (surface), phase 4 implements step 5 (review) interactively per change, phase 5 implements step 4 (regenerate) for the project bundle, phase 5b extends step 4 to the container-installed `~/.claude/` surface (only when scaffold files match), phase 6 is the devcontainer-specific extension of step 5 for the rebuild branch, and phase 7 is the upstream-feedback hand-off introduced for this skill.

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
- **`raise`** — open an upstream issue against the superagents repo for this change in Phase 7 (after operator confirmation of the rendered body). The change is not applied locally.
- **`skip`** — do nothing for this change in this run
- **`both`** — apply locally **and** open an upstream issue for this change in Phase 7

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

## Phase 5b — In-container update path

This phase is the container-surface mirror of Phase 5. While Phase 5 regenerates the project-local bundle under `<project>/.claude/skills/superagents/` and `<project>/.agency/skills/superagents/`, Phase 5b refreshes the user-level Superagents install under `~/.claude/` (skills like `superagents-skill-builder`, `superagents-devcontainer`, `superagents-upgrade` themselves, plus `~/.claude/agents/`). The two surfaces drift independently and Phase 5b targets only the container-installed surface.

### When to surface

Phase 5b is offered when **both** of the following are true:

1. **Phase 3 classification** is `regeneration-recommended` or `regeneration-required` (i.e. there is something worth applying — Phase 5b is a no-op when the project is already `compatible`).
2. **Phase 2.4 detected no scaffold drift.** All four scaffold files (`.devcontainer/Dockerfile`, `.devcontainer/devcontainer.json`, `.devcontainer/post-create-superagents.sh`, `.devcontainer/scaffold-devcontainer.sh`) match the target ref. If even one differs, defer to Phase 6 (rebuild advisory) instead — the in-container path would fail its own scaffold guard and refuse to run.

When scaffold files have changed: do **not** offer the in-container path. Surface only the Phase 6 rebuild advisory. Mentioning Phase 5b in this case would mislead the operator into running a script that will exit with code 2.

### What to surface

When Phase 5b is offered, present it alongside the Phase 5 project-bundle option as a parallel choice. Make the trade-off explicit so the operator can pick:

```text
Two refresh paths are available for this upgrade:

  [a] Project-bundle regeneration (Phase 5)
      Refreshes <project>/.claude/skills/superagents/ and
      <project>/.agency/skills/superagents/ from the installed builder.
      Scope: this project's bundle only.

  [b] In-container update (Phase 5b)
      Refreshes ~/.claude/ (user-level superagents install) from
      <ref> via .devcontainer/upgrade-superagents-in-container.sh.
      Scope: every project sharing this devcontainer's ~/.claude/.
      Faster than a full rebuild; cleaner state than a manual clone.

  [c] Both
      Run [a] then [b].

  [d] Skip both (operator runs nothing).
```

The two paths address different surfaces and are not redundant: the project bundle is what the project's own skills read at runtime; `~/.claude/` is what the operator's `claude` session loads on startup. Most upgrades benefit from refreshing both.

### How to invoke

For choice `[b]` or `[c]`, do **not** invoke the script from inside this skill's process. Instead, instruct the operator to run, from the container terminal:

```bash
.devcontainer/upgrade-superagents-in-container.sh
```

To pin a specific ref:

```bash
SUPERAGENTS_REF=<tag-or-sha> .devcontainer/upgrade-superagents-in-container.sh
```

The script ships in every project scaffolded via `superagents-devcontainer-bootstrap` (template at `skills/devcontainer-bootstrap/templates/upgrade-superagents-in-container.sh` in the superagents repo, copied into target projects' `.devcontainer/` by `scaffold-devcontainer.sh`). It re-runs the scaffold guard on its own — if scaffold files have drifted between the time of this Phase 5b decision and the time the script runs, it will exit with code 2 and the operator will need to follow the Phase 6 rebuild advisory.

### What the script does

1. **Host guard.** Refuses to run on the host (would clobber the operator's host claude install).
2. **Shallow clone.** Clones `$SUPERAGENTS_REPO@$SUPERAGENTS_REF` into a temp dir and removes it on exit.
3. **Scaffold guard.** Compares the four scaffold files. Exits 2 with a "rebuild required" message if any differ, without touching `~/.claude/`.
4. **Install.** Runs `scripts/install.sh --tool claude-code --no-interactive` against the cloned checkout.
5. **Diff report.** Prints the file paths under `~/.claude/` that were added, removed, or modified, and reminds the operator to restart their claude session if a `SKILL.md` they had open was changed.

### Recording the decision

Treat Phase 5b like any other Phase 4 decision: record the operator's choice in the in-memory plan so the final summary lists "in-container update: invoked / deferred / skipped". The script itself emits the durable audit trail (the diff report under `~/.claude/`); this skill does not need to write a separate log entry. Do **not** append to `upstream-feedback-pending.log` — that log's format is owned by Phase 7 (issue #146) and is reserved for `raise` / `both` decisions.

### Manual smoke test

After running the script, a quick sanity check inside the same container session:

```bash
ls -la ~/.claude/skills/superagents-devcontainer/SKILL.md
head -3 ~/.claude/skills/superagents-devcontainer/SKILL.md
```

The mtime should be recent; the content should match the target ref. If the operator had a claude session running, they should restart it (or use the in-session reload) so the refreshed skills are loaded.

## Phase 6 — Devcontainer advisory

This phase consumes the diff produced in Phase 2.4 and surfaces a host-side rebuild advisory when — and only when — the project's `.devcontainer/` scaffold has drifted from what the installed framework release would currently emit. It is **advisory only**: the skill never invokes `devcontainer`, `docker`, or any other host-side process from inside the container.

### 6.1 Detect

The diff source is Phase 2.4's comparison: the project's `.devcontainer/` directory against the templates the installed `superagents-devcontainer-bootstrap` skill would currently emit. Phase 1.1 already resolved the installed framework release and recorded its source (`release.json`, bundle frontmatter, host checkout, or `unknown`); Phase 2.4 uses that resolution to locate the templates to compare against. Phase 6 reuses Phase 2.4's per-file change list verbatim — do not re-walk the filesystem.

The four scaffold files this advisory tracks are:

- `.devcontainer/devcontainer.json`
- `.devcontainer/Dockerfile`
- `.devcontainer/post-create-superagents.sh`
- `.devcontainer/scaffold-devcontainer.sh`

(Phase 2.4 may additionally compare `.devcontainer/smoke-test-superagents.sh`. A diff in the smoke-test script alone does not require a host rebuild — it is a runtime helper, not a scaffold input — so when the only differing file is `smoke-test-superagents.sh`, this advisory stays silent and the change is left to the in-container update path; see § 6.5.)

### 6.2 Project never bootstrapped a devcontainer

If `<project>/.devcontainer/` does not exist, the project never bootstrapped a devcontainer. **Skip Phase 6 entirely and silently** — no warning, no prompt, no log line that would read like a warning. Bootstrap is the `superagents-devcontainer-bootstrap` skill's territory, not this skill's.

### 6.3 No-change branch

If Phase 2.4 reported zero scaffold-file diffs (or the only diff is `smoke-test-superagents.sh`; see § 6.1), the advisory is silent — no rebuild prompt, no false-positive guidance.

The silent pass is still recorded in the upgrade run summary printed by Phase 3 / the final summary in Phase 5, in the form:

```text
Devcontainer scaffold: checked, no rebuild required.
```

Reviewers reading the run output can see Phase 6 was evaluated and intentionally produced no operator-facing prompt. When the scaffold is unchanged but other in-container framework files have moved (fragments, generated SKILL.md content, manifests), the in-container update path defined in issue #149 takes over — this advisory hands off to that flow rather than printing its own guidance. See § 6.5 for the hand-off contract.

### 6.4 Change branch

If Phase 2.4 reported one or more scaffold-file diffs (excluding the smoke-test-only case in § 6.1), print the advisory below. Print it once per upgrade run, after Phase 5 has finished applying any local regeneration so the operator sees it as the final actionable item.

Output format:

```text
## Devcontainer scaffold changes detected

The following devcontainer files differ between the installed framework release and the target framework release:
  - <relative path, one per line, e.g. .devcontainer/Dockerfile>
  - <relative path, one per line, e.g. .devcontainer/post-create-superagents.sh>

A host-side rebuild is required for these changes to take effect. The
container you are reading this from is running the previous scaffold and
will not pick up the new Dockerfile / post-create / devcontainer.json /
scaffold-devcontainer.sh until it is rebuilt from the host.

Before rebuilding:
  1. In VS Code, open the Command Palette and run
     "Dev Containers: Close Remote Connection".
  2. Confirm the status bar no longer shows the container name.

Then run on the host (not inside this container):

  devcontainer up --workspace-folder . --remove-existing-container

For full rebuild guidance — including the VS Code Command Palette
equivalent, prerequisite checks, and the rationale for detaching first —
see the `superagents-devcontainer` skill, sections "Rebuild" and
"Important: Detach VS Code First". Do not copy the procedure inline; that
skill is the canonical source.
```

Constraints on this output:

- The diff list must be exactly the per-file changes Phase 2.4 produced — never a hard-coded list of all four files. Operators should see which files actually drifted, not a boilerplate roster.
- The exact host-side command printed is the one from `superagents-devcontainer/SKILL.md` § "Rebuild" → "CLI (host terminal)": `devcontainer up --workspace-folder . --remove-existing-container`. Do not paraphrase or substitute.
- The detach reminder must point at `superagents-devcontainer/SKILL.md` § "Important: Detach VS Code First" by name. The two short numbered steps shown above are operator-facing pointers to that section, not a re-implementation of it; if the canonical detach procedure changes, update that skill, not this one.
- The reference to `superagents-devcontainer` is **by skill name**, not by inline-copying its full rebuild procedure (`Dev Containers: Rebuild Container`, `Dev Containers: Rebuild Without Cache`, the `npm install -g @devcontainers/cli` prerequisite check, etc. all live in that skill).

After printing the advisory, Phase 6 returns. It does **not** invoke `devcontainer`, `docker`, `gh`, or any other host-targeting command from inside the container. The operator runs the rebuild themselves on the host.

### 6.5 Coordination with #149 (in-container update path)

Issue #149 introduces the **in-container update path**: when the framework has moved but the `.devcontainer/` scaffold is unchanged, some installed-framework changes can be applied to the running container without a rebuild. That path is implemented separately from this advisory and lives in its own section of this skill (most likely a Phase 5b or a dedicated section between Phase 5 and Phase 6).

The hand-off contract between Phase 6 and #149's section is:

- **Scaffold differs (this Phase 6 fires):** print the advisory in § 6.4 and stop. Do **not** also run #149's in-container update — a host rebuild will reset the container and any in-container updates would be wasted work. The operator's next action is the host-side rebuild.
- **Scaffold unchanged (this Phase 6 silent per § 6.3):** hand off to #149's in-container update flow. The silent run-summary line in § 6.3 is the seam #149 reads from when deciding whether to fire. Phase 6 does not implement that flow itself.

This skill must not duplicate, pre-empt, or contradict #149's section. If a future change makes scaffold drift recoverable without a rebuild, that change belongs in #149's flow, not in Phase 6.

### 6.6 Constraints (do not violate)

- **Advisory only.** Never invoke `devcontainer`, `docker`, `code`, or any host-side process. The skill runs inside the container; the host is unreachable.
- **Reference, do not inline.** The `superagents-devcontainer` skill is the canonical source for the rebuild and detach procedure. Phase 6 prints exactly the one host command and points at the skill — no copying the full procedure.
- **No `.devcontainer/` rewriting.** Phase 6 reads scaffold drift; it never writes scaffold files. The operator's rebuild is what brings the new scaffold into effect.
- **Silent when not actionable.** When `.devcontainer/` is absent, when no scaffold files differ, or when only `smoke-test-superagents.sh` differs, the advisory does not print operator-facing prompts. Surface only the run-summary line described in § 6.3.
- **Non-blocking.** Phase 6 must not abort earlier-phase results. By the time it runs, Phase 5 has already applied (or skipped) local regeneration; Phase 6 only adds an advisory at the tail.

## Phase 7 — Upstream feedback

Open one upstream issue per operator-confirmed improvement against the superagents repo, and append a record of every successful filing to `<project>/.agency/skills/superagents/upstream-feedback.log`.

Phase 7 has two entry paths:

- **In-flow (continued from Phase 4).** Phase 7 runs once Phase 5 (and the Phase 6 stub print) have completed. For every change the operator marked `raise` or `both`, the skill prepares one upstream issue draft. The `originated_in_phase` field on the log record is `4`.
- **Standalone (`/superagents-upgrade feedback`).** When the first argument is the literal string `feedback`, skip phases 1–6 entirely. Prompt the operator for a single ad-hoc improvement and open one issue. The `originated_in_phase` field on the log record is `7`. The operator may run the standalone path even on projects that have never been bootstrapped — Phase 7 does not read the project manifest, only the project path, so the "manifest missing" stop condition does not apply when the entry path is `feedback`.

Both paths share the per-issue authoring loop (7.2 → 7.6) below.

### 7.1 Standalone entry — gather the improvement

Only when entered via `/superagents-upgrade feedback`. (When continuing from Phase 4, skip to 7.2 and use the operator's already-recorded `raise`/`both` change as the seed.)

Prompt the operator, in order:

1. `improvement_type` — one of: `fragment | agent | builder-behavior | devcontainer | docs | bug | other`.
2. `summary` — one line. This becomes the issue title verbatim.
3. `motivating_example` — free text. Encourage paths, snippets, observed-vs-expected behavior. Multi-line is fine.
4. `labels` (optional) — additional comma-separated labels to apply on top of the type-default set in 7.3.
5. `project_context` (optional) — the path within the current project that surfaced the improvement (for example, `apps/web/src/foo.ts` or `the entire .claude/skills/superagents-deliver bundle`). Free text. Recorded in the log; not embedded in the issue body unless the operator decides to include it.

If the operator answers `other` to `improvement_type`, ask them for a one-line clarification. Carry that clarification into the rendered body's `## Context` section so reviewers do not have to guess what bucket the issue belongs in.

### 7.2 Map type → template + label hints

Phase 7 maps `improvement_type` onto two things: which `.github/ISSUE_TEMPLATE/*.yml` to attach (when one exists) and which default labels to suggest.

| `improvement_type` | Issue template | Default labels |
|---|---|---|
| `fragment` | (none — programmatic body, see 7.4) | `enhancement`, `packaging` |
| `agent` | `new-agent-request.yml` | `enhancement`, `new-agent` |
| `builder-behavior` | (none — programmatic body) | `enhancement`, `builder` |
| `devcontainer` | (none — programmatic body) | `enhancement`, `packaging` |
| `docs` | (none — programmatic body) | `docs` |
| `bug` | `bug-report.yml` | `bug` |
| `other` | (none — programmatic body) | `enhancement` |

Operator-supplied labels from 7.1 step 4 are unioned onto the default set (deduplicated, preserving order).

This skill does **not** add new `.github/ISSUE_TEMPLATE/*.yml` files. The five non-template types render their body directly from the convention documented in 7.4. Adding dedicated templates for `fragment`, `builder-behavior`, `devcontainer`, `docs`, or `other` is a follow-up — track it under a separate issue rather than here.

### 7.3 Render the body

Two rendering paths.

**Templated path (`agent`, `bug`).** Prepare a body that fills the template's structured fields with the operator's answers. The skill does not inline the template's YAML — `gh issue create --template <name>` opens the template form prefilled. The operator confirms or edits before send.

**Programmatic path (everything else).** Render a body that follows the `## Context` / `## Goal` / `## Acceptance Criteria` / `## Dependencies` / `## Out of scope` convention used in closed issues #126 and #135. The exact template:

```markdown
## Context

<motivating_example, verbatim. If improvement_type was `other`, prepend the operator's
one-line clarification on its own paragraph before the motivating example.>

## Goal

<summary, optionally extended by the operator at the confirmation prompt below>

## Acceptance Criteria

- [ ] <operator-authored bullets — leave a single placeholder bullet for the operator to fill>

## Dependencies

<one-line — operator may reference an existing issue or write `None`>

## Out of scope

<one-line — operator may write `None`>
```

The skill never invents acceptance criteria or out-of-scope items on the operator's behalf. It populates the `## Context` and `## Goal` sections from the answers in 7.1 and leaves the remaining sections as placeholders the operator fills at the confirmation prompt.

### 7.4 Confirm and edit

Display the rendered body verbatim, plus the resolved title, label set, target repo (from `SUPERAGENTS_FEEDBACK_REPO`, default `peakweb-team/superagents`), and template flag (if any). Prompt:

```text
Open this issue against <repo>?
  [y]   yes — submit as shown
  [e]   edit — re-prompt to revise the body before submitting
  [N]   no  — abort. Nothing is written upstream and no record is appended to the log.
```

A `N` (or no answer) terminates this issue's authoring loop without writing anything. If the operator chose `both` in Phase 4 and aborts the upstream issue here, the local apply already happened — surface that explicitly so the operator knows the apply is not rolled back.

The operator may select `e` an unbounded number of times. Each `e` round re-prompts only the fields the operator wants to change.

### 7.5 Submit

Run, with arguments:

- `--repo "$SUPERAGENTS_FEEDBACK_REPO"` (defaulting to `peakweb-team/superagents`)
- `--title "<summary>"`
- `--body-file <tmpfile>` (write the confirmed body to a tempfile under `$TMPDIR` and pass its path; never embed the body inline on the command line)
- one `--label <value>` per label in the resolved label set
- `--template <name>` only when 7.2 mapped this type to a yml template

```bash
gh issue create \
  --repo "$SUPERAGENTS_FEEDBACK_REPO" \
  --title "$summary" \
  --body-file "$body_file" \
  $label_flags \
  $template_flag
```

Capture the URL from `gh`'s stdout. If `gh issue create` exits non-zero (network failure, auth failure, label that does not exist on the repo), surface the error verbatim, do not append a partial record to the log, and offer to retry. The local apply (for `both`) is not rolled back on submit failure — apply already happened in Phase 5.

### 7.6 Record the filing

Append exactly one line to `<project>/.agency/skills/superagents/upstream-feedback.log`. Each line is a single JSON object (JSON Lines / `.jsonl` format, but the file is named `.log` to match the rest of the bundle's log naming). Do not pretty-print across multiple lines — readers grep this file.

Required fields (always present):

| Field | Type | Description |
|---|---|---|
| `created_at` | string (ISO-8601, UTC, second precision) | When this record was appended. Example: `2026-04-30T14:23:05Z`. |
| `improvement_type` | string | One of `fragment | agent | builder-behavior | devcontainer | docs | bug | other`. |
| `summary` | string | The issue title, verbatim. |
| `issue_url` | string | The full URL returned by `gh issue create`. |
| `issue_number` | integer | The issue number parsed from the URL's trailing path segment. |
| `originated_in_phase` | integer | `4` when reached via Phase 4's `raise`/`both`. `7` when reached via the standalone `feedback` shortcut. |
| `project_context` | string | The free-text project path from 7.1 step 5. Empty string when the operator skipped that prompt. |

Optional fields (present only when relevant):

| Field | Type | Description |
|---|---|---|
| `change_id` | string | The Phase 4 change id this record corresponds to. Present only when `originated_in_phase` is `4`. |
| `surface` | string | One of `contract | fragments | skill-md | devcontainer`. Present only when `originated_in_phase` is `4`. |
| `labels` | array of string | The resolved label set submitted with the issue. Always recorded for auditability. |
| `template` | string | The yml template name (without `.yml`) when 7.2 selected one. Omitted otherwise. |

Example records:

```jsonl
{"created_at":"2026-04-30T14:23:05Z","improvement_type":"fragment","summary":"Add fragment for tracker-sync providers","issue_url":"https://github.com/peakweb-team/superagents/issues/200","issue_number":200,"originated_in_phase":7,"project_context":"apps/api/.agency/skills/superagents/manifest.yaml","labels":["enhancement","packaging"]}
{"created_at":"2026-04-30T14:25:11Z","improvement_type":"bug","summary":"Builder writes empty fragments.lock when capability fallback fires","issue_url":"https://github.com/peakweb-team/superagents/issues/201","issue_number":201,"originated_in_phase":4,"project_context":".claude/skills/superagents-deliver/SKILL.md","change_id":"skill-md.superagents-deliver","surface":"skill-md","labels":["bug"],"template":"bug-report"}
```

Create `.agency/skills/superagents/upstream-feedback.log` if it does not exist; append otherwise. Never rewrite a previous line.

#### Migration from the provisional `upstream-feedback-pending.log`

Issue #145 introduced `<project>/.agency/skills/superagents/upstream-feedback-pending.log` as a provisional artifact for Phase 7's stub. With Phase 7 implemented, the canonical artifact is `upstream-feedback.log` (this section's format) and the `-pending.log` name is retired.

When Phase 7 starts (in either entry path), the skill performs a one-shot migration before appending any new records:

1. If `<project>/.agency/skills/superagents/upstream-feedback-pending.log` exists and `<project>/.agency/skills/superagents/upstream-feedback.log` does not: rename `upstream-feedback-pending.log` to `upstream-feedback.log`. Surface a one-line notice (`migrated upstream-feedback-pending.log → upstream-feedback.log`).
2. If both files exist: append the contents of `upstream-feedback-pending.log` to `upstream-feedback.log`, then delete `upstream-feedback-pending.log`. Surface the merge.
3. If only `upstream-feedback.log` exists, or neither exists: do nothing.

The provisional records in `-pending.log` are line-formatted (`key:value;` pairs) per the #145 stub. They are intentionally kept as-is rather than rewritten into JSON Lines — readers that grep the log will find both formats interleaved, which is acceptable for a one-time migration window. New records always use the JSON Lines format above.

### 7.7 Print outcome

Print the URL back to the operator and confirm the log append:

```text
Filed: <issue_url>
Recorded in: <project>/.agency/skills/superagents/upstream-feedback.log
```

When the in-flow path was processing more than one `raise`/`both` change, repeat 7.2 → 7.7 once per change, in the order Phase 4 recorded the choices.

## Error Handling

- **Manifest missing** → stop with a clear message; direct the operator at the installed skill-builder for first-time generation. Do not pretend to upgrade a project that has not been bootstrapped.
- **Installed framework release unresolved** → continue with `unknown` and warn; the diff against `origin/main` is still useful.
- **Network unavailable for Phase 1.3** → skip the origin/main delta silently; the rest of the flow continues.
- **Builder hand-off fails in Phase 5** → leave the project in its pre-Phase-5 state. The skill-builder is responsible for atomic writes; if it left a partial bundle, surface that with a message asking the operator to revert.
- **Manifest validation fails after regeneration** → stop and surface the failure. Do not let the operator commit a manifest the upgrade-metadata test would reject.
- **`gh issue create` fails in Phase 7** → surface the error verbatim, do not append a partial record to `upstream-feedback.log`, and offer to retry. If the operator chose `both` in Phase 4, the local apply already happened — make this explicit so the operator knows the apply is not rolled back.
- **`gh` not installed or not authenticated when Phase 7 needs to submit** → stop the Phase 7 sub-flow with a clear message ("`gh auth login` against a token with `repo` scope on `$SUPERAGENTS_FEEDBACK_REPO`"). The rest of the upgrade run (phases 1–5 results) is unaffected.

## Stopping Conditions

The skill stops cleanly (without applying changes) when:

- the project has no `.agency/skills/superagents/manifest.yaml` (project never bootstrapped) — except when entered via `/superagents-upgrade feedback`, which does not require a bootstrapped project
- the operator declines the Phase 4 plan confirmation
- every detected change is marked `skip`
- the installed framework release equals the project's `framework_release` *and* every Phase 2 surface is empty (nothing to upgrade)
- in Phase 7, the operator answers `N` (or no answer) to the confirm-and-edit prompt for every pending issue (no upstream issues filed, no log records written)

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
- For changes marked `raise` or `both`, the operator confirmed the rendered body, an upstream issue was filed via `gh issue create`, and a JSON Lines record was appended to `<project>/.agency/skills/superagents/upstream-feedback.log` capturing the URL, type, and project context.
- The standalone shortcut `/superagents-upgrade feedback` reaches Phase 7 directly, prompts the operator for one improvement, and produces the same log entry shape with `originated_in_phase: 7`.
- For devcontainer-scaffold changes, the operator saw the host-side rebuild advisory and was pointed at the `superagents-devcontainer` skill.
- When Phase 5b applies (classification is `regeneration-recommended` or `regeneration-required` *and* scaffold files match), the operator saw the in-container update option alongside the project-bundle regeneration option, with the script path and `SUPERAGENTS_REF` override documented.

## Reference

- Authoritative upgrade contract: [`docs/release-versioning-and-upgrade-contract.md`](../../docs/release-versioning-and-upgrade-contract.md)
- Release artifact and pipeline: [`docs/release-process.md`](../../docs/release-process.md), [`docs/schemas/release.schema.json`](../../docs/schemas/release.schema.json)
- Generated layout this skill operates on: [`docs/generated-skill-layout.md`](../../docs/generated-skill-layout.md)
- The skill-builder this skill hands off to in Phase 5: [`skills/skill-builder/SKILL.md`](../skill-builder/SKILL.md)
- Companion devcontainer skill referenced from Phase 6 and Phase 5b's "Update Without Rebuild" section: [`skills/superagents-devcontainer/SKILL.md`](../superagents-devcontainer/SKILL.md)
- Manifest validation harness used in Phase 5 verification: [`tests/test-manifest-upgrade-metadata.sh`](../../tests/test-manifest-upgrade-metadata.sh)
- Issue templates Phase 7 maps onto: [`.github/ISSUE_TEMPLATE/`](../../.github/ISSUE_TEMPLATE/)
- Issue body convention Phase 7's programmatic path follows: closed issues #126 and #135 (`## Context` / `## Goal` / `## Acceptance Criteria` / `## Dependencies` / `## Out of scope`)
- In-container update script invoked by Phase 5b: [`skills/devcontainer-bootstrap/templates/upgrade-superagents-in-container.sh`](../devcontainer-bootstrap/templates/upgrade-superagents-in-container.sh) (shipped to `<project>/.devcontainer/upgrade-superagents-in-container.sh` by `scaffold-devcontainer.sh`)
- Scaffold-guard test for the in-container update path: [`tests/test-in-container-upgrade-guard.sh`](../../tests/test-in-container-upgrade-guard.sh)

## Open Questions

These are surfaced for the operator and for follow-up work; they are not blocking.

- **Promote Phase 1.1 resolution order into the contract.** The installed `release.json` is canonical when present; the other three steps (bundle frontmatter, host-checkout `git describe`, literal `unknown`) are backward-compatibility fallbacks for installs that predate the release pipeline. `docs/release-versioning-and-upgrade-contract.md` does not yet record this ordering — it should, so other consumers can rely on the same resolution.
- **Builder hand-off contract for Phase 5 and Phase 2.3.** Phase 2.3's manual-edit detection is best-effort heuristic and Phase 5's hand-off regenerates the whole bundle, because the installed `superagents-skill-builder` does not yet promise three behaviors this skill would benefit from: (1) deterministic re-run from `fragments.lock.yaml` plus `decisions.yaml` without re-prompting, (2) a `--dry-run` mode that emits the would-be output without writing files, (3) a `--scope` / `--change-ids` mode that regenerates only a subset of skills. Adding those behaviors to `skills/skill-builder/SKILL.md` is a follow-up; until then, this skill stays on the whole-bundle-regenerate path and on heuristic manual-edit detection. See `skills/skill-builder/SKILL.md` Phase 4 for the current contract.
- **Dedicated issue templates for the non-template improvement types.** Today only `agent` and `bug` map onto a `.github/ISSUE_TEMPLATE/*.yml` file; the other five types (`fragment`, `builder-behavior`, `devcontainer`, `docs`, `other`) render their bodies programmatically per Phase 7.4. Adding dedicated `fragment-request.yml`, `builder-behavior.yml`, `devcontainer-issue.yml`, or `docs-improvement.yml` templates would let `gh issue create --template` enforce the form server-side. Track this as a follow-up rather than expanding the template set inside this PR.
