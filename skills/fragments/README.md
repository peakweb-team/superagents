# Skill Fragments

This directory contains the reusable fragment source material that the Superagents builder selects from when generating project-local skills.

## Contract

Fragments now follow a canonical metadata contract documented here:

- [docs/fragment-schema.md](../../docs/fragment-schema.md)
- [docs/fragment-assembly-rules.md](../../docs/fragment-assembly-rules.md)
- [docs/external-capability-model.md](../../docs/external-capability-model.md)

In v1, each fragment is:

1. a Markdown file
2. with YAML frontmatter for builder-readable metadata
3. followed by a human-readable body that explains the behavior

## Current Layers

- `task-intake/`
  - direct-brief and other work-entry fragments
  - includes companion planning-batch intake fragments for portfolio-to-spec decomposition
- `project-management/`
  - task-system and workflow-of-record fragments
- `delivery/`
  - PR, review, and downstream delivery-loop fragments
- `orchestration/`
  - team-sizing, role-shaping, and coordination fragments
- `runtime/`
  - context, model-routing, execution-discipline, and devcontainer-management fragments

## Builder Expectations

The builder should treat fragments as composable operating-system parts for a repository, not just prompt snippets.

That means fragment metadata should help the builder answer:

- when this fragment applies
- what capability it contributes
- what it conflicts with
- what it commonly pairs with
- where it belongs in assembled output

The concrete rules for exclusivity buckets, conflict handling, and emitted behavior blocks are defined in [`docs/fragment-assembly-rules.md`](../../docs/fragment-assembly-rules.md).

Capability names should use the canonical vocabulary from `docs/external-capability-model.md` so provider fragments stay comparable and direct-brief workflows remain first-class.

## MVP Bias

The fragment system is Claude-first for MVP, but the schema remains capability-oriented so Superagents can broaden later without rebuilding the entire contract.
