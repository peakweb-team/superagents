# Peakweb Agency Agents Roadmap

This roadmap defines what Peakweb Agency Agents is trying to become beyond the original `agency-agents` roster.

The short version:

- `agency-agents` gives users a strong library of specialist personas.
- Peakweb Agency Agents aims to add a reusable execution layer on top of that roster.
- The centerpiece of that execution layer is a **skill builder** that assembles project-specific skills from reusable fragments.

## Product Direction

Peakweb Agency Agents should help teams move from:

- a generic library of agents

to:

- a project-aware operating layer that reflects how the team actually ships software

That means the system should understand:

- what task system the team uses, if any
- what work is available across the current ticket or brief portfolio
- how task dependencies and readiness affect execution order
- where code review happens
- how PRs are raised and reviewed
- how many agents a task really needs
- how context and models should be used efficiently
- how validation evidence is gathered, stored, and linked back to human workflow systems

## Direct-Brief Bootstrap

Direct-brief bootstrap is a delivery flow that starts from a human brief without a formal ticket system, then progressively structures execution, review, and validation artifacts as the work becomes more concrete.

## Core Contract

Peakweb Agency Agents will **not** auto-configure third-party tools.

Instead:

- users configure access to their systems through MCP, CLI tools, environment variables, repo conventions, or other supported mechanisms
- Peakweb provides fragment logic, builder behavior, setup guidance, and validation expectations
- generated skills assume integrations are already available and correctly configured

This is an important boundary. We can help users connect systems, but we are not promising automatic provisioning or vendor setup.

## Design Principles

- **Claude-first MVP**: optimize the first release for Claude and Claude Code rather than trying to support every AI platform immediately.
- **Capabilities over vendors**: fragments should depend on shared workflow capabilities, not hardcoded brand logic.
- **Composable over monolithic**: use small fragments that can be assembled into project-specific skills.
- **Repo-local precedence**: generated skills should live in the project and override user-level defaults.
- **Smallest capable team**: orchestration should start with the minimum agent team needed for the task.
- **Efficient by default**: context use, model routing, and subtask boundaries should minimize waste.
- **Human-reviewable output**: generated skills should be easy to understand, edit, and version.

## Epics

### Epic 1: Skill Builder Foundation

Create the builder workflow that inventories a repository, asks a minimal questionnaire, and generates project-local skills from reusable fragments.

Goals:

- define the builder workflow from repo inventory through generated output
- define where generated skills live and how they override user-level skills
- define how the builder records assumptions, confidence, and unresolved questions
- define how framework releases and repo-local generated skills participate in a safe upgrade/regeneration flow
- generate project-local skills that are understandable and versionable

Non-goals:

- building a universal one-size-fits-all skill
- generating opaque machine-only output
- auto-configuring external systems
- treating repo-local generated-skill upgrades as blind file replacement without compatibility review

### Epic 2: Fragment And Assembly Architecture

Define the fragment model and assembly engine so project-specific skills can be composed from reusable building blocks.

Goals:

- define fragment types, metadata, applicability rules, and composition behavior
- distinguish generic workflow fragments from provider-specific fragments
- allow generated skills to combine multiple fragments without duplicating rules
- define validation rules for fragment compatibility and conflicts

Non-goals:

- encoding every workflow directly into the builder itself
- mixing provider logic into generic orchestration fragments
- supporting unlimited customization in v1

### Epic 3: External Integration Contract

Define the capability model that fragments can rely on when interacting with external systems.

Goals:

- define shared capabilities such as task lookup, status updates, PR creation, review requests, review feedback retrieval, and delivery signal access
- define how a project declares which configured integration satisfies each capability
- define expected fallback behavior when a capability is unavailable
- make it clear where provider-specific setup ends and Peakweb behavior begins

Non-goals:

- shipping automatic MCP or vendor provisioning
- embedding credentials or secrets management into the framework
- assuming every provider exposes the same surface area

### Epic 4: Delivery Workflow Coverage

Provide a strong starting point for the most common software-delivery platforms and review patterns in the market.

Goals:

- support major task systems such as GitHub Issues, Jira, Linear, Azure Boards, and GitLab Issues
- support [direct-brief bootstrap](#direct-brief-bootstrap) flows for greenfield or light-process projects alongside task-system-backed delivery
- keep task-system provider fragments optional companions to direct-brief intake rather than a hard prerequisite
- support major code-hosting and PR systems such as GitHub, GitLab, and Bitbucket
- support common review patterns such as native review, CodeRabbit, and layered review automation
- keep first-wave provider-fragment guidance split between task-system and code-host/review contracts (see [`docs/task-system-provider-fragment-set.md`](./docs/task-system-provider-fragment-set.md) and [`docs/code-host-review-provider-fragment-set.md`](./docs/code-host-review-provider-fragment-set.md))
- make provider selection part of builder output rather than hardcoded defaults

Non-goals:

- covering every marketplace tool in the first release
- guaranteeing identical depth for every provider on day one
- coupling support to only Peakweb's internal tool choices

### Epic 5: Team Sizing And Orchestration Strategy

Teach the system to choose the smallest capable team and coordinate work across implementation, review, and validation.

Goals:

- define canonical `solo`, `sub-agent`, and `agent-team` heuristics (see [`docs/orchestration-execution-rubric.md`](./docs/orchestration-execution-rubric.md))
- map task characteristics to likely agent roles and specialist needs
- define handoff expectations between implementers, reviewers, and validators (see [`docs/orchestration-role-handoff-contract.md`](./docs/orchestration-role-handoff-contract.md))
- keep team formation proportionate to task scope and risk

Non-goals:

- defaulting every task to a swarm
- pretending one orchestration style fits every repo
- optimizing for maximum agent count instead of delivery quality

### Epic 6: Runtime Efficiency And Model Routing

Add shared rules for context use, task scoping, and model selection across generated skills.

Goals:

- define efficient file-reading and context-loading behavior
- define when stronger models are warranted and when cheaper paths are enough
- define how to split work into bounded subtasks without duplication
- improve reliability and cost-efficiency in large repositories

Non-goals:

- hardcoding provider-specific model implementations
- forcing complex routing for small tasks
- optimizing purely for cost at the expense of correctness

### Epic 7: Installation, Packaging, And Adoption

Make the new skills layer installable, understandable, and usable alongside the existing agent roster.

Goals:

- ship the base agents and reusable skill fragments together
- document how users run the builder inside a project
- document how repo-local generated skills take precedence over user-level defaults
- provide setup guides for common integration paths without promising automation

Non-goals:

- hiding the distinction between source fragments and generated project-local output
- introducing breaking install behavior without migration guidance
- assuming all users want project-local generation immediately

### Epic 8: Documentation, Examples, And Reference Projects

Use docs and examples to show how the system behaves across different team/tool combinations.

Goals:

- document the product boundary clearly, especially around integrations
- provide example generated skills for representative stacks and workflows
- provide examples for GitHub-heavy, Jira-heavy, mixed-tool, and [direct-brief bootstrap](#direct-brief-bootstrap) environments
- make it easy for users to understand why Peakweb differs from the upstream project

Non-goals:

- relying on marketing copy alone to explain the system
- documenting only Peakweb's internal setup
- assuming users will infer the builder workflow from fragments alone

### Epic 9: Portfolio Execution And Dependency-Aware Orchestration

Move beyond single-task execution so Peakweb can reason over a queue of available work, respect dependencies, and drive progress across multiple tickets or briefs.

Goals:

- define a higher-level orchestration model that can inspect available work across a project or delivery scope
- define dependency-aware planning and execution-order rules
- define how portfolio-level orchestration invokes lower-level task executors such as `/agent-task` or `/agent-issue`
- define human-authorization boundaries for automating PR progression, review gates, and task completion steps
- support both task-system-backed portfolios and direct-brief work queues where appropriate

Non-goals:

- removing humans from prioritization or authorization-sensitive decisions
- assuming every team wants fully autonomous backlog execution
- collapsing portfolio planning and task execution into one opaque workflow

### Epic 10: Autonomous Validation, Preview Environments, And Evidence

Add stronger validation loops that can run against deploy previews, gather proof artifacts, and attach durable evidence to the human workflow even when the task system has poor native media support.

Goals:

- define how generated workflows leverage preview environments such as Vercel for validation
- define deterministic test execution patterns such as unit, integration, E2E, and Playwright-based flows
- define probabilistic or agentic testing patterns that use browser MCP or similar tooling
- define how screenshots and other proof artifacts are stored in a durable external location and linked back into issues, tickets, or PRs
- define how validation evidence influences PR readiness, review, and task completion behavior
- define a minimum evidence set for reviewable completion, such as screenshots or recordings for UI changes, deterministic test or CI artifacts, and concise execution logs or summaries for agentic validation paths
- define retention expectations for stored evidence, such as a default 90-day retention window or an equivalent project-configured object-store policy
- define traceability requirements so evidence artifacts carry stable ids and links back to the related PR, issue, ticket, or brief
- define how evidence completeness and quality map to reviewer checklists, PR readiness, and task-completion gates

Non-goals:

- hardcoding one hosting provider or evidence store as the only supported path
- replacing deterministic testing with screenshot-based review alone
- assuming every repository is ready for fully autonomous validation from day one

## Recommended Sequencing

### Phase 1

- Issue `#29` should be treated as a front-of-queue decision gate for MVP platform stance.
- Epic 1: Skill Builder Foundation
- Epic 2: Fragment And Assembly Architecture
- Epic 3: External Integration Contract

### Phase 2

- Epic 4: Delivery Workflow Coverage
- Epic 5: Team Sizing And Orchestration Strategy
- Epic 6: Runtime Efficiency And Model Routing

### Phase 3

- Epic 7: Installation, Packaging, And Adoption
- Epic 8: Documentation, Examples, And Reference Projects

### Phase 4

- Epic 9: Portfolio Execution And Dependency-Aware Orchestration
- Epic 10: Autonomous Validation, Preview Environments, And Evidence

## First Issue Candidates

Once the roadmap is agreed, the first issue batch should likely focus on:

1. Define fragment schema and metadata contract.
2. Define generated skill layout and precedence rules.
3. Define external capability model for integrations.
4. Define builder inventory workflow and confidence model.
5. Define builder questionnaire and unresolved-decision flow.
6. Define fragment assembly and conflict-resolution rules.
7. Draft provider matrix for major delivery platforms and review tools (see [`docs/provider-matrix.md`](./docs/provider-matrix.md)).

## Explicit Non-Goals For V1

To keep the first version sharp, V1 should explicitly avoid:

- auto-configuring third-party integrations
- trying to support every vendor at launch
- shipping a giant all-in-one master skill
- hiding generated behavior in ways users cannot review
- coupling the product only to Peakweb's internal tooling choices
