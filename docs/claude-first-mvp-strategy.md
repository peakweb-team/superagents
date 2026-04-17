# Claude-First MVP Strategy

This document captures the research outcome for issue `#29`:

- [#29 Research Claude-first MVP strategy and Anthropic compatibility approach](https://github.com/peakweb-team/pw-agency-agents/issues/29)

## Decision

Superagents should be **Claude-first for the MVP**.

That means:

- the first builder and generated-skill experience should optimize for Claude and Claude Code
- project-local override behavior should align with Claude-centric workflows
- Superagents should avoid spending MVP time on first-class support for every AI platform

At the same time, the architecture should remain **clean enough to broaden later** if adoption justifies it.

In practice, that means:

- Claude-first product decisions
- capability-oriented internal design
- no premature multi-platform abstraction layer

## Why This Is The Right MVP Stance

Superagents is a fork of a project that is already Claude-forward in how teams are likely to use it.

Trying to make the MVP equally optimized for every AI platform would create three immediate risks:

1. It would dilute the builder experience before we have a strong reference implementation.
2. It would push us toward generic abstractions that are not yet justified by real user demand.
3. It would slow down the highest-value work: making the skill builder excellent for the most likely first users.

The MVP should therefore optimize for the environment most aligned with the upstream project and the current product direction: Claude and Claude Code.

## What Anthropic Appears To Offer

Based on official Anthropic material:

- Anthropic has a **Skills** concept: folders containing instructions, scripts, and resources that Claude can load when relevant.
- Skills are described as **composable**, and Anthropic positions them as usable across Claude apps, Claude Code, and the API.
- Claude Code supports a strong **project-local configuration** model, which aligns well with repo-local override behavior.

These ideas are highly relevant to Superagents's direction.

## Additional Lessons From Anthropic's `skill-creator`

Anthropic's public `skills/skill-creator` implementation adds a few practical lessons beyond the high-level product docs.

### 1. Skill Creation Is Itself A Workflow

Anthropic treats skill creation as a repeatable workflow, not just a one-off writing task.

That aligns strongly with Superagents's builder direction:

- discover intent
- ask focused clarifying questions
- draft the skill
- evaluate it
- refine it

### 2. Start With Intent, Not Structure

The `skill-creator` flow starts by understanding what the user wants the skill to enable, when it should trigger, and what outputs are expected.

Superagents should mirror this. The builder should start from:

- desired workflow behavior
- trigger context
- output expectations

and only then move into fragment selection and generated skill structure.

### 3. Ask Only The Questions That Matter

Anthropic's flow is interview-driven, but targeted. It tries to fill gaps from context first, then asks only what is still ambiguous.

That is a strong fit for Superagents's builder questionnaire design.

### 4. Progressive Disclosure Matters

Anthropic explicitly separates:

- metadata
- the main skill body
- additional resources

This is an important pattern for Superagents as well. It suggests our fragment system should not collapse everything into one giant generated output when layered structure would keep runtime loading cleaner.

### 5. Evaluation Should Be Part Of The Loop

Anthropic's `skill-creator` strongly emphasizes test prompts, evaluation, and iterative refinement.

Superagents probably does not need the full evaluation harness in the first builder release, but this is still an important takeaway:

- the builder should eventually support iteration, not just initial generation
- generated skills should be easy to test against real repo tasks

### 6. Description And Triggering Quality Matter

Anthropic treats the skill description as a core triggering mechanism.

For Superagents, that means generated skills should pay close attention to:

- when the skill should activate
- what kinds of projects or workflows it applies to
- what wording helps the Claude-side experience trigger reliably

## How These Lessons Affect Superagents

These Anthropic patterns reinforce the MVP direction without changing the core decision:

- we should learn from Anthropic's workflow design
- we should not depend on Anthropic's implementation directly

Most importantly, they strengthen the case that Superagents's builder should be:

- intent-first
- minimally inquisitive
- compositional
- iterative over time
- optimized for Claude triggering behavior

## What We Should Mirror

We should intentionally mirror these Anthropic patterns in the MVP:

### 1. Composable Skills

Superagents should treat skills as small, purpose-built building blocks that can be assembled together rather than one giant universal prompt.

### 2. Minimal Loading

The builder and runtime should favor loading only the fragments and context needed for the current task, not the entire system.

### 3. Project-Local Overrides

Generated skills should live inside the repository and take precedence over broader user-level defaults.

### 4. Claude Code As The Primary Execution Context

The first implementation should assume Claude Code is the most important target environment for skill-builder usage and generated skill consumption.

## What We Should Stay Independent From

We should not build Superagents as a thin wrapper around Anthropic-owned implementation details.

Specifically:

- we should not assume Anthropic's internal or product-level skill-builder behavior is available as a stable public dependency
- we should not require Anthropic-specific platform features beyond what a normal Claude/Claude Code user can reasonably access
- we should not encode our fragment architecture in a way that only makes sense inside Anthropic-owned tooling

Superagents should learn from Anthropic's product direction without becoming dependent on product surfaces we do not control.

## What We Should Avoid In MVP

We should explicitly avoid the following in the first release:

### 1. Cross-Platform Feature Parity

The MVP should not aim for equivalent support across Claude, OpenAI tooling, Gemini tooling, or any other ecosystem.

### 2. Deep Platform Abstraction

We do not need a full vendor-neutral runtime layer before we have a working Claude-first builder and generated-skill story.

### 3. Platform-Agnostic Marketing That Drives Platform-Agnostic Engineering

It is fine to say the architecture may broaden later. It is not fine to let that possibility force MVP design into generic mush.

## What "Agnostic Architecture" Means For MVP

For the MVP, "agnostic" should mean:

- provider capabilities are modeled cleanly
- fragment responsibilities are separated from vendor names where reasonable
- generated skills are human-readable and portable in principle

It should **not** mean:

- every platform gets a first-class implementation now
- every design decision must be optimized for hypothetical future runtimes
- Claude-specific UX is treated as a liability instead of an MVP advantage

In short:

- be Claude-first in product
- be disciplined in architecture
- do not overbuild for future platforms

## Implications For Phase 1 Issues

This decision should directly shape the early issue work.

### Implication For `#11`

Fragment schema should support a Claude-first execution model first, with only the abstraction needed to avoid obvious dead ends.

### Implication For `#12`

Generated skill layout and precedence should be designed around Claude-centric project-local behavior as the primary reference path.

### Implication For `#13`

The external capability model should stay vendor-aware enough for future expansion, but the first implementation should be biased toward the delivery workflows most likely to be used alongside Claude Code.

### Implication For `#14` And `#15`

Builder inventory and questionnaire design should prefer Claude-forward defaults when repository evidence is ambiguous, while still making assumptions explicit.

### Implication For `#17`

Provider matrix research remains useful, but broad provider coverage should not be mistaken for a requirement that MVP execute equally well on every AI platform.

## Recommended Product Boundary

For the MVP, the product boundary should be:

- **Primary target**: Claude Code users
- **Primary output**: project-local generated skills and supporting fragments
- **Primary workflow**: repo inspection, minimal questionnaire, fragment assembly, repo-local override behavior
- **Expansion path**: broader AI-platform support only after real adoption and concrete demand

## Recommendation

Superagents should proceed with:

- a **Claude-first MVP**
- a **capability-oriented internal design**
- a **deliberately deferred** broader platform-support story

This gives us the best chance of shipping something coherent, useful, and differentiated before investing in ecosystem breadth.

## References

Official Anthropic sources reviewed:

- [Claude Skills: Customize AI for your workflows](https://www.anthropic.com/news/skills?t=n)
- [Claude Code overview](https://docs.anthropic.com/en/docs/claude-code/overview)
- [Claude Code product page](https://www.anthropic.com/product/claude-code)
