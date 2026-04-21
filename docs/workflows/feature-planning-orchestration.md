# Feature Planning Orchestration Workflow

Use this workflow when a feature needs a reusable planning pass before implementation. It produces the same pair of artifacts used for the class enrollment roster work:

- `docs/features/<feature-slug>/implementation-plan.md`
- `docs/features/<feature-slug>/implementation-tasks.md`

The workflow is intentionally role-based. The orchestrator owns context, file writes, and final integration. Subagents provide role-specific judgement and review.

## Entry Point

The orchestrator starts by asking the user what feature to plan and what supporting information is available.

Ask this before spawning subagents:

```text
Which feature do you want to plan?

Please include any available context:
- feature name or short slug
- relevant docs, screenshots, specs, experiments, tickets, or reference implementations
- target app/module
- known constraints, non-goals, deadlines, or security/privacy requirements
- whether you want only planning artifacts or implementation afterward too
```

If the user's first message already includes enough context, do not ask again. Restate the inferred feature slug and proceed.

## Output Location

Default output folder:

```text
docs/features/<feature-slug>/
```

If the folder does not exist, create it. If it already contains screenshots, specs, or text descriptions, read them before drafting. If `implementation-plan.md` or `implementation-tasks.md` already exists, update it instead of creating a duplicate.

## Roles

### Orchestrator

Responsibilities:

- Ask the intake question.
- Locate and read relevant local docs, screenshots, experiments, reference apps, and API definitions.
- Create a concise context packet for subagents.
- Spawn role subagents only after enough context exists.
- Integrate role outputs into final artifacts.
- Resolve conflicts between PM, lead, and senior engineer recommendations.
- Keep scope aligned with the user's feature and repository conventions.
- Write files with `apply_patch`.
- Final response includes changed files and unresolved questions.

### Lead Engineer Subagent

Responsibilities:

- Own technical architecture, implementation strategy, data flow, API shape, storage choices, security constraints, sequencing, and engineering risks.
- Prefer existing app patterns and service composition.
- Identify reusable code from reference implementations or experiments.
- Call out open technical decisions and proposed defaults.
- Review the senior engineer task list after it is drafted.

### PM Subagent

Responsibilities:

- Own product framing, users, jobs-to-be-done, MVP boundaries, non-goals, copy tone, acceptance criteria, edge states, and success signals.
- Challenge ambiguous or misleading UX states.
- Ensure the plan avoids fake data and preserves user trust.
- Keep the feature scoped to the user value, not implementation convenience.

### Senior Engineer Subagent

Responsibilities:

- Review the integrated plan for implementability.
- Convert the plan into PR-sized implementation tasks.
- Include file-level targets, acceptance criteria, tests, verification steps, and rollout order.
- Identify missing dependencies, build-system work, test gaps, and privacy/security release gates.

## Orchestration Sequence

### Step 1 - Intake

Ask the entry-point question unless the feature context is already clear.

Expected result:

- feature name
- feature slug
- feature folder
- source materials to read
- constraints and non-goals

### Step 2 - Context Collection

The orchestrator reads the relevant materials locally.

Minimum context to gather:

- feature docs and images in `docs/features/<feature-slug>/`
- related requirements in `docs/requirements/`
- current app structure for views, models, services, and composition
- reference app patterns if requested
- old app/API definitions if requested
- relevant experiments if requested

If context is missing, continue with explicit assumptions unless the missing information blocks planning.

### Step 3 - Lead Engineer And PM Plan Drafts

Spawn Lead Engineer and PM subagents in parallel when subagents are available.

Lead Engineer prompt:

```text
You are the Lead Engineer for <feature-name>.

Using the context below, draft the technical implementation plan sections for this feature.

Focus on:
- existing app patterns to follow
- data models and storage
- API/service changes
- view model structure
- UI integration points
- security/privacy constraints
- sequencing
- risks and mitigations
- technical open questions with proposed defaults

Do not write files. Return structured markdown sections that can be integrated into implementation-plan.md.

Context:
<context-packet>
```

PM prompt:

```text
You are the Product Manager for <feature-name>.

Using the context below, draft the product plan sections for this feature.

Focus on:
- product intent
- primary users
- user stories
- MVP scope
- explicit non-goals
- copy and tone
- screen and edge states
- acceptance criteria
- success signals
- product risks and mitigations
- product open questions with proposed defaults

Do not write files. Return structured markdown sections that can be integrated into implementation-plan.md.

Context:
<context-packet>
```

If subagents are unavailable, the orchestrator performs both role passes sequentially and notes that in the final response.

### Step 4 - Integrate Implementation Plan

The orchestrator writes:

```text
docs/features/<feature-slug>/implementation-plan.md
```

Recommended structure:

```text
# <Feature Name> - Implementation Plan

Role: Lead Engineer and PM, integrated by orchestrator

## Upfront Questions
## References Read
## Product Intent
## PM Product Frame
## MVP Scope
## Key Decisions
## Data Model
## API And Services
## View Model / State Model
## Product States
## UI Plan
## Navigation
## Dependencies And Sequencing
## Integration Steps
## Tests
## Manual Acceptance
## Risks And Mitigations
## Definition Of Done
```

Plan integration rules:

- Open questions must include proposed defaults.
- Technical and product recommendations should not conflict silently.
- Any server/API assumption must name the source or mark itself as an assumption.
- Privacy/security constraints must be stated as release gates when relevant.
- Avoid planning fake data as production behavior.

### Step 5 - Senior Engineer Task Draft

Spawn the Senior Engineer subagent after the plan exists.

Senior Engineer prompt:

```text
You are the Senior Engineer reviewing the integrated plan for <feature-name>.

Create implementation tasks from the plan.

Focus on:
- PR-sized delivery slices
- task ordering and dependencies
- owner role
- files likely to change
- exact work to do
- acceptance criteria per task
- tests and manual QA
- build-system/resource tasks
- privacy/security checks
- optional follow-ups separated from must-ship work

Do not write files. Return structured markdown for implementation-tasks.md.

Integrated plan:
<implementation-plan-content>
```

### Step 6 - Lead Review Of Tasks

Send the senior task draft to the Lead Engineer subagent for review.

Lead review prompt:

```text
You are the Lead Engineer for <feature-name>.

Review the Senior Engineer implementation task draft against the implementation plan.

Amend or flag:
- missing dependencies
- incorrect sequencing
- risky assumptions
- files or targets likely omitted
- missing tests
- missing privacy/security gates
- tasks that should be optional rather than must-ship

Return concrete amendments only.

Implementation plan:
<implementation-plan-content>

Task draft:
<implementation-task-draft>
```

The orchestrator integrates amendments into the final task document.

### Step 7 - Write Implementation Tasks

The orchestrator writes:

```text
docs/features/<feature-slug>/implementation-tasks.md
```

Recommended structure:

```text
# <Feature Name> - Implementation Tasks

Role: Senior Engineer, reviewed and amended by Lead Engineer

Source plan: docs/features/<feature-slug>/implementation-plan.md

## Working Assumptions
## Delivery Slices
## Task 0 - Confirm Defaults And Guardrails
## Task 1 - ...
## Optional Follow-Up Tasks
## Lead Review Amendments Integrated
```

Task quality bar:

- Every task has owner, files, goal, work, and acceptance criteria.
- Tasks are ordered so earlier PRs provide useful standalone value.
- Tests are task-specific and targeted.
- Build-system membership/resource-copying tasks are explicit for Xcode projects.
- Privacy/security checks are explicit when local-only or sensitive data is involved.
- Optional follow-ups cannot block must-ship behavior.

### Step 8 - Final Validation

Before final response:

- Check `git status --short`.
- Ensure new docs are ASCII-only unless the repo/doc already requires Unicode.
- Confirm paths and cross-links are correct.
- Confirm no app code was changed unless the user asked for implementation.
- Summarize files changed and any unresolved questions.

## Subagent Context Packet Template

Use this packet for all role subagents:

```text
Feature: <feature-name>
Slug: <feature-slug>
Output folder: docs/features/<feature-slug>

User request:
<original-user-request>

Relevant source files/docs read:
<bullet-list-of-paths>

Current app patterns:
<summary>

Relevant API/reference findings:
<summary>

Relevant experiment findings:
<summary>

Constraints:
<summary>

Non-goals:
<summary>

Known open questions:
<summary>
```

Keep the packet concise. Link paths; do not paste entire source files.

## Conflict Resolution

When role outputs disagree:

- Security/privacy beats convenience.
- Existing app patterns beat new abstractions.
- User-stated requirements beat inferred preferences.
- MVP scope beats optional polish.
- Lead Engineer owns technical feasibility.
- PM owns user value and language.
- Orchestrator owns final integrated artifact.

Document material tradeoffs in the plan rather than hiding them.

## Final Response Template

```text
Created the reusable planning artifacts for <feature-name>.

Changed:
1. docs/features/<feature-slug>/implementation-plan.md
2. docs/features/<feature-slug>/implementation-tasks.md

The workflow used:
- Lead Engineer technical plan
- PM product plan
- Senior Engineer task breakdown
- Lead Engineer task review/amendments

Open questions:
- <question or "None">

Next useful step: confirm the upfront questions, then implementation can begin.
```
