# Peakweb Agency Agents

A practical execution layer built on top of the `agency-agents` roster.

Peakweb keeps the broad specialist-agent library and adds a project-aware skills system so teams can run repeatable delivery workflows inside real repositories.

## What This Repository Is For

Peakweb is focused on software-delivery execution, not just persona prompts:

- install a reusable base roster of specialists
- compose repo-specific skills from modular fragments
- run delivery workflows with explicit planning, implementation, review, and validation behavior
- keep generated repo-local skills versioned with your codebase

## Feature Highlights

### 1. Superpowers + Agency-Agents (Workflow + Specialist Breadth)

Peakweb combines two strengths:

- workflow discipline inspired by `superpowers`
- broad persona coverage inherited from `agency-agents`

That combination lets teams keep structured execution while still selecting domain-specific specialists.

### 2. Custom Skills For Your Use Cases

The `peakweb-skill-builder` flow inventories a target repository, asks only missing workflow questions, and assembles project-local skills from fragments.

Generated outputs live in your repo:

- `.claude/skills/peakweb/` (execution-facing skills)
- `.agency/skills/peakweb/` (builder metadata, decisions, and review context)

### 3. Model Routing

Peakweb fragments include runtime guidance for choosing the right model strength for the task, instead of defaulting every step to the most expensive path.

See: [docs/runtime-context-budgeting-and-repo-reading.md](docs/runtime-context-budgeting-and-repo-reading.md)

### 4. Token Conservation

The framework emphasizes bounded context loading, scoped reads, and targeted orchestration so large-repo workflows stay efficient.

### 5. Parallel Work Across Multiple Issues/Teams

Peakweb supports isolated execution with `git worktree`, enabling multiple issue streams to run in parallel without branch collisions.

### 6. Repo-Local Precedence (Deterministic)

Repo-local generated Peakweb skills are authoritative in that repository, while user-level installed skills remain reusable defaults and source material.

See: [docs/builder-usage-and-repo-local-precedence-contract.md](docs/builder-usage-and-repo-local-precedence-contract.md)

### 7. Multi-Tool Installation

The project includes conversion/install scripts and integration outputs for multiple coding-assistant tools.

Supported install targets include:

- `claude-code`
- `copilot`
- `antigravity`
- `gemini-cli`
- `opencode`
- `openclaw`
- `cursor`
- `aider`
- `windsurf`
- `qwen`
- `kimi`

## How Peakweb Relates To Superpowers

### What Is Shared

- strong workflow discipline (plan before execute, explicit review/verification stages)
- emphasis on reliable, repeatable software-delivery behavior
- practical use of work isolation and operational guardrails

### What Is Different

- Peakweb is built around a **builder-generated, repo-specific skills layer**
- Peakweb keeps a **large specialist persona roster** from `agency-agents`
- Peakweb aims for **adaptive team sizing and orchestration**, not one fixed execution style
- Peakweb treats generated skills as repo-versioned artifacts with deterministic precedence

Reference: [docs/superpowers-review.md](docs/superpowers-review.md)

## Usage

### 1. Install The Base Package

From this repo:

```bash
./scripts/install.sh --tool claude-code
```

This installs:

- agents to `~/.claude/agents/`
- builder source bundle to `~/.claude/skills/peakweb-skill-builder/`

### 2. Create Skills For A Specific Repository

In your target project:

```bash
cd /path/to/target-repo
```

Then invoke `peakweb-skill-builder` in your coding assistant.

Example invocation:

- type `/peakweb-skill-builder`, or select `peakweb-skill-builder` from your assistant skill menu
- prompt: `Generate Peakweb project-local skills for this repository`

Expected generated roots:

- `.claude/skills/peakweb/`
- `.agency/skills/peakweb/`

Review and commit both roots together.

Full contract: [docs/builder-usage-and-repo-local-precedence-contract.md](docs/builder-usage-and-repo-local-precedence-contract.md)

### 3. Use Skills Day-To-Day

Typical loop:

1. Activate the repo-local Peakweb skill before starting issue work.
   Example: select the generated skill from your assistant skill list (under `.claude/skills/peakweb/`) or invoke it by command if your assistant supports slash-commands.
   What to expect: the skill frames intake inputs (issue/brief), constraints, and required context.
2. Start implementation from the target repo with a concrete task prompt.
   Example prompt: `Implement issue #123 in this repository using the active Peakweb workflow.`
   What to expect: a scoped plan, execution steps, and explicit handoffs between implementation and review.
3. Run review and validation as separate completion gates.
   Example prompt: `Run Peakweb review and validation for the current branch and summarize any blockers.`
   What to expect: a findings list, validation evidence, and a clear pass/fail recommendation for merge.
4. Regenerate and commit skills when workflow/tooling assumptions change.
   Example trigger: switching task systems, review tooling, or orchestration strategy.
   What to expect: updates in `.claude/skills/peakweb/` and `.agency/skills/peakweb/` that should be reviewed and committed together.

### 4. Run Multiple Workstreams In Parallel (Worktrees)

Peakweb is worktree-first by default. For each issue/ticket, the system should automatically:

1. create or reuse a dedicated local worktree for that ticket
2. create/switch to the ticket branch inside that worktree
3. keep concurrent tickets isolated so file and branch state cannot collide

The intent is zero manual setup for normal operation.

Manual `git worktree` commands are low-level equivalents (useful for debugging or recovery), for example:

```bash
git worktree add ../repo-issue-101 -b feat/issue-101 origin/HEAD
git worktree add ../repo-issue-102 -b feat/issue-102 origin/HEAD
```

Use one worktree per issue/team stream to keep execution isolated.

## Repository Layout

- `agents/`: source specialist roster by domain/division
- `skills/`: builder and reusable fragment source
- `docs/`: contracts, architecture, and delivery guidance
- `examples/`: generated-skill references and workflow examples
- `integrations/`: generated integration outputs for supported tools
- `scripts/`: conversion/install scripts

## Key Documents

- [ROADMAP.md](ROADMAP.md)
- [docs/builder-inventory-workflow.md](docs/builder-inventory-workflow.md)
- [docs/builder-questionnaire-flow.md](docs/builder-questionnaire-flow.md)
- [docs/generated-skill-layout.md](docs/generated-skill-layout.md)
- [docs/spec-builder-contract.md](docs/spec-builder-contract.md)
- [docs/builder-usage-and-repo-local-precedence-contract.md](docs/builder-usage-and-repo-local-precedence-contract.md)
- [docs/install-packaging-skill-fragments-contract.md](docs/install-packaging-skill-fragments-contract.md)
- [docs/runtime-context-budgeting-and-repo-reading.md](docs/runtime-context-budgeting-and-repo-reading.md)
- [examples/generated-skills/README.md](examples/generated-skills/README.md)

## Other Integrations

Regenerate integration outputs:

```bash
./scripts/convert.sh
```

Install interactively for detected tools:

```bash
./scripts/install.sh
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)
