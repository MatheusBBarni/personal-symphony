# PRD: Improve Compozy Task Lifecycle Statuses

## Overview

Compozy-backed Symphony workflows need a trustworthy status contract, not just more status labels. Operators can already see Compozy Task Step progress and parts of run-level lifecycle state, but they still have to reconcile multiple signals to understand what a Compozy PRD Run is actually doing. The current experience can make one surface feel active, another feel blocked, and another imply pull-request readiness without making the relationship between those states explicit.

This PRD defines a full V1 operator-trust experience for Compozy PRD Runs. V1 will preserve existing Compozy Task Step progress behavior while making the relationship between task-step progress, run lifecycle state, dispatch state, and Pull Request readiness unmistakable across Runtime State, Terminal Console, and Web Dashboard. The product promise is simple: the same run should tell the same story everywhere, and that story should be accurate enough for an operator to act on without reading logs.

Primary users are workflow operators monitoring active Compozy PRD Runs. Secondary users are workflow maintainers debugging orchestration behavior and project owners checking progress without inspecting implementation details.

## Goals

- Give operators one trustworthy view of Compozy PRD Run state across Runtime State, Terminal Console, and Web Dashboard.
- Make active-state distinctions clear: planning, executing, reviewing, retrying, stalled, blocked, completed, and handoff-related states must be understandable at a glance.
- Ensure Pull Request readiness never contradicts the visible run state.
- Preserve existing Compozy Task Step progress semantics, including current-step behavior and progress counts.
- Preserve aggregate Batch Pull Request behavior: one Compozy PRD Run can become eligible for one aggregate Batch Pull Request in batch mode, not one PR per task step.
- Reduce operator dependence on logs, task files, and branch inspection for ordinary status interpretation.

Measurable targets:

| Goal | Target |
| --- | --- |
| Cross-surface consistency | 100% of representative lifecycle transitions appear consistently across Runtime State, Terminal Console, and Web Dashboard within one poll cycle |
| Readiness consistency | 0 cases where visible PR readiness contradicts visible run state in acceptance scenarios |
| Active-state clarity | Operators can distinguish planning, execution, review, retrying, and blocked states in under 30 seconds during dogfood walkthroughs |
| Task-step compatibility | 0 regressions in existing Compozy Task Step current-step behavior and counts |
| Aggregate PR correctness | 0 per-step pull requests in batch mode |

## User Stories

### Workflow Operator

1. As a workflow operator, I want the same Compozy PRD Run to present the same status story in Runtime State, Terminal Console, and Web Dashboard, so that I do not have to cross-check multiple surfaces to know what is happening.
2. As a workflow operator, I want to distinguish planning, executing, reviewing, retrying, stalled, and blocked states at a glance, so that I know whether work is progressing normally or needs attention.
3. As a workflow operator, I want Pull Request readiness to match the visible run state, so that I never assume blocked, failed, skipped, or handoff-failed work is ready for review.
4. As a workflow operator, I want a concise reason when a run is blocked, not PR-ready, or stuck in handoff, so that I know what broad kind of action is needed next.
5. As a workflow operator, I want one aggregate Batch Pull Request after a successful Compozy PRD Run, so that review happens on the combined outcome rather than on internal task-step boundaries.

### Workflow Maintainer

6. As a workflow maintainer, I want the product contract to distinguish task-step progress, run lifecycle, dispatch state, and PR readiness, so that status problems can be understood and debugged without guesswork.
7. As a workflow maintainer, I want active-state and terminal-state examples documented consistently, so that operator language and expected system behavior stay aligned.
8. As a workflow maintainer, I want V1 to preserve current Compozy Task Step semantics, so that lifecycle improvements do not break existing progress interpretation.

### Project Owner

9. As a project owner, I want the Web Dashboard to show a trustworthy high-level run state, so that I can follow progress without asking an operator to interpret logs.
10. As a project owner, I want completed, blocked, failed, skipped, and handoff-related outcomes to be clearly distinct, so that I can tell the difference between progress, attention, and review readiness.

## Core Features

### F1. Cross-surface transition contract

V1 must define one operator-facing contract for Compozy PRD Run status. The contract must describe how four connected layers relate:

- Compozy Task Step progress
- Compozy PRD Run lifecycle state
- Dispatch state
- Pull Request readiness and handoff state

This contract must hold across Runtime State, Terminal Console, and Web Dashboard. Different surfaces may present different levels of detail, but they must not contradict each other about the state of the same run.

### F2. Active-state clarity

V1 must make active states easy to distinguish. The operator should be able to tell whether a run is:

- planning
- executing
- reviewing
- retrying
- stalled or blocked

This feature matters most during live monitoring. It must reduce the need to inspect logs or task files just to understand whether the run is healthy and moving forward.

### F3. Attention and failure clarity

V1 must make attention-oriented outcomes unmistakable. Blocked, failed, skipped, merge-attention, protected-path-attention, and non-retryable completion outcomes must not look like normal progress or successful completion.

These states must carry concise operator-facing reasons that explain why the run is no longer progressing normally or why it requires intervention.

### F4. Pull Request readiness consistency

V1 must keep Pull Request readiness aligned with visible run state. A run that is blocked, failed, skipped, not ready, or in a failed handoff state must never appear ready for an aggregate Batch Pull Request.

When automatic Batch Pull Request creation is enabled, successful runs may become eligible for one aggregate Batch Pull Request only after the run is visibly complete and safe for handoff.

### F5. Backward-compatible task-step progress

V1 must preserve existing Compozy Task Step progress behavior. Operators must continue to see current step, completed count, failed count, skipped count, and total count in ways that remain understandable and stable.

The PRD intentionally improves trust at the run level without redefining the product meaning of Compozy Task Step execution progress.

### F6. Operator-facing documentation and examples

V1 must update documentation and examples so operators can quickly understand:

- the difference between task-step progress and run lifecycle
- what active states mean
- what attention-oriented states mean
- why visible completion does or does not imply PR readiness
- how aggregate Batch Pull Request behavior works for Compozy PRD Runs

Documentation should include representative examples for retry, blocked, review, successful completion, and handoff failure scenarios.

## User Experience

### Primary flow: active healthy run

1. The operator opens Runtime State, Terminal Console, or Web Dashboard.
2. The run appears as one Compozy PRD Run with separate but non-conflicting signals for progress, lifecycle, and readiness.
3. The operator can tell whether the run is planning, executing, or reviewing.
4. If the run moves forward, the surfaces reflect the same transition within one poll cycle.
5. The operator does not need to inspect logs to decide whether the run is actively progressing.

### Primary flow: active run under stress

1. The operator sees a run that is retrying, stalled, blocked, or otherwise not progressing normally.
2. The surfaces make that state distinct from normal active execution.
3. The operator sees a concise reason or category of attention.
4. The operator can tell whether the issue affects run progress, PR readiness, or both.

### Primary flow: completed or handoff-ready run

1. The operator sees the run complete successfully.
2. The surfaces make completion distinct from PR readiness and from PR handoff.
3. If automatic Batch Pull Request creation is enabled, the run becomes eligible for one aggregate handoff.
4. If handoff succeeds, the operator sees that outcome consistently.
5. If handoff fails, the operator sees a handoff-related state instead of a misleading successful-ready state.

### UX principles

- The same run must not tell conflicting stories on different surfaces.
- Active states should be faster to interpret than logs.
- Attention-oriented states should be visually and semantically distinct from healthy progress.
- Pull Request readiness should be explicit, not inferred from task-step counts alone.
- Task-step progress remains useful context, not the sole explanation of run health.
- Product terminology should stay consistent with Compozy PRD Run, Compozy Task Step, Runtime State, Terminal Console, Web Dashboard, and Batch Pull Request.

## High-Level Technical Constraints

- V1 must preserve the product boundary that one `.compozy/tasks/<slug>/` directory represents one Compozy PRD Run.
- V1 must preserve current Compozy Task Step progress semantics from the operator’s perspective.
- V1 must preserve aggregate Batch Pull Request behavior in batch mode.
- V1 must not loosen Protected Trunk Branch safety behavior or auto-merge safeguards.
- V1 must not require GitHub API access for Compozy-backed Local Issue Tracker visibility.
- V1 must use the existing glossary and current product terminology consistently.
- V1 documentation must remain secret-free and must not include token values or local environment contents.

## Non-Goals (Out of Scope)

- **Per-step Symphony issues** — Compozy Task Steps remain internal ordered progress within one Compozy PRD Run.
- **Per-step pull requests** — Batch mode remains aggregate-only.
- **Configurable lifecycle schemas** — V1 does not become a user-defined workflow platform.
- **Lifecycle analytics dashboards** — historical trend analysis and bottleneck reporting are deferred.
- **Guided repair controls** — V1 explains attention states but does not add repair actions.
- **Changing Pull Request Policy defaults** — automatic PR behavior remains opt-in.
- **Replacing current tracker models** — GitHub, minibeads, and Compozy-backed Local Issue Tracker boundaries remain intact.

## Phased Rollout Plan

### MVP (Phase 1): Cross-surface operator trust

Included:

- One explicit transition contract across task-step progress, run lifecycle, dispatch state, and PR readiness
- Active-state clarity for planning, execution, review, retrying, and blocked outcomes
- Cross-surface consistency across Runtime State, Terminal Console, and Web Dashboard
- Pull Request readiness that never contradicts visible run state
- Backward-compatible Compozy Task Step progress behavior
- Documentation and examples for representative status scenarios

Success criteria to proceed:

- Operators can identify the active state and readiness state from any current surface
- Representative transitions remain consistent across surfaces within one poll cycle
- Blocked, failed, skipped, and handoff-failed outcomes do not appear review-ready
- Existing task-step progress remains understandable and unchanged in meaning

### Phase 2: Richer reasons and transition history

Potential additions:

- More granular attention and not-ready reason categories
- Human-readable transition history
- Better comparison between current step, lifecycle phase, and readiness in the dashboard

Success criteria to proceed:

- Operators still need historical context after V1
- V1 status semantics remain stable enough to extend without changing the core contract

### Phase 3: Compozy run control plane

Potential additions:

- Bottleneck analytics
- Guided operator repair suggestions
- Higher-level run summaries for project owners
- Expanded lifecycle views if repeated workflows justify them

Long-term success criteria:

- Operators use Symphony surfaces as the first source of truth for run health
- Project owners can follow Compozy-backed work without operator translation

## Success Metrics

| Metric | Target | Measurement |
| --- | --- | --- |
| Cross-surface consistency | 100% of representative lifecycle transitions align across Runtime State, Terminal Console, and Web Dashboard within 1 poll cycle | Acceptance scenarios and dogfood walkthroughs |
| Readiness consistency | 0 contradictory states between visible run state and visible PR readiness | Acceptance scenarios for active, blocked, failed, skipped, completed, and handoff outcomes |
| Active-state comprehension | < 30 seconds to identify whether a run is planning, executing, reviewing, retrying, or blocked | Timed operator walkthroughs |
| Task-step compatibility | 0 regressions in current-step behavior and visible step counts | Existing Compozy progress checks plus regression acceptance scenarios |
| Aggregate PR correctness | 0 per-step pull requests and no more than 1 aggregate Batch Pull Request per successful run | Pull-request handoff records and dogfood verification |
| Attention clarity | 100% of blocked, failed, skipped, and handoff-failed scenarios show a concise reason | Acceptance scenarios across representative attention outcomes |

## Risks and Mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Surface drift leaves one view behind the others | Operators lose trust and return to logs | Make cross-surface consistency a core success metric, not a polish task |
| Status language blurs progress, lifecycle, and readiness | Operators misread the state of work | Define and document the boundary between each status layer with examples |
| Broader scope creates regression pressure on step progress | Lifecycle improvements could break current progress interpretation | Keep no-regression task-step behavior as a hard V1 constraint |
| Operators over-trust labels without reasons | Attention states may still be hard to act on | Require concise reasons for blocked, not-ready, failed, skipped, and handoff-failure scenarios |
| Familiar users resist new distinctions | Adoption slows if the model feels more complex | Keep the vocabulary disciplined and show the same story everywhere |

## Architecture Decision Records

- [ADR-001: Represent Compozy lifecycle at PRD Run level](adrs/adr-001.md) — Lifecycle status belongs to the Compozy PRD Run, while Compozy Task Step statuses remain execution progress.
- [ADR-002: Use full V1 operator trust as the PRD product approach](adrs/adr-002.md) — V1 must expose lifecycle and PR readiness across current operator surfaces.
- [ADR-003: Persist dispatch-aware Compozy lifecycle in Runtime Home](adrs/adr-003.md) — Runtime Home lifecycle metadata survives restarts while task-step frontmatter remains the progress source.
- [ADR-004: Treat Compozy statuses as an explicit transition contract](adrs/adr-004.md) — V1 must define and validate the mapping between task-step status, run lifecycle state, dispatch state, and PR readiness.
- [ADR-005: Use a cross-surface transition contract as the PRD approach](adrs/adr-005.md) — V1 prioritizes consistent status meaning across Runtime State, Terminal Console, and Web Dashboard without regressing task-step progress.

## Open Questions

- What exact operator-facing label should represent active execution on each surface: `in_execution`, `in progress`, `running`, or a mixed presentation with one canonical meaning?
- Should `Human attention` remain a dispatch-facing label while lifecycle continues to present `blocked` as the operator-facing lifecycle category?
- Should handoff failure appear primarily as a PR-readiness problem, a lifecycle phase, or both?
- What minimum set of example scenarios should documentation include for retrying, blocked, review, successful completion, and handoff failure states?
