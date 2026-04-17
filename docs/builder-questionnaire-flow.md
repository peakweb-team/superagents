# Builder Questionnaire And Unresolved-Decision Flow

This document defines the proposed contract for issue `#15`:

- [#15 Define builder questionnaire and unresolved-decision flow](https://github.com/peakweb-team/pw-agency-agents/issues/15)

It builds on:

- the Claude-first MVP stance from issue `#29`
- the fragment schema from issue `#11`
- the builder inventory and confidence model from issue `#14`
- the fragment assembly contract from issue `#16`
- the generated-skill layout contract from issue `#12`
- the external capability model from issue `#13`
- the orchestration tiering rubric in [`docs/orchestration-execution-rubric.md`](./orchestration-execution-rubric.md)
- the role and handoff contract in [`docs/orchestration-role-handoff-contract.md`](./orchestration-role-handoff-contract.md)
- the runtime context-budgeting and repo-reading contract in [`docs/runtime-context-budgeting-and-repo-reading.md`](./runtime-context-budgeting-and-repo-reading.md)
- the project integration declaration format from issue `#18`
- the capability fallback contract from issue `#19`
- the first-wave task-system provider fragment set in [`docs/task-system-provider-fragment-set.md`](./task-system-provider-fragment-set.md)
- the first-wave code-host/review provider fragment set in [`docs/code-host-review-provider-fragment-set.md`](./code-host-review-provider-fragment-set.md)

## Why This Exists

The inventory workflow gives the builder signals and confidence levels.

That is not enough by itself.

The builder still needs a disciplined way to decide:

1. which questions are worth asking
2. which questions should be skipped because the repo already answered them
3. how to record confirmed vs assumed vs unresolved decisions
4. how unresolved decisions should appear in builder output

This document defines the MVP answer so the builder can stay minimal, explicit, and deterministic.

## Goals

- define the smallest useful questionnaire for MVP
- prioritize only the questions that materially change fragment selection or generated-skill behavior
- define when a question should be skipped
- define the builder decision states
- define how unresolved decisions are recorded in output
- resolve workflow choices that materially change which capability families the generated skill should rely on
- surface when degraded integrations should continue, warn, switch to manual mode, or fail

## Non-Goals

- creating a long setup interview
- asking the user about facts already visible in the repo
- replacing repository inspection with questionnaires
- redefining the fragment assembly engine

## Core Principle

The builder should ask the minimum number of questions required to avoid misleading workflow instructions.

That means:

- inspect first
- infer second
- ask third
- record uncertainty explicitly

That recorded uncertainty should appear in the builder metadata bundle and review handoff defined in [`docs/generated-skill-layout.md`](./generated-skill-layout.md).

It should also be reflected in provider and capability mapping state inside [`docs/project-integration-declaration-format.md`](./project-integration-declaration-format.md).

In a Claude-first MVP, the builder should prefer safe defaults when the impact is low, but it should not guess silently on high-impact workflow choices.

## Decision States

Every builder decision should end in one of four states:

- `confirmed`
- `assumed`
- `unresolved`
- `not-applicable`

### `confirmed`

Use `confirmed` when either:

- repository evidence is strong enough to support a high-confidence automatic choice, or
- the user explicitly answers the questionnaire

Examples:

- GitHub Issues is selected because direct repo evidence makes it clearly primary
- the user confirms that direct-brief bootstrap should remain available even without an authoritative tracker
- the user confirms that CodeRabbit is part of the review loop
- the user confirms that tracked-task updates are required even though direct briefs remain allowed
- the user confirms that a missing task-tracker update path should be treated as manual mode rather than a blocker

### `assumed`

Use `assumed` when:

- the builder has a plausible default
- the decision is below full certainty
- the cost of being wrong is limited enough to proceed for MVP

Examples:

- assume human PR review when PR flow is clear but no review automation is detected
- assume solo-by-default execution in a small repo with no strong multi-agent evidence

An assumed decision must always include:

- the assumption text
- the supporting evidence
- the reason it was not escalated to a question

Assumed decisions must also be written into the generated review artifacts so a reviewer can see why the builder proceeded.

### `unresolved`

Use `unresolved` when:

- the decision materially affects fragment selection or generated behavior
- the builder lacks enough confidence to confirm a choice
- no safe assumption is appropriate

Examples:

- both GitHub Issues and Jira appear active, but primary authority is unclear
- the repository shows no authoritative tracker, but it is unclear whether the generated skill should be direct-brief-first or tracker-optional
- review automation is referenced, but it is unclear whether it is required or legacy
- the project clearly needs PR delivery, but it is unclear whether hosted delivery-status signals are required for completion
- the project may proceed without automated ticket updates, but it is unclear whether that should warn, require manual completion steps, or block the workflow

An unresolved decision should usually create a follow-up question.

If the builder still ends with an unresolved decision after the questionnaire phase, it should surface that clearly in `decisions.yaml` and `review.md` rather than burying it inside the generated skill text.

Those unresolved decisions should also block exclusive-fragment resolution when the assembly rules in [`docs/fragment-assembly-rules.md`](./fragment-assembly-rules.md) would otherwise force a misleading winner.

### `not-applicable`

Use `not-applicable` when the decision does not matter for this repository or builder run.

Examples:

- branch naming preference for a repo that is not using branch-based delivery guidance in v1
- model-budget questions for a tiny repository where runtime-routing guidance is not selected

## Questionnaire Priorities

The builder should ask questions in priority order, not all at once.

The initial MVP questionnaire should focus on the smallest set of decisions that most strongly affect fragment selection.

### Priority 1: Work Intake Mode

Question goal:

- determine whether generated skills should start from a tracked task, a direct brief, or support both

Ask when:

- multiple task systems are suggested by the repo
- the repo clearly uses a forge but issue authority is still unclear
- the repo appears greenfield, light-process, or likely to benefit from direct-brief bootstrap
- the intended UX wants a dual entry path such as `/agent-task <ticket-or-prompt>`

Examples:

- Should the generated skill expect work to begin from a tracked task, a direct brief, or both?
- If both GitHub Issues and Jira are used, which one should the builder treat as the source of truth for tracked-task intake?
- Should a greenfield repo support a direct-brief bootstrap mode even if GitHub Issues exists?

### Priority 2: Review Path

Question goal:

- determine how implementation work is reviewed before completion

Ask when:

- PR-based delivery is evident, but the review path is ambiguous
- review automation is mentioned without direct config

Examples:

- Should the builder assume human PR review, CodeRabbit, or a layered review path?
- Is reviewer automation active in this repo, or are reviews human-only?

### Priority 3: Orchestration Default

Question goal:

- determine whether the generated skill should default to `solo`, escalate to `sub-agent` for bounded parallel work, or reserve `agent-team` for richer peer coordination cases
- ensure generated role ownership and handoff behavior follows the canonical local coordination contract

Ask when:

- repository evidence suggests parallel or cross-functional work, but it is unclear whether bounded decomposition is enough or richer peer coordination is required

Examples:

- Should bounded parallel implementation default to `sub-agent` before `agent-team`?
- Are there recurring tasks in this repo where active peer-to-peer coordination materially improves outcomes?

### Priority 4: Worktree Isolation Strategy

Question goal:

- determine whether worktree usage should default to `off`, `manual`, or `auto`
- determine whether per-task override is allowed on top of the repository default

Ask when:

- repository evidence suggests parallel ticket work, but there is no explicit worktree policy
- branch collision risk appears meaningful, but the team may prefer manual control
- existing docs mention branch conventions but do not clarify worktree behavior

Examples:

- Should this repository default to `off`, `manual`, or `auto` worktree strategy?
- Should a task be allowed to override the repository default worktree strategy?
- If `auto` is selected, should deterministic task worktree paths use a sibling root or a custom root?

### Priority 5: Runtime / Budget Constraints

Question goal:

- capture constraints that materially change runtime context-budgeting, repo-reading, and model-routing guidance

These answers should shape runtime behavior using the canonical context-budgeting and repo-reading contract in [`docs/runtime-context-budgeting-and-repo-reading.md`](./runtime-context-budgeting-and-repo-reading.md).

Ask when:

- runtime guidance is likely relevant but budget or model expectations are not inferable

Examples:

- Should the generated skill optimize aggressively for low token/tool cost, or favor stronger reasoning effort by default?
- Are there model, reasoning-effort, or budget constraints the builder should encode in runtime guidance?
- Should this repo default to small-task `narrow` context budgets, or start at large-repo `medium` budgeting with package-mapping first?

### Priority 6: PR And Branching Conventions

Question goal:

- capture naming or flow rules that will shape generated instructions but usually do not block fragment selection

Ask when:

- PR delivery is evident and the repo does not already document branch/PR conventions

Examples:

- Should branch names include ticket keys by default?
- Is there a preferred PR title/body convention the generated skill should follow?

This is lower priority because it usually refines generated output rather than changing the fragment set.

## Question-Avoidance Logic

The builder should skip a question when any of the following is true:

### 1. The Repo Already Answered It With High Confidence

If the inventory workflow marked a decision `high` confidence and no meaningful conflict exists, do not ask.

Example:

- a direct Jira workflow plus repeated Jira ticket references means the builder should not ask whether Jira exists

### 2. The Question Would Not Change Builder Behavior

If different answers would not change fragment selection or meaningful generated behavior, do not ask.

Example:

- asking whether a repo uses PRs is unnecessary if all visible delivery evidence already requires PR-based review behavior

### 3. A Safe Default Exists And The Impact Is Low

If the decision can be safely assumed for MVP and the assumption is explicitly recorded, do not ask.

Example:

- assume human-only review when no direct automation evidence exists

### 4. The Topic Is Better Recorded As Unresolved Than Forced Into An Immediate Answer

If the answer is optional for MVP and would create a noisy questionnaire, record it as unresolved or not-applicable instead of asking.

Example:

- a future optimization preference that does not affect the initial fragment set

## Ask / Assume / Skip Decision Rule

For each candidate question, the builder should evaluate:

1. Does this decision materially affect fragment selection or generated behavior?
2. Is current confidence below `high`?
3. Would a wrong assumption likely mislead the user?
4. Is there a safe MVP default?

Recommended behavior:

- Ask if the answer is high impact, confidence is below `high`, and no safe default exists.
- Assume if the answer is lower risk and a safe default exists.
- Skip if the repo already answered it or it would not change behavior.

## Suggested Question Shape

Questions should be short, direct, and framed around concrete project choices.

Good pattern:

- decision
- why it matters
- the narrowest reasonable set of likely answers

Good example:

- Should the generated skill start from tracked tasks, direct briefs, or both? This changes the intake and project-management fragments.

Avoid:

- broad open-ended discovery interviews
- asking users to restate what the repository already shows
- mixing multiple unrelated decisions into one question

## Recording Questionnaire Results

Builder output should preserve both the question and the resulting decision state.

Canonical ID rule:

- `questions[].id` should use kebab-case.
- `decisions` keys should use snake_case.
- The normalization rule is: lowercase the question id and convert hyphens to underscores.
- Implementations and parsers should apply that mapping consistently when relating question records to decision records.

Examples:

- `work-intake-mode` -> `work_intake_mode`
- `review-path` -> `review_path`
- `primary-task-tracker` -> `primary_task_tracker`

Recommended conceptual shape:

```yaml
questions:
  - id: work-intake-mode
    status: asked
    prompt: Should the generated skill start from tracked tasks, direct briefs, or both?
    options:
      - tracked-task
      - direct-brief
      - both
    why: This changes the intake and project-management fragments.
    answer: both
decisions:
  work_intake_mode:
    state: confirmed
    value: both
    source: user-answer
```

If a question is skipped, the builder should still record why:

```yaml
questions:
  - id: review-path
    status: skipped
    reason: Repository evidence already supports human PR review at high confidence.
decisions:
  review_path:
    state: confirmed
    value: human-pr-review
    source: repo-evidence
```

## Unresolved-Decision Output Contract

Unresolved decisions should be visible in builder output, not hidden in prose.

At minimum, each unresolved decision should record:

- `id`
- `topic`
- `why_unresolved`
- `impact`
- `recommended_question`
- `safe_to_proceed`

Recommended shape:

```yaml
unresolved_decisions:
  - id: work-intake-mode
    topic: work intake mode
    why_unresolved: The repository suggests GitHub-based delivery, but it is unclear whether direct-brief bootstrap should remain available.
    impact: high
    recommended_question: Should the generated skill start from tracked tasks only, direct briefs only, or both?
    safe_to_proceed: false
  - id: task-tracker-authority
    topic: primary task tracker for tracked-task intake
    why_unresolved: GitHub Issues and Jira are both referenced, but authority is not explicit.
    impact: high
    recommended_question: Which system should the builder treat as authoritative for task intake and status updates?
    safe_to_proceed: false
  - id: runtime-budget-preference
    topic: runtime budget preference
    why_unresolved: The repo suggests complex work, but no explicit budget preference was found.
    impact: medium
    recommended_question: Should the generated skill optimize for lower cost or stronger reasoning effort by default?
    safe_to_proceed: true
```

## Example Builder Output

Below is a sample output shape showing confirmed, assumed, and unresolved decisions together.

```yaml
inventory:
  signals:
    - id: forge.github
      value: true
      strength: direct
      source:
        type: git-remote
        path: .git/config
    - id: task_tracker.jira
      value: true
      strength: strong-indirect
      source:
        type: docs
        path: CONTRIBUTING.md
        detail: Jira ticket keys appear in workflow examples
decisions:
  work_intake_mode:
    state: assumed
    value: both
    confidence: medium
    source: builder-default
    assumption: The repository appears to support delivery work but does not show a clearly authoritative tracker, so the builder kept both tracked-task and direct-brief intake available.
  primary_forge:
    state: confirmed
    value: github
    confidence: high
    source: repo-evidence
  review_path:
    state: assumed
    value: human-pr-review
    confidence: medium
    source: builder-default
    assumption: No direct review automation config was found, so the builder assumed human review.
  primary_task_tracker:
    state: unresolved
    value: null
    confidence: low
    source: conflicting-evidence
    why_unresolved: GitHub Issues and Jira both appear active, but neither is clearly primary.
questions:
  - id: primary-task-tracker
    status: pending
    prompt: Which system should the builder treat as the primary task tracker for tracked-task intake?
    why: This changes the generated project-management fragment.
unresolved_decisions:
  - id: task-tracker-authority
    topic: primary task tracker for tracked-task intake
    why_unresolved: GitHub Issues and Jira both appear active, but authority is unclear.
    impact: high
    recommended_question: Which system should the builder treat as authoritative?
    safe_to_proceed: false
```

## Relationship To The Inventory Workflow

Issue `#14` defined when the builder should ask a follow-up question.

This document defines what should happen next:

- which questions deserve priority
- how to skip unnecessary questions
- how to represent decision state after asking or skipping
- how unresolved choices remain visible in output

Together, `#14` and `#15` form the MVP builder decision loop:

1. inspect the repository
2. normalize evidence into signals
3. assign confidence to candidate decisions
4. ask only the necessary questions
5. record confirmed, assumed, and unresolved outcomes explicitly

Issue `#16` then consumes those recorded outcomes to assemble a coherent fragment set and emitted behavior blocks.

## Practical Guidance For MVP

To keep the questionnaire disciplined, the builder should:

- ask at most a few high-impact questions in the first pass
- prefer binary or short-option questions over broad prose requests
- skip any question already answered by strong repo evidence
- preserve ambiguity in output instead of hiding it
- avoid pretending the user answered something they did not answer

This keeps the builder lightweight, reviewable, and aligned with Superagents' goal of becoming an adaptive workflow operating layer rather than a giant setup wizard.
