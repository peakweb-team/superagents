# Skills

This directory is the starting point for the Peakweb skills layer.

## Goals

- Keep the core agent roster reusable and tool-agnostic.
- Compose project-specific skills from focused fragments instead of shipping one giant universal skill.
- Support both user-level installation and repo-level generated skills that can be versioned with the project and take precedence locally.

## Initial Structure

- `skill-builder/`
  - Interactive builder skill that inventories a repo, asks a targeted questionnaire, and assembles project-specific skills.
- `fragments/project-management/`
  - Strategy fragments for issue systems such as GitHub Issues and Jira.
- `fragments/orchestration/`
  - Team formation and agent-selection strategies.
- `fragments/delivery/`
  - PR creation, review routing, and reviewer interaction patterns.
- `fragments/runtime/`
  - Context budgeting, tool usage, and model-routing guidance.

## Intended Flow

1. Peakweb Agency Agents is installed into the user's home directory with the base agent roster and reusable skill fragments.
2. The user runs the `skill-builder` skill inside a target project.
3. The builder inspects the repo, confirms any missing details through a short questionnaire, and selects the relevant fragments.
4. The builder assembles one or more project-local skills under a versioned project directory such as `.agency/skills/`.

This is scaffolding for the first iteration, not the final packaging or install behavior.
