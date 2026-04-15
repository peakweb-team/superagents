# Skills

This directory is the starting point for the Peakweb skills layer.

## Goals

- Keep the core agent roster reusable and tool-agnostic.
- Compose project-specific skills from focused fragments instead of shipping one giant universal skill.
- Support both user-level installation and repo-level generated skills that can be versioned with the project and take precedence locally.

## Initial Structure

- `skill-builder/`
  - Interactive builder skill that inventories a repo, asks a targeted questionnaire, and assembles project-specific skills.
- `fragments/task-intake/`
  - Work-entry fragments for direct-brief and other intake modes.
- `fragments/project-management/`
  - Strategy fragments for issue systems such as GitHub Issues and Jira.
- `fragments/orchestration/`
  - Team formation and agent-selection strategies.
- `fragments/delivery/`
  - PR creation, review routing, and reviewer interaction patterns.
- `fragments/runtime/`
  - Context budgeting, tool usage, and model-routing guidance.

## Fragment Contract

Fragments are no longer just loose Markdown notes. The canonical fragment schema now lives in [`docs/fragment-schema.md`](../docs/fragment-schema.md), and the fragment source directory is documented in [`skills/fragments/README.md`](./fragments/README.md).

That contract keeps the builder deterministic while preserving readable, reviewable fragment bodies.

## Builder Contract

The repository-inventory and confidence rules for the builder now live in [`docs/builder-inventory-workflow.md`](../docs/builder-inventory-workflow.md).

That document defines which repo signals the builder should look for, how it should assign confidence, and when it should stop inferring and ask the user.

The questionnaire and unresolved-decision contract now lives in [`docs/builder-questionnaire-flow.md`](../docs/builder-questionnaire-flow.md).

The generated-skill output, naming, and precedence contract now lives in [`docs/generated-skill-layout.md`](../docs/generated-skill-layout.md).

The external capability vocabulary that fragments and generated skills should rely on now lives in [`docs/external-capability-model.md`](../docs/external-capability-model.md).

The repo-local provider and capability binding format now lives in [`docs/project-integration-declaration-format.md`](../docs/project-integration-declaration-format.md).

The fallback rules for unavailable, partial, or manual-only capabilities now live in [`docs/capability-fallback-behavior.md`](../docs/capability-fallback-behavior.md).

## Intended Flow

1. Peakweb Agency Agents is installed into the user's home directory with the base agent roster and reusable skill fragments.
2. The user runs the `skill-builder` skill inside a target project.
3. The builder inspects the repo, confirms any missing details through a short questionnaire, and selects the relevant fragments.
4. The builder assembles one primary skill and any needed companion skills under `.claude/skills/peakweb/`, then writes reviewable builder metadata under `.agency/skills/peakweb/`.

This is scaffolding for the first iteration, not the final packaging or install behavior.
