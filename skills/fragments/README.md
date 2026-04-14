# Skill Fragments

This directory contains the reusable fragment source material that the Peakweb builder selects from when generating project-local skills.

## Contract

Fragments now follow a canonical metadata contract documented here:

- [docs/fragment-schema.md](../../docs/fragment-schema.md)

In v1, each fragment is:

1. a Markdown file
2. with YAML frontmatter for builder-readable metadata
3. followed by a human-readable body that explains the behavior

## Current Layers

- `project-management/`
  - task-system and workflow-of-record fragments
- `delivery/`
  - PR, review, and downstream delivery-loop fragments
- `orchestration/`
  - team-sizing, role-shaping, and coordination fragments
- `runtime/`
  - context, model-routing, and execution-discipline fragments

## Builder Expectations

The builder should treat fragments as composable operating-system parts for a repository, not just prompt snippets.

That means fragment metadata should help the builder answer:

- when this fragment applies
- what capability it contributes
- what it conflicts with
- what it commonly pairs with
- where it belongs in assembled output

## MVP Bias

The fragment system is Claude-first for MVP, but the schema remains capability-oriented so Peakweb can broaden later without rebuilding the entire contract.
