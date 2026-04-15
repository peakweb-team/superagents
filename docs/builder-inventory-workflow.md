# Builder Inventory Workflow And Confidence Model

This document captures the research and proposed contract for issue `#14`:

- [#14 Define builder inventory workflow and confidence model](https://github.com/peakweb-team/pw-agency-agents/issues/14)

It builds directly on:

- the Claude-first MVP stance from issue `#29`
- the fragment schema from issue `#11`
- the generated-skill layout contract from issue `#12`
- the roadmap goal of turning Peakweb into a workflow operating layer instead of a loose prompt library

## Why This Exists

The builder cannot select fragments deterministically unless it has a disciplined way to answer four questions:

1. What repository evidence should it inspect?
2. How should that evidence be normalized into builder-readable signals?
3. When is the evidence strong enough to infer a project choice?
4. When should the builder stop inferring and ask the user?

This document defines the MVP answer.

## Goals

- inventory the most useful repository signals for early builder decisions
- make signal naming explicit enough to support fragment selection
- define a confidence model for inferred choices
- define the threshold for follow-up questions
- define what evidence the builder should record in its output

## Non-Goals

- implementing the full builder runtime
- detecting every possible tool or provider in v1
- replacing human confirmation when the evidence is genuinely ambiguous
- encoding full fragment assembly rules here

## MVP Workflow

The builder inventory flow should follow five steps.

### 1. Collect Raw Evidence

Inspect the repository and its immediate execution context for durable clues such as:

- git remotes
- repo files and directories
- CI and automation config
- docs and contribution guides
- existing local agent, skill, or workflow files
- package-manager and workspace manifests

The builder should prefer local evidence over assumptions and prefer durable config over incidental text.

### 2. Normalize Evidence Into Signals

Convert raw findings into a stable signal vocabulary that fragments and later builder logic can reference.

Example normalized signals:

- `forge.github`
- `task_tracker.github_issues`
- `task_tracker.jira`
- `repo.monorepo`
- `workflow.pull_requests`
- `workflow.parallel_agents`
- `workflow.model_budget_matters`
- `review.coderabbit`
- `docs.references_jira_workflows`

Signals are the bridge between repository inspection and fragment selection.

### 3. Infer Project Choices

Use one or more signals to infer builder decisions such as:

- primary task tracker
- review loop shape
- whether team-sizing guidance is needed
- whether runtime/model-routing guidance is needed
- whether a repo-local generated skill is likely to need multiple companion fragments
- whether existing repo-local Claude or Peakweb files should be reviewed before regeneration

The builder should infer choices only when the evidence reaches the confidence threshold defined below.

### 4. Record Evidence And Confidence

Every inferred choice should retain:

- the decision that was made
- the confidence level
- the signals that supported it
- the concrete sources those signals came from
- any conflicting or missing evidence

This keeps generated behavior reviewable and gives the questionnaire phase a clean starting point.

The recorded evidence should ultimately feed the metadata bundle defined in [`docs/generated-skill-layout.md`](./generated-skill-layout.md), especially `inventory.yaml`, `decisions.yaml`, and `review.md`.

### 5. Ask Only The Necessary Follow-Up Questions

If a high-impact decision remains ambiguous, the builder should ask a focused follow-up question instead of guessing.

If the ambiguity is low impact and a safe Claude-first default exists, the builder may proceed while explicitly recording the assumption.

## Signal Model

The builder should treat a signal as a normalized observation, not as a final decision.

Each recorded signal should have the following shape in concept:

```yaml
id: forge.github
value: true
strength: direct
source:
  type: git-remote
  path: .git/config
  detail: origin=github.com:peakweb-team/pw-agency-agents.git
```

Recommended signal fields:

- `id`
  - stable signal name
- `value`
  - usually boolean in v1, but may be a string or small enum when needed
- `strength`
  - one of `direct`, `strong-indirect`, or `weak-indirect`
- `source`
  - the file, config, path, or repo feature where the evidence came from
- `notes`
  - optional short explanation when the source is not self-explanatory

## Signal Categories

The builder should prioritize signal categories that materially affect fragment selection and questionnaire behavior.

### Forge And Code Host Signals

These help identify the primary hosting environment and likely PR workflow.

Common signals:

- `forge.github`
- `forge.gitlab`
- `forge.bitbucket`
- `workflow.pull_requests`
- `workflow.default_branch.main`
- `workflow.default_branch.master`

Typical evidence sources:

- git remote URLs
- CI workflow directories such as `.github/`
- contribution docs mentioning PR flow

### Task Tracker Signals

These drive provider-fragment selection for project-management behavior.

Common signals:

- `task_tracker.github_issues`
- `task_tracker.jira`
- `task_tracker.linear`
- `task_tracker.azure_boards`
- `task_tracker.gitlab_issues`
- `repo.references_issue_numbers`
- `repo.references_jira_keys`
- `docs.references_jira_workflows`

Typical evidence sources:

- issue-key patterns in branch names, docs, or templates
- references in contribution guides or runbooks
- issue or ticket links in templates, workflows, or scripts

### Review Workflow Signals

These shape the delivery fragment set and later provider-matrix work.

Common signals:

- `review.coderabbit`
- `review.human_required`
- `review.layered_automation`
- `workflow.pr_template_present`
- `workflow.review_checklist_present`

Typical evidence sources:

- CodeRabbit config
- PR templates
- docs describing review gates
- CI checks that clearly block merge on review state

### Repository Shape Signals

These affect runtime and orchestration guidance.

Common signals:

- `repo.monorepo`
- `repo.large`
- `repo.multi_package`
- `repo.multi_language`
- `repo.cross_functional_changes_likely`
- `repo.local_skills_present`

Typical evidence sources:

- workspace manifests
- package-manager config
- directory layout
- presence of multiple deployable apps or packages
- existing `.claude/`, `.agency/`, or skill-related directories

### Delivery And Validation Signals

These indicate how much explicit workflow guidance the generated skills will need.

Common signals:

- `workflow.ci_present`
- `workflow.deploy_config_present`
- `workflow.test_commands_present`
- `workflow.validation_expected`
- `workflow.release_process_documented`

Typical evidence sources:

- CI config
- deployment manifests
- package scripts
- Makefiles and task runners
- release docs

### Team And Runtime Signals

These matter for adaptive specialist-team selection and efficient execution rules.

Common signals:

- `workflow.parallel_agents`
- `workflow.review_and_validation_expected`
- `workflow.model_budget_matters`
- `workflow.specialist_handoffs_likely`
- `runtime.expensive_context`

Typical evidence sources:

- large or multi-package repo shape
- workflow docs with explicit handoff stages
- evidence of implementation plus review plus validation loops
- repository size and scope indicators

### Claude-First Environment Signals

Because MVP is Claude-first, the builder should also look for signals that strengthen Claude-centric defaults without overfitting the architecture.

Common signals:

- `runtime.claude_code_primary`
- `runtime.anthropic_skill_patterns_present`
- `repo.claude_local_config_present`

Typical evidence sources:

- `.claude/` directories
- Claude-focused setup docs
- project-local agent or skill conventions clearly aimed at Claude Code

These signals should bias defaults, but they should not override stronger evidence about task tracking, review tooling, or delivery flow.

## Confidence Model

Confidence is assigned to inferred decisions, not just to raw signals.

The MVP confidence levels should be:

- `high`
- `medium`
- `low`

### High Confidence

Use `high` when the repository provides direct or converging evidence that clearly supports one decision.

Examples:

- a GitHub remote plus `.github/` workflows plus issue references in PR templates support `forge.github` and likely `task_tracker.github_issues`
- repeated Jira ticket keys in docs and branch conventions support `task_tracker.jira`
- a root workspace manifest plus multiple app/package directories support `repo.monorepo`

Builder behavior:

- infer the choice automatically
- do not ask a follow-up question unless the decision conflicts with another high-confidence choice

### Medium Confidence

Use `medium` when the evidence suggests a likely answer but still leaves a meaningful chance of being wrong.

Examples:

- GitHub is clearly the forge, but issue usage is only implied by a few doc references
- the repo looks multi-package, but it is unclear whether orchestration truly needs multiple specialists
- review automation is mentioned in docs, but there is no local config proving it is active

Builder behavior:

- infer the choice only if a safe default exists and the impact of being wrong is limited
- otherwise ask a follow-up question
- always record the assumption explicitly

### Low Confidence

Use `low` when the evidence is weak, conflicting, or missing.

Examples:

- both GitHub Issues and Jira are mentioned, but neither appears clearly primary
- review tooling is described in outdated docs without matching config
- branch naming and templates provide no consistent task-tracker clues

Builder behavior:

- do not silently infer a high-impact choice
- ask a follow-up question
- record the unresolved ambiguity in the builder output

## Signal Strength Heuristics

The builder should also classify individual signals by how they were derived.

### `direct`

Evidence from configuration or repo structure that explicitly indicates the tool or workflow.

Examples:

- a GitHub remote URL
- a CodeRabbit config file
- a workspace manifest
- a `.claude/` project-local config directory

### `strong-indirect`

Evidence that does not directly configure the tool, but strongly implies it through repeated conventions.

Examples:

- repeated Jira keys in docs and PR title examples
- multiple docs that describe a PR-based review flow
- recurring references to issue numbers in branch naming guidance

### `weak-indirect`

Evidence that hints at a possibility but should not carry a high-impact decision by itself.

Examples:

- a single passing mention in a README
- an old migration note about a previous process
- one stale example branch name

Direct signals should outweigh indirect ones. Multiple converging strong-indirect signals may together justify `high` decision confidence.

## Follow-Up Threshold

The builder should ask a follow-up question when all three of the following are true:

1. the decision materially changes fragment selection or generated-skill behavior
2. the current confidence is below `high`
3. a wrong guess would likely create misleading workflow instructions

In practice, the builder should usually ask when deciding:

- the primary task tracker
- the primary PR/review loop
- whether Jira or GitHub Issues is authoritative
- whether review automation such as CodeRabbit is actually active

The builder should usually avoid asking when deciding:

- language or framework facts already visible in the repo
- whether a repo is monorepo-shaped when workspace manifests make it obvious
- low-risk runtime defaults such as reading files narrowly before escalating context use

## Recording Evidence In Builder Output

The builder output should include an inventory summary that is human-reviewable and stable enough to diff in git.

At minimum, record:

- detected signals
- inferred decisions
- confidence for each decision
- evidence sources
- assumptions
- unresolved questions

Recommended output shape:

```yaml
inventory:
  signals:
    - id: forge.github
      value: true
      strength: direct
      source:
        type: git-remote
        path: .git/config
        detail: origin points to github.com
    - id: workflow.pull_requests
      value: true
      strength: direct
      source:
        type: repo-path
        path: .github/PULL_REQUEST_TEMPLATE.md
    - id: review.coderabbit
      value: false
      strength: weak-indirect
      source:
        type: docs
        path: CONTRIBUTING.md
        detail: review mentions automation generally but no CodeRabbit config was found
  decisions:
    primary_task_tracker:
      value: github-issues
      confidence: medium
      supported_by:
        - forge.github
        - workflow.pull_requests
        - repo.references_issue_numbers
      conflicts_with: []
      assumption: GitHub Issues appears primary, but no explicit issue-policy doc was found.
    review_path:
      value: human-pr-review
      confidence: high
      supported_by:
        - workflow.pull_requests
        - workflow.review_checklist_present
      conflicts_with: []
  unresolved_questions:
    - id: task-tracker-authority
      prompt: Is GitHub Issues the primary tracker, or is another system authoritative?
      why: The repository shows GitHub delivery flow, but issue authority is not explicit.
```

The exact serialization can evolve, but the content should remain stable.

## Example Inventory Summary

Below is a sample Markdown-form inventory summary suitable for an MVP builder handoff.

```md
## Inventory Summary

### Detected Signals

- `forge.github` — high confidence
  - source: `.git/config` origin points to GitHub
- `workflow.pull_requests` — high confidence
  - source: `.github/PULL_REQUEST_TEMPLATE.md`
- `repo.monorepo` — high confidence
  - source: root workspace manifest and multiple package directories
- `workflow.model_budget_matters` — medium confidence
  - source: monorepo shape and multiple specialist-oriented workflow docs
- `task_tracker.github_issues` — medium confidence
  - source: issue-number references in docs and PR flow, but no explicit task-policy file

### Inferred Decisions

- Primary forge: GitHub (`high`)
- Primary task tracker: GitHub Issues (`medium`)
- Delivery model: PR-based review (`high`)
- Team sizing guidance needed: yes (`high`)
- Runtime/model-routing guidance needed: yes (`high`)

### Assumptions

- GitHub Issues is assumed to be the primary tracker until contradicted.
- No review automation provider is assumed because none was directly detected.

### Follow-Up Questions

- Confirm whether GitHub Issues is the authoritative tracker or just a mirror for another system.
```

## Recommended Priority Order For Inventory

The builder should inspect in this order so it can answer the highest-impact questions first:

1. forge and hosting signals
2. task-tracker signals
3. PR and review workflow signals
4. repository shape and packaging signals
5. delivery, validation, and runtime-efficiency signals
6. Claude-specific environment signals

This order keeps the first questionnaire pass small because the builder resolves major workflow branches before spending effort on lower-impact details.

## Practical Guidance For MVP

To stay aligned with the Claude-first MVP direction, the builder should prefer:

- concrete repository evidence over broad platform abstraction
- a small stable signal vocabulary over a huge speculative one
- explicit assumptions over silent guessing
- targeted follow-up questions over long setup interviews

That gives Peakweb the discipline of a workflow operating system while preserving the flexibility to expand its provider coverage later.
