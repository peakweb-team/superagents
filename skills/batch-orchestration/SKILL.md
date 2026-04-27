---
name: superagents-batch-orchestration
description: Behavioral patterns for orchestrating multi-PR batch delivery runs — CR rate-limit handling, sibling conflict resolution, chained-PR retargeting, pre-merge follow-up filing, comment attribution, operator-paired issue filing, specialist dispatch, and anti-idle discipline.
disable-model-invocation: false
argument-hint: "[brief | batch-run-context]"
---

# Superagents Batch Orchestration

These patterns apply whenever the orchestrator is running a **batch delivery** — working through multiple PRs or issues in the same session. They complement the primary workflow skill and take precedence over generic guidance when batch conditions exist.

## 1. Batch Orchestration — Multiple-PR Runs

### CodeRabbit Rate-Limit (Per-PR)

CodeRabbit imposes a per-hour review-request limit that is easy to hit when several commits land on a single PR in quick succession. When CR replies with a `Rate limit exceeded` summary:

- **Do not idle.** Move on to the next PR's CR loop, the next implementation, or any other work that does not depend on the rate-limited PR.
- **Do not keep poking.** Do not request another review until the operator-supplied wait period has passed. A spammed re-review request can lengthen the cooldown.
- **Track the cooldown** with a single timed background poll (`until <CR review check>; do sleep 30; done`) — and resume the loop only after the poll fires.
- **Note in the PR body.** If a rate-limit window stalls a PR for more than a few minutes, add a comment so the operator knows the delay is not a code issue.

### PR Merge → Sibling Conflicts

In a batch where N PRs branch off the same `main`, the moment the operator merges the first one every other PR is potentially in conflict — typically on shared files like `package.json`, `package-lock.json`, `.gitignore`, root config, or any shared component the issues happened to touch.

When a sibling PR flips to `mergeable: CONFLICTING`:

1. `git fetch origin main` in that PR's worktree.
2. `git merge origin/main` (not rebase — preserves the CR review history with stable commit SHAs reviewers have already seen).
3. Resolve conflicts in-place. Keep both sides whenever the intent is additive (new npm script + new npm script, new CSS rule + new CSS rule). Only one side wins when the change is genuinely contradictory.
4. After resolving `package.json`, regenerate the lockfile via `NPM_CONFIG_CACHE=/tmp/.npm-cache npm install --package-lock-only --no-audit --no-fund`. **Do not** hand-edit the lockfile.
5. Re-run typecheck + lint before pushing the merge commit. The merge commit can introduce unexpected breakage even if the textual resolution looked clean.
6. **Cascade through chained PRs.** If PR A is `--base main` and PR B is `--base feat/A`, then merging `main` into A also requires merging the updated A into B. Do this as a follow-up step in the same pass, not later.

## 2. Chained-PR Retargeting at Main

When you open PR B with `--base feat/A` so it reviews cleanly against the unmerged dependency, you take on a tracking obligation: the moment PR A merges into `main`, you must **retarget PR B at `main` before the operator merges B**, otherwise B's content will land on the now-orphaned `feat/A` branch instead of `main`.

Procedure:

1. Track every chained PR you open. The signal is `gh pr view <#> --json baseRefName --jq .baseRefName` returning anything other than `main`.
2. After **any** merge to `main`, sweep your tracked chained PRs. For each one whose base was just merged:
   - `gh pr edit <#> --base main` to retarget. GitHub re-evaluates the diff automatically.
   - If the retarget produces conflicts (because the chained branch hasn't picked up `main` yet), resolve via `git merge origin/main` in the chained worktree first, push, **then** retarget. Do not retarget into a conflict state.
   - Post a one-line PR comment: "Retargeted at `main` after #<base-PR> merged." So the reviewer sees the change is intentional.
3. If the operator already merged the chained PR into the now-orphaned base branch before you got there, **the content is not on `main`**. Recover by opening a fresh PR `<chained-branch> → main` (the chained branch already contains the previous merge of its base, so the diff against `main` is exactly the chained work). Title and body should explicitly say "recovery PR — content stranded on `<orphaned-branch>` after out-of-order merges; opening fresh against `main`."

**Auto-close caveat — chained PRs don't close their issues.** GitHub's `Closes #N` keyword only fires when the PR merges into the repository's default branch directly. A chained PR that merges into `feat/A` does **not** trigger the auto-close, even though the work eventually reaches `main` via a later merge of `feat/A`. Add to the post-merge cleanup pass: for every chained PR whose work has now reached `main`, manually close the linked issue with a status comment noting the merged PR and confirming the work is on `main`. Update the project board status in the same step.

## 3. Pre-Merge Follow-Up Filing

Before the PR merges (and ideally before requesting human review), audit your own delivery for deferred work and **file the follow-up issues now, while the context is still fresh**. Sources of deferral to sweep:

1. **PR body's "Acceptance criteria" with unchecked boxes** — anything ticked `[ ]` that was not addressed in this PR is a follow-up candidate.
2. **CodeRabbit nitpicks you disputed or deferred** — even when you correctly chose to defer, the operator should see the open thread on the board, not lose it in PR comments.
3. **PR body's "Risk & assumptions" / "Out of scope" sections** — anything described as "follow-up", "deferred", "operator-paired", or "revisit when X" belongs as an issue.
4. **Implementation comments left in the code** — `// TODO(#NNN)` referencing a not-yet-existing issue means "I haven't filed it yet."

For each: file a new issue with title, context (link back to the parent PR + issue), goal, AC, and dependencies. After filing, leave a single PR comment listing the new issue numbers and a one-line description of each, so the operator can scan-and-merge with confidence the work is not lost.

Why this happens before merge, not after: the operator is the merge gate. If they merge thinking the AC is fully covered when in fact three things were deferred, those things vanish into PR archaeology. Filing the issues first lets the operator see exactly what they are accepting.

## 4. CodeRabbit Thread Reply Discipline

Every CodeRabbit comment gets a reply. Code + commit alone is not enough — a human reviewer reading the PR top-to-bottom needs to see, on each CR thread, what happened.

For every CR comment in the latest pass, post a reply that says one of:

- `Addressed in <sha> — <one-line description>`
- `Disputed — <rationale, ideally with a citation to the issue spec or a project convention>`
- `Deferred to #<follow-up issue> — <one-line reason>`

A single roll-up comment on the PR ("addressed N nits in `<sha>`, deferred X, disputed Y") is the minimum acceptable form when there are many trivial nits; per-thread replies are the default.

The reason the status comment is non-negotiable: CodeRabbit threads stay open and visible to the operator long after the diff that caused them is merged into history. If you push a fix and stay silent, the human reviewing the PR later sees an open CR thread with no resolution and has to dig through commits to figure out whether it was addressed, disputed, or forgotten. The comment is the durable record; the commit is the implementation.

## 5. Agent-Comment Attribution Tagging

When you post a comment via `gh pr comment`, `gh api .../comments`, or `gh api .../comments/<id>/replies`, GitHub authors it as the user owning the `GH_TOKEN` — typically the operator. Those comments look indistinguishable from the operator's own real feedback, which leads to confusion ("did I write this?") and to comments being read as user direction when they are actually orchestrator commentary.

Tag every comment you post on the operator's behalf with an explicit prefix on the first line:

```
> 🤖 _Posted by the orchestrator on behalf of @<operator-login> via `<skill-name>`._

<actual comment body>
```

The blockquoted line keeps the actual content readable while making attribution unambiguous. Apply this to:

- Roll-up status comments on a PR ("addressed N nits in `<sha>`...")
- Per-thread CR replies ("Addressed in `<sha>` ...", "Disputed ...", "Deferred to #N ...")
- Recovery / explanatory comments (chained-PR retargeting notes, conflict-resolution explanations, follow-up roll-ups before merge)

Do **not** apply this prefix to the PR body itself (the body is owned by the orchestrator-as-author by default; tagging it is redundant). Apply it only to comments and review replies.

When you see an existing PR comment authored by the operator's login, **never** assume the operator wrote it — check whether you (or a previous orchestrator run) authored it via the token. Search your own session history first; if a comment matches something the orchestrator would have posted (status updates, dispute language, "addressed in `<sha>`" patterns), treat it as orchestrator-authored even if GitHub attributes it to the human.

## 6. Operator-Paired Work as Separate Issues

When a PR ships code whose acceptance criteria include steps the orchestrator cannot perform autonomously — provisioning a managed-cloud resource, setting environment variables in a SaaS dashboard, running a one-shot seed against production data, configuring an external OAuth client, etc. — **file those operator-only steps as their own `chore:` follow-up issue** rather than burying them in the PR body's "operator runbook" section.

The PR body still describes what the operator needs to do (so the reviewer of the PR sees the full picture before merge), but the canonical tracker is a separate issue with its own AC checklist that the operator works through after the PR merges. This matters because:

- A PR body's checklist gets archived once the PR merges. The operator who comes back later to complete the manual step wants a live, open issue with checkboxes — not a closed PR's body.
- The operator-only work is genuinely independent of the code-side delivery; the code can ship green even if the manual provisioning has not started yet. Conflating them in one work item makes the project board lie about which work is done.
- It surfaces operator-side risk early. When the orchestrator files multiple "operator: do X" issues alongside one feature PR, the operator sees the real scope of "shipped" and can sequence the manual work explicitly rather than discovering it post-merge.

Each follow-up issue has full standalone AC; the parent PR's body links to it inline so a reviewer can scan-and-merge with confidence the operator-side work is preserved on the board.

## 7. Specialist-Team-Per-Input Dispatch

When a task decomposes into N independent inputs and **each input consumes meaningful context** (a multi-MB PDF read, a multi-thousand-line repo walk, etc.), do **not** run the work in the orchestrator's session. Dispatch one specialist team member per input, in parallel where possible, each with its own context window.

Why this is the right shape:

- The orchestrator's context stays clean. The orchestrator only sees each team member's final report. The actual heavy reading happens in disposable sub-contexts.
- Independent inputs run in parallel — total wall-time is bounded by the slowest input, not the sum of all of them.
- Each team member can be a specialist persona suited to the work. The persona choice is part of the dispatch contract.

Invocation pattern:

1. Read or generate a manifest with one record per input (`name`, `sha256`, output target, `status`).
2. Orchestrator reads the manifest, identifies pending records, and dispatches one specialist team member per pending record. Each dispatch is scoped narrowly: "you are responsible for exactly this record; here is its name, its hash, the output path, and the skill that documents the work contract."
3. Each team member invokes the relevant skill, reads the assigned input, produces the artifact, returns a concise success report.
4. Orchestrator re-runs any validation utility, confirms the manifest flips the relevant records to `up-to-date`, and pings the operator for any human-in-the-loop close gate.

What this is **not**:

- It is not "spawn a generic agent for every input." The persona matters.
- It is not free. Each dispatch consumes its own context budget. Use it when the inputs are independent and individually expensive; do not use it when the work is sequentially dependent or when the per-input cost is trivial.
- It does not replace skills — it complements them. The skill documents the work contract once; the team-member dispatch executes that contract once per input.

When a team member hits an environment-side limit during dispatch (Read tool refusing an oversized file, an image too large for an upload SDK), the team member must **report and stop**, not silently produce a partial artifact. The orchestrator then either splits the input and re-dispatches per chunk, or surfaces the block to the operator for external pre-processing.

## 8. Don't Idle — Push Until Truly Blocked

When the orchestrator's nominal state is "waiting" — for a sub-agent to finish, for CodeRabbit to review, for CR's rate-limit window to clear, for a Vercel preview to deploy, for an operator merge — there is almost always *some* useful work that advances the project's goals. Idling is the failure mode to avoid; setting a timer to check back in is the floor, not the ceiling.

Concrete behavior, in order of preference:

1. **Add new foreground work that won't conflict with what's in flight.** Open the next groomed issue's worktree (different files than the in-flight PR almost certainly). Read a backlog issue and surface what blocks it. File a follow-up issue noticed during the last review pass but not yet written. Sweep the open-PR list for ones whose CR went silent because of a skipped review and ping `@coderabbitai review` on each.

2. **Sweep the in-flight queue when you can't add new work.** For every running sub-agent: confirm it's still alive. For every open PR: re-read the latest CR check status, address any new feedback per the per-thread reply discipline. For every chained PR: confirm its base hasn't merged out from under it (auto-retarget per the chained-PR rule) and confirm its issue auto-closed if its chain has now reached `main` (close manually if not).

3. **Take initiative on technical hurdles a specialist persona can solve.** If a sub-agent's report exposes a tractable problem — a flaky test, an a11y issue, a perf regression, an observability gap — dispatch the specialist rather than waiting for the operator to triage. The operator wakes up to a closed loop, not an open question.

4. **Only set a timer when there is genuinely nothing else to do.** "Genuinely nothing" means: no new work to advance, no in-flight queue to sweep, no specialist dispatch to make, no follow-up issue to file. Then set a check-back timer sized to whatever you're waiting on — CR rate-limits clear in ~2 minutes, preview builds take ~30–60 seconds, a sub-agent on a large input can take 5+ minutes.

5. **Push until you are truly blocked AND the operator is offline.** "Truly blocked" means: every in-flight thing is in a state only the operator can move forward — merge a PR, set an env var, provision a cloud resource, supply a missing source file, sign off on a manual review. *And* the operator is not actively driving from the other side. Only then do you stop pushing and wait.

Why this is non-negotiable: every minute the orchestrator sits idle while project goals are incomplete is a minute the operator's parallel productivity is wasted. The operator's leverage scales with how much closed-loop progress they walk back to.
