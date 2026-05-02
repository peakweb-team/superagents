# Skill Builder Review — superagents

**Generated**: 2026-04-30
**Previous build**: 2026-04-27
**Runtime target**: `claude-code`
**Framework release**: v0.x

## What Was Generated

One primary skill: `superagents-workflow`

Location: `.claude/skills/superagents-workflow/SKILL.md`

> Note: Skill lives at `.claude/skills/superagents-workflow/` (not the builder-contract root `.claude/skills/superagents/superagents-workflow/`) to align with Claude Code runtime discovery. This was normalized in issue #135.

## What Changed Since Last Build (2026-04-27)

| Change | Detail |
|---|---|
| Fragment added | `runtime/devcontainer-management` — `.devcontainer/` directory newly detected as a direct signal |
| Signal added | `repo.devcontainer` added to `inventory.yaml` |
| Manifest path corrected | Updated from stale `.claude/skills/superagents/superagents-workflow/` to actual location |
| fragment_count | 4 → 5 |

## Decisions Summary

| Decision | Value | State |
|---|---|---|
| Runtime target | `claude-code` | confirmed |
| Work intake mode | `github-issues` only | confirmed |
| Primary task tracker | GitHub Issues | confirmed |
| Review layer | CodeRabbit + human | confirmed |
| Worktree strategy | `auto` | confirmed |
| Per-task worktree override | `true` | assumed |
| Team sizing default | `solo` | confirmed |
| Runtime context budget | `medium` | assumed |

## Fragments Selected

| Fragment | Reason |
|---|---|
| `project-management/github-issues` | Confirmed sole tracker; branch naming corroborates |
| `orchestration/team-sizing` | Solo default with escalation heuristics; CI gates require validation phase |
| `delivery/pull-request-review` | PR template + CodeRabbit + human approval path |
| `runtime/context-and-model-routing` | Large agent/doc surface warrants bounded context expansion |
| `runtime/devcontainer-management` | `.devcontainer/` directory present; rebuild/stop/package guidance needed |

## Fragments Suppressed

| Fragment | Reason |
|---|---|
| `task-intake/direct-brief` | Issues-only intake confirmed |
| `task-intake/portfolio-spec-decomposition` | No batch planning requirement |
| `project-management/github-projects` | Per-repo issue workflow confirmed; conflicts with github-issues fragment |
| `project-management/jira` | No Jira signals |
| `delivery/cross-repo-pr-bundle` | Single-repo delivery confirmed |

## Orchestration Tier

**Solo.** Most work in this repo (agent additions, doc updates, CI fixes, fragment additions) is single-domain and benefits from one coherent Claude Code session rather than specialist handoffs.

Escalate to sub-agent team when work spans more than two distinct domain areas simultaneously.

## Devcontainer Fragment Note

The `runtime/devcontainer-management` fragment delegates command details to the installed user-level `superagents-devcontainer-bootstrap` skill. The primary skill now carries rebuild/stop/package lifecycle guidance inline and references that skill for execution. No companion skill is generated — the user-level skill is sufficient.

## CodeRabbit Note

No `.coderabbit.yaml` was found locally — CodeRabbit is configured at the GitHub organization/repo level. The generated skill correctly treats CR as active and sequences review: wait for CodeRabbit summary → address CR comments → request human approval.

## Worktree Strategy Note

`auto` is appropriate given the active parallel branch pattern (`codex/issue-NNN-*` across 10+ branches). The skill surfaces remediation steps for ambiguous states rather than proceeding silently.

## Items To Review Manually

1. **Devcontainer rebuild trigger** — the skill proactively suggests a rebuild on `devcontainer.json`, `Dockerfile`, or `post-create-superagents.sh` changes. Adjust if you want a narrower trigger set.
2. **Branch slug format** — the skill generates `codex/issue-<N>-<slug>`. Verify this matches your naming convention.
3. **Pre-PR commands** — the skill lists validation commands per change type. Confirm the set is current.
4. **CodeRabbit sequencing** — if you prefer CR and human review in parallel, edit the PR review section.
5. **Per-task override policy** — `worktree_allow_task_override: true` was assumed. Update `decisions.yaml` and remove the override paragraph from `SKILL.md` to enforce a strict policy.

## Assumed Decisions

- `worktree_allow_task_override: true` — standard safe default; change in `decisions.yaml` if strict policy needed.
- `runtime_context_budget: medium` — assumed from repo shape; revisit if context exhaustion occurs in practice.

## Next Fragments To Consider

- `delivery/cross-repo-pr-bundle` — if work begins requiring coordinated PRs to downstream consumer repos
- `task-intake/portfolio-spec-decomposition` — if batch planning runs (sprint kickoffs) become a regular pattern

## Runtime Mode

Small-task / medium-context. Execution should follow `discover → select → deepen → execute → verify`. No stage skips expected for typical issue work.
