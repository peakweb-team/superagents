# Claude Code Integration

The Agency was built for Claude Code. No conversion needed — agents work
natively with the existing `.md` + YAML frontmatter format.

The Claude install flow now also ships a reusable Peakweb skill bundle
containing the skill-builder and fragment source library.

## Install

```bash
# Copy all agents to your Claude Code agents directory
# and install the Peakweb reusable fragment bundle
./scripts/install.sh --tool claude-code

# Or manually copy a category
cp engineering/*.md ~/.claude/agents/
```

## Activate an Agent

In any Claude Code session, reference an agent by name:

```
Activate Frontend Developer and help me build a React component.
```

```
Use the Reality Checker agent to verify this feature is production-ready.
```

## Agent Directory

Agents are organized into divisions. See the [main README](../../README.md) for
the full Agency roster.

Reusable skill bundle path:

- `~/.claude/skills/peakweb-skill-builder/SKILL.md`
- `~/.claude/skills/peakweb-skill-builder/fragments/**/*.md`

Install/packaging and migration contract:

- [`docs/install-packaging-skill-fragments-contract.md`](../../docs/install-packaging-skill-fragments-contract.md)

Builder usage flow, repo-local precedence rules, and generated-skill review/versioning guidance:

- [`docs/builder-usage-and-repo-local-precedence-contract.md`](../../docs/builder-usage-and-repo-local-precedence-contract.md)
