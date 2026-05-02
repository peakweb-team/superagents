---
name: superagents-cleanup
description: Inventory and safely scrub leftover branches, worktrees, and remote refs that accumulate from issue-driven Superagents work. Classifies each item against PR state, runs read-only by default, and never deletes the active branch, `main`, or branches with open PRs without explicit per-item confirmation.
disable-model-invocation: false
argument-hint: "[--apply] [--include-remote] [--include-locked]"
---

# Superagents Cleanup

Use this skill when leftover `codex/issue-*` branches, prunable worktrees, locked agent worktrees from batch orchestration, or merged remote branches have piled up and the operator wants to scrub them.

This skill is **interactive and read-only by default**. It prints a plan; it does not delete anything until the operator passes `--apply` and confirms each category at the prompt. Destructive operations (locked worktree teardown, remote branch delete) are gated behind their own dedicated confirmations.

## Inputs

- `--apply` — execute approved deletions. Without this flag the skill stops at the end of Phase 3 (Plan) with a dry-run summary.
- `--include-remote` — opt in to remote-branch classification and (with `--apply`) deletion of merged `codex/*` branches on origin. Off by default because remote deletion is the most destructive surface.
- `--include-locked` — opt in to teardown of locked agent worktrees under `.claude/worktrees/agent-*`. Off by default because these may carry uncommitted work from batch orchestration.

Environment overrides:

- `SUPERAGENTS_CLEANUP_REPO` — `owner/repo` slug used when querying PR state. Defaults to the repo's `origin` remote, falling back to `peakweb-team/superagents`.
- `SUPERAGENTS_CLEANUP_PROTECT` — comma-separated branch names to add to the protected list on top of the built-in defaults (`main`, the currently checked-out branch, anything matching `release/*`).

## When To Use

Invoke this skill when any of the following is true:

- `git branch | wc -l` is well above the count of open issues you are actively working on
- `git worktree list` shows entries marked `prunable` whose host paths no longer exist
- `.claude/worktrees/agent-*` directories exist for batches that have already shipped
- `git branch -r` shows merged `codex/issue-*` branches that the GitHub UI has not auto-deleted

Do **not** invoke this skill in the middle of an active issue's work — it operates on the assumption that anything on `main` or with an open PR is load-bearing, but reasonable people disagree about edge cases. Run it between tasks.

## Phase Map

| Phase | Name | Default behavior |
|-------|------|------------------|
| 1 | Discover | Read-only inventory |
| 2 | Classify | Read-only PR / worktree state lookup |
| 3 | Plan | Print grouped plan, prompt per category |
| 4 | Apply | Delete only with `--apply` and per-category confirmation |

The skill always runs phases 1–3. Phase 4 runs only when `--apply` is passed.

## Phase 1 — Discover

Inventory three surfaces. Each comparison feeds Phase 2.

### 1.1 Local branches

```bash
git for-each-ref --format='%(refname:short) %(upstream:short) %(objectname:short)' refs/heads/
```

Capture every local branch, its tracked upstream (if any), and its tip SHA. Always exclude:

- `main`
- the currently checked-out branch (`git symbolic-ref --short HEAD`)
- anything matching `release/*`
- anything in `SUPERAGENTS_CLEANUP_PROTECT`

The exclusion list is fixed before classification begins; nothing in the protected set is ever a candidate for deletion.

### 1.2 Worktrees

```bash
git worktree list --porcelain
```

Parse the porcelain output into three buckets:

| Bucket | Signal |
|---|---|
| `active` | Worktree path exists and is not the main worktree |
| `prunable` | Porcelain emits `prunable` |
| `locked` | Porcelain emits `locked` |

For locked worktrees, additionally record the lock reason (the `locked` line's optional payload).

### 1.3 Remote branches (only when `--include-remote`)

```bash
git ls-remote --heads origin 'codex/*'
```

Capture every `codex/*` remote branch and its tip SHA. Skip this entirely when `--include-remote` is not passed — remote queries are the slowest part of discovery and the destructive part of Phase 4.

### 1.4 Stale agent-worktree directories

```bash
find .claude/worktrees -maxdepth 1 -type d -name 'agent-*'
```

Cross-reference against the porcelain output from 1.2: a directory under `.claude/worktrees/agent-*` that does not appear in `git worktree list` is an orphan filesystem leftover (the worktree admin entry was already pruned). Record orphans separately from locked worktrees — they cannot be removed via `git worktree remove` and need `rm -rf` instead.

## Phase 2 — Classify

For each candidate, compute its disposition.

### 2.1 Branch → PR state

For every non-protected local branch and (when `--include-remote`) every remote `codex/*` branch:

```bash
gh pr list --repo "$SUPERAGENTS_CLEANUP_REPO" --head "<branch>" --state all --json number,state,mergedAt,closedAt --limit 1
```

Map the result to one of four labels:

| `gh` result | Label | Default disposition |
|---|---|---|
| `state: MERGED` | `merged` | delete |
| `state: CLOSED` (not merged) | `closed` | prompt — operator may want to keep work |
| `state: OPEN` | `open` | keep (skip with a note) |
| empty array | `no-pr` | prompt — could be in-flight or abandoned |

`merged` is the only label that auto-defaults to delete. Everything else requires an explicit operator decision.

Resolve `SUPERAGENTS_CLEANUP_REPO` in this order:

1. The env var, if set
2. `gh repo view --json nameWithOwner -q .nameWithOwner` against the current remote
3. The literal `peakweb-team/superagents`

### 2.2 Worktree → action

| Bucket | Default action |
|---|---|
| `prunable` | `git worktree prune` (single command, removes all prunable entries) |
| `locked` (only when `--include-locked`) | unlock + `git worktree remove --force` after explicit confirmation |
| `locked` (without `--include-locked`) | report only — do not offer to remove |
| `active` | keep |
| `orphan` directory | `rm -rf` after explicit confirmation, plus `git worktree prune` to clean any dangling admin entry |

## Phase 3 — Plan

Print a single grouped summary. Group by surface and label so the operator can approve or reject categories rather than items one-by-one.

```text
Cleanup plan (DRY RUN — pass --apply to execute)

Local branches (<N> protected, <M> candidates):
  merged  (<count>):  <branch>, <branch>, ...
  closed  (<count>):  <branch>, <branch>, ...
  open    (<count>):  <branch>, ...                    [will keep]
  no-pr   (<count>):  <branch>, ...

Worktrees:
  prunable (<count>): <path>, <path>, ...
  locked   (<count>): <path> (reason: <reason>), ...    [skipped — pass --include-locked]
  orphan   (<count>): <path>, <path>, ...

Remote codex/* branches (<count>):                      [skipped — pass --include-remote]

Currently checked-out branch: <branch>                  [protected]
```

Emit one count per label even when zero, so the operator can confirm the surface was checked. After the summary, print a one-line next-step:

- Without `--apply`: `Re-run with --apply to execute. Add --include-remote and --include-locked to widen scope.`
- With `--apply`: prompt for per-category approval (Phase 4).

## Phase 4 — Apply

Runs only when `--apply` is passed. Process categories in the order below — least destructive first.

### 4.1 Per-category confirmation prompt

For each non-empty category, prompt:

```text
Delete <N> <category> item(s)? [y/N]
```

A `N` (or no answer) skips the category. Categories are independent — declining one does not affect the others.

For `closed` and `no-pr` branches, drop into a per-item prompt instead of a category-level one. These labels do not have a safe auto-default, so the operator confirms each branch individually.

### 4.2 Execution order

1. **Prune `prunable` worktrees** — `git worktree prune -v`. This is reversible only by re-creating the worktree, but no data is lost (the working trees were already gone).
2. **Delete `merged` local branches** — `git branch -d <branch>`. Use `-d` (safe), not `-D`. If a branch fails the merge check, surface it and skip — do not silently force-delete.
3. **Delete `closed` and `no-pr` local branches that the operator approved** — `git branch -D <branch>` (force, because these may not be merged into `main`).
4. **Locked worktrees (only when `--include-locked` and operator approved)** — for each: `git worktree unlock <path>` then `git worktree remove --force <path>`. Print the lock reason before the per-item confirmation.
5. **Orphan agent-worktree directories** — `rm -rf <path>` followed by `git worktree prune -v`. Confirm per item.
6. **Remote `codex/*` branches (only when `--include-remote` and operator approved)** — `git push origin --delete <branch>`. Batch into one `git push` per ten branches to keep the output readable. This is the most destructive step; print a final "Proceed with remote deletion of N branch(es)? [y/N]" gate immediately before pushing, even after the per-category prompt approved it.

### 4.3 Final summary

After Phase 4 completes, print a final summary listing every item deleted, every item skipped, and every item that errored. Format:

```text
Cleanup complete.

Deleted:
  local branches: <count>  (<list>)
  worktrees:      <count>  (<list>)
  orphan dirs:    <count>  (<list>)
  remote refs:    <count>  (<list>)

Skipped:
  protected:      <count>
  open PR:        <count>
  declined:       <count>

Errors:
  <path or branch>: <stderr from git, one line>
```

When dry-run (no `--apply`), print the same summary but with the header "Cleanup plan (DRY RUN)" and zeros under "Deleted".

## Safety Rules (do not violate)

- **Never delete `main` or the active branch.** These are excluded at Phase 1 and re-checked immediately before each `git branch -d`.
- **Never `git branch -D` a `merged`-labeled branch.** If `-d` refuses it, the merge state is wrong — stop and surface the discrepancy rather than forcing.
- **Never delete a branch with an open PR.** `gh pr list --state OPEN` is the source of truth, not local merge state.
- **Locked worktrees are skipped without `--include-locked`.** The lock is the operator's signal that the worktree carries state worth preserving (active batch run, in-progress agent work). Do not unlock silently.
- **Remote deletion never bundles with local deletion.** Even with `--apply --include-remote`, remote `codex/*` deletes get their own final-gate prompt.
- **No `git push --force` and no `git reset --hard`.** This skill only deletes refs and removes worktree files; it never rewrites history.

## Error Handling

- **`gh` not authenticated** — Phase 2.1 cannot classify branches. Stop with a clear message ("`gh auth login` against a token with `repo` scope") and do not fall back to a heuristic. Misclassifying a branch as merged is the worst-case failure of this skill.
- **`gh` rate-limited** — surface the retry-after window and stop. Re-running later is safe (Phase 1 is read-only and Phase 2 is idempotent).
- **`git worktree remove` fails** — typically because the working tree has uncommitted changes. Surface the path, the stderr, and continue with the next item. Do not retry with `--force` automatically.
- **Branch deletion fails on `-d`** — record under "errors" and continue. Do not auto-escalate to `-D`.
- **Remote push rejected** — surface the rejection (likely a branch protection rule on `origin`), record under "errors", and continue with the next branch.

## Stopping Conditions

The skill stops cleanly (without applying changes) when:

- The operator declines every category at the Phase 4 prompts.
- Phase 1 finds nothing to clean (no candidate branches, no prunable or locked worktrees, no orphan dirs, and — when `--include-remote` — no merged remote branches).
- `--apply` was not passed (the skill always stops after Phase 3 in dry-run mode).

The skill stops with an error when:

- `git` is not on `PATH` or the working directory is not a git repository.
- `gh` is required (any branch classification or `--include-remote`) and is missing or unauthenticated.

## Success Criteria

- Discovery enumerated every local branch, every worktree, every orphan `agent-*` directory, and (when opted in) every remote `codex/*` branch.
- Classification labeled every branch as `merged | closed | open | no-pr` against `gh pr list`, never against a local heuristic.
- The plan summary printed counts per label and named protected branches explicitly.
- In dry-run mode, no filesystem changes occurred and no refs moved.
- In apply mode, `main` and the active branch are still present after the run, every deletion appears in the final summary, and every error is surfaced (not swallowed).
- Locked worktrees were left alone unless `--include-locked` was passed *and* the operator approved each one.
- Remote branch deletions, if any, passed through both the per-category prompt and the final remote-deletion gate.

## Reference

- Worktree porcelain format: `git worktree list --porcelain` documented in `git-worktree(1)`
- PR state lookup: `gh pr list` documented at https://cli.github.com/manual/gh_pr_list
- Companion skill that creates the worktrees this skill cleans up: the `superagents-workflow` skill (dogfooded copy lives at `.claude/skills/superagents-workflow/SKILL.md`; this skill source tree does not yet ship a canonical `skills/superagents-workflow/`)
- Companion skill for refreshing the in-container `~/.claude/` install (a different surface than the repo this skill operates on): [`skills/superagents-upgrade/SKILL.md`](../superagents-upgrade/SKILL.md)

## Open Questions

These are surfaced for follow-up; they are not blocking.

- **Auto-detection of "stale" no-pr branches.** Today `no-pr` branches drop into a per-item prompt. A future iteration could classify by branch age (last commit older than N days) and offer a single category-level approval for the obviously-abandoned subset.
- **Integration with `superagents-workflow` cleanup hooks.** When the workflow skill closes out a PR, it could append the merged branch name to a queue this skill consumes. That would let cleanup run as a single category-level approval rather than re-querying `gh` for every branch.
- **Worktree-creation policy alignment.** Issue-driven worktrees currently land in two distinct locations (`/Users/<user>/gitRepos/superagents-issue-*` on the host, `.claude/worktrees/agent-*` for batch agents). This skill cleans both, but the workflow skill's `auto` strategy should probably consolidate on a single in-repo location to make cleanup unambiguous.
