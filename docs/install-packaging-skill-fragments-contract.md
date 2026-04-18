# Installation And Packaging Contract For Reusable Superagents Skills

This document defines the canonical install/packaging contract for:

- [#26 Ship reusable skill fragments in installation and packaging flow](https://github.com/peakweb-team/pw-agency-agents/issues/26)
- [#83 Feature: Superagents skill for isolated Anthropic dev container + user-level packaging](https://github.com/peakweb-team/pw-agency-agents/issues/83)

It aligns with:

- the generated-skill layout and precedence rules in [`docs/generated-skill-layout.md`](./generated-skill-layout.md)
- the builder usage and repo-local precedence contract in [`docs/builder-usage-and-repo-local-precedence-contract.md`](./builder-usage-and-repo-local-precedence-contract.md)
- the release and upgrade contract in [`docs/release-versioning-and-upgrade-contract.md`](./release-versioning-and-upgrade-contract.md)
- the Phase 3 packaging/adoption milestone in [`ROADMAP.md`](../ROADMAP.md)

## Why This Exists

Superagents now has multiple user-level assets that must ship together:

- the base agent roster
- the reusable `superagents-skill-builder` bundle with fragment source material
- the reusable `superagents-devcontainer-bootstrap` bundle for isolated Anthropic-based container scaffolding

Without an explicit install contract, users can end up with agents installed but missing critical reusable skills.

## User-Level Installation Paths (Claude-First MVP)

When users run:

```bash
./scripts/install.sh --tool claude-code
```

the installer must place assets at deterministic user-level paths:

- agents:
  - `~/.claude/agents/*.md`
- reusable skills:
  - `~/.claude/skills/superagents-skill-builder/SKILL.md`
  - `~/.claude/skills/superagents-skill-builder/fragments/**/*.md`
  - `~/.claude/skills/superagents-devcontainer-bootstrap/SKILL.md`
  - `~/.claude/skills/superagents-devcontainer-bootstrap/templates/*`

The reusable bundle paths are intentionally namespaced (`superagents-`) so they do not collide with unrelated local skills.

## Packaging Behavior

Superagents framework packaging for install flows must include all of the following source inputs:

- `agents/**`
- `skills/skill-builder/SKILL.md`
- `skills/fragments/**/*.md`
- `skills/devcontainer-bootstrap/**`
- `scripts/install.sh`

Installer behavior for reusable skills is deterministic:

1. `superagents-skill-builder` is staged and activated at `~/.claude/skills/superagents-skill-builder/`.
2. The target `fragments/` subtree under that bundle is replaced.
3. Current repository fragments are copied into the rebuilt subtree.
4. `superagents-devcontainer-bootstrap` is staged and activated at `~/.claude/skills/superagents-devcontainer-bootstrap/`.
5. Existing target bundle directories are replaced atomically.

Atomic replacement ensures removed or renamed files do not linger as stale local content across reinstall/upgrade runs.

## Relationship To Repo-Local Generated Output

This contract does not change generated output roots:

- generated project-local skills remain under `.claude/skills/superagents/`
- generated metadata remains under `.agency/skills/superagents/`

User-level reusable skills are source material and helper workflows. Repo-local generated output remains the project-authoritative execution layer.

## Migration Expectations

### Existing users with agents-only Claude installs

If a user previously installed only `~/.claude/agents`, migration is:

1. pull a release that includes this contract
2. rerun `./scripts/install.sh --tool claude-code`

Expected result:

- existing agent files are refreshed as before
- `superagents-skill-builder` is installed at `~/.claude/skills/superagents-skill-builder/`
- `superagents-devcontainer-bootstrap` is installed at `~/.claude/skills/superagents-devcontainer-bootstrap/`

No project-local generated files are created or overwritten by this installer step.

### Existing users with repo-local generated skills

No immediate regeneration is required purely because user-level reusable bundles are refreshed or expanded.

Regeneration guidance continues to follow [`docs/release-versioning-and-upgrade-contract.md`](./release-versioning-and-upgrade-contract.md).

## MVP Boundary

This contract requires:

- deterministic user-level installation paths for reusable Superagents skills
- packaging that ships reusable skills with the roster install flow
- explicit migration guidance for agents-only installs

This contract does not require:

- automatic project-local generation during installation
- automatic migration of hand-edited generated skills
- provider-specific runtime guarantees beyond the existing Claude-first MVP scope
