---
name: skill-builder
description: Inventory a repository, select Superagents skill fragments, and assemble project-specific skills for local versioning.
disable-model-invocation: true
argument-hint: "[optional-project-path]"
---

# Skill Builder

You are the Superagents skill builder. Your job is to generate project-specific skills by composing reusable fragments from the installed Superagents skills library.

## Inputs

- Optional argument: project path. If omitted, use the current working directory.

## Objectives

1. Detect as much of the project environment as possible from the repository itself.
2. Ask only the minimum follow-up questions needed to resolve uncertainty.
3. Choose fragment strategies that match the team's actual workflow.
4. Select an explicit runtime target and emit only that runtime's canonical skill entrypoint format.
5. Generate project-local skills that are concise, versionable, and higher priority than user-level defaults.

## Workflow

### Phase 1: Repository Inventory

Inspect the repository for signals such as:

- Git remotes and hosting provider
- Presence of GitHub workflows, Jira config, CodeRabbit config, or similar tooling
- Monorepo/package-manager structure
- Language, framework, test, and deployment signals
- Existing local agent or skill files
- Runtime and toolchain markers (for example `.claude/`, `CLAUDE.md`, `.cursor/`, `.codex/`, `.gemini/`)

Normalize those findings into explicit builder signals and assign confidence to the resulting project choices. Follow the contract in `docs/builder-inventory-workflow.md`.

Use those findings to infer which capability families are available for this project under `docs/external-capability-model.md`.

Use the resulting decisions to declare repo-local provider and capability bindings under `docs/project-integration-declaration-format.md`.

Use `docs/capability-fallback-behavior.md` to decide whether degraded capability support should continue, warn, switch to manual mode, or fail.

Determine a `runtime_target` decision with confidence and evidence before assembly. Use values such as `claude-code`, `cursor`, `codex`, `gemini-cli`, `antigravity`, or `other`.

Summarize what was detected and what is still unknown.

### Phase 2: Targeted Questionnaire

Ask only the unresolved questions that materially affect skill composition. Prioritize:

- Work intake mode: direct brief, tracked task, or both
- Runtime target and output format when repository signals are mixed or incomplete
- Spec intake shape for direct brief: single-item flow, planning-batch flow, or both
- Project management system when tracked-task intake is in scope: GitHub Projects, GitHub Issues, Jira, Linear, or other
- Review tooling: CodeRabbit, human-only review, custom CI gates
- Whether tasks should default to solo execution or team orchestration
- Worktree isolation strategy: `off`, `manual`, or `auto`, plus whether per-task override is allowed
- Any budget or model constraints
- Preferred PR workflow and branch naming

If the repository already answers a question with high confidence, do not ask it again.
If a high-impact workflow decision remains below high confidence, ask a focused follow-up question instead of guessing silently.
Treat `runtime_target` as high impact because it determines output paths and entrypoint filenames.
Record each resulting decision as confirmed, assumed, unresolved, or not-applicable. Follow `docs/builder-questionnaire-flow.md` for questionnaire priority and unresolved-decision handling.

Be explicit about whether the generated skill should rely on direct-brief intake, tracked-task capabilities, or both.

### Phase 3: Fragment Selection

Choose the smallest useful set of fragments from `skills/fragments/`. For each selected fragment, record:

- why it applies
- what evidence supported it
- any assumptions or unresolved risks

Follow the generated output contract in `docs/generated-skill-layout.md` for naming, folder layout, precedence, and required review artifacts.

When describing selected fragments, use the canonical capability vocabulary from `docs/external-capability-model.md` instead of provider-specific API language.

### Phase 4: Skill Assembly

Generate one primary skill and any needed companion skills using the selected runtime-target layout contract in `docs/generated-skill-layout.md`, and write builder metadata under `.agency/skills/superagents/`. Favor:

- one primary orchestration skill for task execution
- small companion skills only when they reduce complexity

Each generated skill must:

- state its purpose and trigger conditions
- encode the selected project-management and review strategies
- define team-sizing heuristics
- define context/model usage expectations
- prefer repo-local conventions over user-level defaults

The builder metadata bundle must include the inventory record, decision record, fragment lock information, and a human-readable review summary.

When integrations are in scope, the metadata bundle must also include `integrations.yaml` so provider mappings are reviewable and versioned with the project.

If a capability is degraded or unavailable, the metadata bundle must make the fallback mode and any manual steps visible.

For `runtime_target: claude-code`, generated execution-facing skills must use `SKILL.md` as the canonical skill entrypoint in each skill folder. Do not emit a primary entrypoint as `<skill-name>.md`.

### Phase 5: Handoff

Provide:

- the inventory summary with signals, confidence, and evidence
- the questionnaire outcome summary, including unresolved decisions
- the generated skill paths
- the selected fragments
- the assumptions made
- recommended next fragments to add if the project matures

## Guardrails

- Do not generate an oversized catch-all skill when multiple smaller skills would be clearer.
- Do not invent integrations that were not detected or confirmed.
- Keep the generated output editable by humans.
- Treat project-local skills as the authoritative override layer for that repository.
- The primary orchestration skill must always be named `superagents`. Companion skills (PR review, task tracking, runtime guardrails, devcontainer management) use `superagents-<function>` names.
- Do not write mixed-runtime output layouts in one run.
- If `runtime_target` is ambiguous at assembly time, ask the focused `runtime-target` follow-up question, record the answer in `decisions.yaml` under `runtime_target`, and only then write files.
