# Superpowers Review For Peakweb

This document captures the research outcome for issue `#31`:

- [#31 Review obra/superpowers skills system for reusable Peakweb patterns](https://github.com/peakweb-team/pw-agency-agents/issues/31)

References reviewed:

- [obra/superpowers repository](https://github.com/obra/superpowers)
- [obra/superpowers skills directory](https://github.com/obra/superpowers/tree/main/skills)

## Summary

`superpowers` is not just a collection of reusable skills. It is an opinionated software-development workflow system built out of composable skills, initial instructions, and automatic skill activation.

That makes it highly relevant to Peakweb.

The most important lesson is this:

- Peakweb should borrow `superpowers`'s **workflow discipline**
- Peakweb should not copy `superpowers` wholesale

Peakweb's product direction is a builder that generates project-specific skills from fragments. `superpowers` provides a strong example of how a skill system can enforce planning, work isolation, verification, and staged execution. It is especially useful as a reference for what "workflow-oriented skills" can look like in practice.

## What Superpowers Is Doing Well

From its public README and skill structure, `superpowers` has a few especially strong patterns.

### 1. It Treats Skills As A Development Lifecycle

The repo describes a full workflow:

- brainstorm first
- isolate work in a worktree
- write a plan
- execute the plan with subagents
- use TDD
- request code review
- verify before completion

This is a major step beyond "skill as reusable snippet". It treats skills as operational stages in a development system.

### 2. It Uses Composable Workflow Stages

The skills directory is organized around workflow phases such as:

- `brainstorming`
- `using-git-worktrees`
- `writing-plans`
- `subagent-driven-development`
- `test-driven-development`
- `requesting-code-review`
- `verification-before-completion`
- `writing-skills`

This phase-based decomposition is highly relevant to Peakweb's fragment model.

### 3. It Is Strong On Work Isolation

`superpowers` strongly emphasizes git worktrees and isolated execution contexts. That is useful because it treats parallel work and branch hygiene as a first-class workflow concern, not an afterthought.

### 4. It Makes Verification A Distinct Stage

Verification is not implied. It is explicit.

This is valuable because one of the easiest failure modes in agent workflows is collapsing "implementation complete" and "verified complete" into the same thing.

### 5. It Treats Skill Authoring As A Discipline

The presence of `writing-skills` is especially important for Peakweb. It suggests skill authoring itself should be treated as a structured, improvable workflow rather than ad hoc prompt writing.

## Agent Model Comparison

One useful difference to examine is how `superpowers` appears to think about execution units compared with Peakweb's current direction.

### Superpowers Appears To Be Workflow-First, Not Persona-First

From the public skills structure, `superpowers` does not appear to organize itself around a large roster of domain personas in the way `agency-agents` does.

Its visible skills are mostly workflow-shaped:

- `brainstorming`
- `writing-plans`
- `using-git-worktrees`
- `subagent-driven-development`
- `requesting-code-review`
- `verification-before-completion`
- `writing-skills`

That suggests `superpowers` is less about "pick the right specialist persona" and more about "move through the right engineering workflow."

This is a meaningful product difference.

### Agency-Agents Is Much Stronger On Persona Breadth

Peakweb inherits a large specialist roster from `agency-agents`.

That matters because it opens up workflows that are not only engineering-process oriented, but also domain oriented. For example:

- audit a GA4 account
- review a paid media setup
- analyze SEO implementation
- inspect a CMS configuration
- produce findings in a wiki or issue tracker

That means Peakweb has a chance to become more flexible than `superpowers` in one important dimension:

- `superpowers` shows how to build strong workflow discipline
- `agency-agents` gives Peakweb a much wider specialist surface area

### Subagents vs Agent Teams

`superpowers` visibly leans into a `subagent-driven-development` model.

That alone does **not** imply a single shared context window.

Anthropic's official Claude Code documentation says custom subagents use **their own separate context window**, which means Claude Code subagent workflows already benefit from context isolation and context preservation. The canonical references worth retaining here are:

- [Claude Code subagents](https://code.claude.com/docs/en/sub-agents)
- [Claude Code agent teams](https://code.claude.com/docs/en/agent-teams)

Those docs also reinforce the bigger distinction: subagents return summarized results to the main agent, while agent teams enable direct messaging and self-coordination across fully independent sessions.

So the difference is not simply:

- `superpowers` = one context window
- Peakweb = many context windows

That would be inaccurate.

The more useful distinction is:

- `superpowers` appears to be centered on a workflow/methodology built around Claude Code subagents
- Peakweb can combine **workflow discipline** with a broader **specialist-agent roster** and explicit team-composition logic

That gives Peakweb a real opportunity to be more powerful in practice, especially when tasks benefit from multiple specialized roles that need to coordinate directly instead of reporting only through a single parent session.

### Why Peakweb May Still Be More Powerful

Peakweb's opportunity is not merely "more agents".

It is:

- broader persona coverage
- builder-generated project-specific workflow layers
- explicit team sizing
- ability to combine workflow fragments with domain-specialist agent selection

If implemented well, Peakweb can become:

- more workflow-aware than plain `agency-agents`
- more persona-rich than `superpowers`

That is a strong differentiator.

## What Peakweb Should Borrow

### Borrow 1: Workflow-Phase Thinking

Peakweb should borrow the idea that skills can correspond to phases in a delivery workflow, not just topical helpers.

This supports a fragment model where some fragments are:

- planning-oriented
- execution-oriented
- verification-oriented
- delivery-oriented

### Borrow 2: Explicit Verification Before Completion

Peakweb should make verification a first-class concern in generated skills.

That does not mean copying `superpowers`' exact workflow, but it does mean generated skills should have a clear place for:

- validation expectations
- review expectations
- completion criteria

### Borrow 3: Meta-Skills For Authoring And Refinement

Peakweb should take seriously the idea that creating and refining skills is itself a workflow.

This supports:

- the skill builder
- future skill iteration flows
- easier evaluation and refinement of generated project-local skills

### Borrow 4: Operational Discipline

`superpowers` shows that skills become much more valuable when they shape behavior, not just content.

Peakweb should borrow that level of seriousness around:

- planning before coding
- isolating work
- verifying results
- keeping workflow stages explicit

## What Peakweb Should Adapt, Not Copy

### Adapt 1: Prescriptiveness

`superpowers` is intentionally opinionated and highly prescriptive.

Peakweb should adapt that, not copy it directly.

Why:

- Peakweb needs a builder that can assemble workflow behavior based on the repo and team context.
- A generated skill system should allow the workflow to vary by project.

So Peakweb should keep the discipline, but not force one rigid lifecycle on every team.

### Adapt 2: Trigger Model

`superpowers` leans heavily on automatic skill triggering.

Peakweb should learn from that, especially for Claude-first behavior, but should still design generated skills so they remain understandable and reviewable even when trigger behavior is imperfect.

### Adapt 3: Worktree Rules

The worktree-first model is strong, but Peakweb should probably treat it as a configurable workflow strategy rather than a universal requirement for every project and task in v1.

### Adapt 4: TDD As A Universal Rule

`superpowers` puts strong emphasis on TDD and staged development discipline.

Peakweb should learn from the emphasis on verification and iteration, but should be careful about hard-coding one engineering doctrine into every generated skill unless the project explicitly wants that.

## What Peakweb Should Avoid Copying

### Avoid 1: Full Workflow Lock-In

Peakweb should not try to become a clone of `superpowers`.

The product directions differ:

- `superpowers` is a complete methodology
- Peakweb is a builder-driven system for generating project-specific skill layers

### Avoid 2: Over-Prescriptive MVP Behavior

If we copy too much of `superpowers`' operational rigidity into the MVP, we risk making Peakweb feel like a workflow religion instead of a builder that adapts to teams.

### Avoid 3: Conflating Reference Quality With Product Fit

`superpowers` can be an excellent reference implementation without being the right product model for Peakweb.

## Implications For Phase 1 Issues

### Implication For `#11` Fragment Schema

The fragment schema should support workflow-phase fragments, not just domain/topic fragments.

For example, it should be possible to represent fragments that are primarily about:

- planning
- work isolation
- execution mode
- review
- verification

### Implication For `#12` Generated Skill Layout And Precedence

Generated skills should probably preserve some layered structure instead of flattening everything into a single undifferentiated prompt.

`superpowers` suggests that stage clarity matters.

### Implication For `#14` Builder Inventory Workflow

The builder should inspect the repo for workflow signals, not just stack signals.

Examples:

- branch/worktree conventions
- review process expectations
- planning artifacts
- testing discipline

### Implication For `#15` Questionnaire Design

The builder questionnaire should include workflow questions, not just tool questions.

Examples:

- how strict should planning be before coding starts?
- is worktree isolation expected?
- how formal is verification before completion?
- how opinionated should the generated workflow be?

## Recommendation

Peakweb should use `superpowers` as a **workflow-pattern reference implementation**.

The recommended stance is:

- borrow its discipline
- borrow its phase-based thinking
- borrow its seriousness about verification and skill authoring
- avoid copying its full rigidity
- keep Peakweb centered on builder-generated, project-specific skill composition

In short:

- learn from `superpowers`
- do not become `superpowers`
