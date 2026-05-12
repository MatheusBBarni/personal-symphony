# PRD: Improve Compozy Task Lifecycle Statuses

## Overview

Compozy-backed Symphony workflows need trustworthy run-level status. Operators can already see Compozy Task Step progress, but they cannot reliably tell whether the overall Compozy PRD Run is being planned, executed, reviewed, blocked, failed, skipped, or moving through Batch Pull Request handoff. That ambiguity forces operators to inspect logs, branches, task files, and dashboard fragments to understand the real state of a run.

This PRD defines a full V1 operator-trust experience for Compozy PRD Run lifecycle visibility. V1 keeps Compozy Task Step statuses as execution progress, adds a clear run-level lifecycle for Stage Agent phases and pull-request readiness, and aligns Runtime State, Terminal Console, and Web Dashboard output. The product promise is simple: every Compozy PRD Run should have a trustworthy visible state, and one aggregate Batch Pull Request should be eligible only when the run has successfully completed and is safe to hand off.

Primary users are workflow operators and developers running Compozy-backed Symphony workflows. Secondary users are workflow maintainers debugging orchestration behavior and project owners checking progress without reading implementation logs.

## Goals

- Give operators a trustworthy Compozy PRD Run lifecycle state across Runtime State, Terminal Console, and Web Dashboard.
- Distinguish Compozy PRD Run lifecycle from Compozy Task Step execution progress.
- Make planner, engineer, reviewer, blocked/attention, failed, skipped, completed, and pull-request handoff states visible at the run level.
- Show a distinct not-PR-ready state with a reason when a run is terminal or stopped but should not open a Batch Pull Request.
- Preserve aggregate Batch Pull Request behavior: no per-step pull requests, and at most one eligible Batch Pull Request for a successfully completed Compozy PRD Run when the Pull Request Policy enables it.
- Preserve existing Compozy Task Step progress semantics and counts.

Measurable targets:

| Goal | Target |
| --- | --- |
| Lifecycle coverage | 100% of active Compozy PRD Runs show one valid run-level lifecycle state. |
| Surface alignment | 100% of lifecycle states visible in Runtime State also appear coherently in Terminal Console and Web Dashboard. |
| PR correctness | 0 per-step pull requests in batch mode. |
| Aggregate PR eligibility | Exactly 1 eligible Batch Pull Request per successfully completed Compozy PRD Run when automatic PR creation is enabled. |
| Diagnostic clarity | 100% of blocked or not-PR-ready runs show a reason within one poll cycle. |
| Operator comprehension | Operators can answer the run state and PR readiness status in under 2 minutes during self-dogfooding checks. |

## User Stories

### Workflow Operator / Developer

1. As a workflow operator, I want each Compozy PRD Run to show whether it is planning, executing, reviewing, blocked, completed, failed, skipped, or in pull-request handoff, so that I can trust the current status without reading logs.
2. As a workflow operator, I want `in_planning` to mean planner-stage work is active, so that I know the run is not yet ready for engineering work.
3. As a workflow operator, I want `in_review` to mean reviewer-stage work is active, so that I know the run is being validated rather than still being implemented.
4. As a workflow operator, I want a not-PR-ready state with a reason, so that I understand why a terminal or stopped run did not open a Batch Pull Request.
5. As a workflow operator, I want one aggregate Batch Pull Request after successful run completion, so that I review the combined result of the Compozy PRD Run instead of many internal task-step changes.

### Workflow Maintainer

6. As a workflow maintainer, I want lifecycle diagnostics for missing, invalid, blocked, or skipped transitions, so that I can debug orchestration behavior from product surfaces before inspecting files.
7. As a workflow maintainer, I want Compozy Task Step progress to remain stable, so that existing task counts and retry status remain useful while run-level lifecycle improves.
8. As a workflow maintainer, I want pull-request handoff failures to remain visible as handoff failures, so that I can separate run completion from downstream PR availability.

### Project Owner

9. As a project owner, I want the Web Dashboard to show trustworthy Compozy PRD Run state, so that I can track progress without asking the operator for log interpretation.
10. As a project owner, I want failed, skipped, blocked, and not-PR-ready runs to be clearly distinct from completed PR-ready runs, so that I do not assume unfinished work is ready for review.

## Core Features

### F1. Run-level lifecycle status

V1 must expose a run-level lifecycle for each Compozy PRD Run. The lifecycle must describe the status of the overall work item, not the status of each Compozy Task Step.

Required lifecycle categories:

- Not started or pending
- In planning
- In execution
- In review
- Blocked or attention needed
- Completed
- Failed
- Skipped
- Pull-request handoff in progress or completed
- Not PR-ready with a reason

The user-facing copy may use exact labels that match existing product language, but the experience must let operators distinguish each category.

### F2. Stage Agent phase visibility

V1 must show planner, engineer, and reviewer ownership at the run level. Operators should see `in_planning` when planner-stage work is active and `in_review` when reviewer-stage work is active. Engineering work should remain distinguishable from planning and review.

This feature must not imply that Compozy Task Steps are separate Symphony issues. It should reinforce that one Compozy PRD Run is the work item and the task steps are ordered progress within it.

### F3. Not-PR-ready state with reason

V1 must explain why a Compozy PRD Run cannot open a Batch Pull Request when task-step progress alone might look terminal. Examples include failed task steps, skipped task steps, blocked or attention states, unsafe final integration, disabled pull-request policy, missing pull-request readiness requirements, or handoff failures.

The reason should be concise and operator-facing. It should answer what stopped the run from being PR-ready and what broad category of action is needed, without requiring implementation details.

### F4. Aggregate Batch Pull Request readiness

V1 must preserve aggregate Batch Pull Request behavior. A Compozy PRD Run should never create a pull request for every Compozy Task Step in batch mode. When the Pull Request Policy enables automatic Batch Pull Requests, the run should become eligible for one aggregate Batch Pull Request only after successful run completion and safe final integration.

Failed, skipped, blocked, attention, or not-PR-ready runs must not appear as successfully PR-ready.

### F5. All-surface operator visibility

V1 must show the new lifecycle and PR readiness information in all current operator surfaces:

- Runtime State
- Terminal Console
- Web Dashboard

The three surfaces should use consistent language and should not contradict one another. Runtime State may be the most structured view, but Terminal Console and Web Dashboard must give operators enough information to answer the current lifecycle state and PR readiness status.

### F6. Backward-compatible Compozy Task Step progress

V1 must preserve existing Compozy Task Step progress behavior. Operators should still see current step, completed count, failed count, skipped count, and total count. Existing meanings for task-step progress should not change.

The PRD intentionally separates run lifecycle from task-step execution progress so that status cleanup does not break current progress interpretation.

### F7. Documentation and examples

V1 must update user-facing documentation for Compozy-backed Local Issue Tracker behavior. Documentation should explain:

- The difference between Compozy PRD Run lifecycle and Compozy Task Step progress.
- What `in_planning`, execution, `in_review`, completed, failed, skipped, blocked, not-PR-ready, and pull-request handoff states mean.
- Why failed or skipped terminal task-step progress does not imply Batch Pull Request readiness.
- How aggregate Batch Pull Request behavior works for Compozy PRD Runs.

## User Experience

### Primary flow: healthy Compozy PRD Run

1. The operator starts or observes a Compozy-backed Symphony run.
2. The run appears as a Compozy PRD Run, not as separate task-step issues.
3. When planner-stage work is active, the run shows `in_planning` or equivalent planning copy.
4. When task-step execution is active, the run shows execution state and current Compozy Task Step progress.
5. When reviewer-stage work is active, the run shows `in_review` or equivalent review copy.
6. When the run completes successfully and is safe for handoff, the run shows completed and PR-ready or pull-request handoff state.
7. If automatic Batch Pull Request creation is enabled, the operator sees one aggregate Batch Pull Request handoff record.

### Primary flow: terminal but not PR-ready

1. The operator sees that all task steps are terminal or no more task steps are runnable.
2. The run does not silently imply PR readiness.
3. The run shows a not-PR-ready state with a concise reason.
4. Terminal Console and Web Dashboard surface the same outcome as Runtime State.
5. The operator knows whether the run failed, skipped, needs attention, lacks PR policy readiness, or encountered handoff failure.

### UX principles

- Do not make operators infer run state from task-step counts alone.
- Do not hide blocked or not-PR-ready states behind generic progress labels.
- Do not present failed or skipped runs as completed work ready for review.
- Use the glossary terms Compozy PRD Run, Compozy Task Step, Batch Pull Request, Runtime State, Terminal Console, Web Dashboard, and Pull Request Policy consistently.
- Favor short operator-facing reason text over verbose debug output.
- Keep all status text readable in terminal and dashboard contexts.

## High-Level Technical Constraints

- V1 must preserve the product boundary that a Compozy PRD Run is the Local Issue Tracker work item and Compozy Task Steps are ordered progress within that work item.
- V1 must preserve existing Compozy Task Step progress statuses and counts from an operator perspective.
- V1 must not change Pull Request Policy defaults. Automatic Batch Pull Request creation remains disabled unless already configured.
- V1 must preserve batch-mode semantics. Batch Pull Requests use the Loop-Start Branch and remain aggregate, not per-step.
- V1 must not weaken Protected Trunk Branch safeguards or auto-merge safety behavior.
- V1 must not require GitHub API access for Compozy-backed Local Issue Tracker status visibility.
- V1 documentation must not include secrets, token values, webhook URLs, or local environment contents.

## Non-Goals (Out of Scope)

- **Per-step Symphony issues** — Compozy Task Steps remain internal progress inside one Compozy PRD Run.
- **Per-step pull requests** — V1 preserves aggregate Batch Pull Request behavior in batch mode.
- **Configurable lifecycle schemas** — Custom user-defined lifecycle workflows are deferred.
- **Lifecycle analytics dashboards** — Bottleneck analytics, trend charts, and historical reporting are out of scope.
- **Guided repair automation** — V1 explains blocked and not-PR-ready states but does not add new repair controls.
- **Changing Pull Request Policy defaults** — V1 does not turn on automatic PR creation by default.
- **Changing Task Pull Request mode** — V1 does not redefine task-mode pull-request behavior.
- **Protected Trunk Branch auto-merge changes** — V1 does not loosen protected branch behavior.
- **Replacing current tracker models** — V1 does not replace GitHub, minibeads, or Compozy-backed Local Issue Tracker models.

## Phased Rollout Plan

### MVP (Phase 1): Full V1 operator trust

Included:

- Run-level lifecycle categories for Compozy PRD Runs.
- Stage Agent phase visibility for planning, execution, and review.
- Not-PR-ready state with concise operator-facing reason.
- Aggregate Batch Pull Request readiness behavior for successful Compozy PRD Runs.
- Lifecycle and PR readiness visibility across Runtime State, Terminal Console, and Web Dashboard.
- Backward-compatible Compozy Task Step progress display.
- Documentation updates for users and operators.

Success criteria to proceed:

- Operators can identify the run lifecycle state from every current operator surface.
- Failed, skipped, blocked, and not-PR-ready runs are visibly distinct from successful PR-ready runs.
- Batch mode never creates per-step pull requests.
- Existing Compozy Task Step progress remains understandable and accurate.

### Phase 2: Lifecycle history and richer diagnostics

Potential additions:

- Human-readable lifecycle transition history.
- More detailed blocked and not-PR-ready reason categories.
- Improved dashboard affordances for comparing current step, lifecycle phase, and PR readiness.

Success criteria to proceed:

- Operators still need historical context after V1 to diagnose recurring workflow stalls.
- V1 lifecycle fields prove stable enough to support history without changing user-facing semantics.

### Phase 3: Compozy Run Control Plane

Potential additions:

- Bottleneck analytics.
- Guided repair suggestions.
- Advanced run summaries for project owners.
- Configurable lifecycle views if repeated real workflows require them.

Long-term success criteria:

- Operators use Symphony surfaces instead of logs as the first place to diagnose Compozy run health.
- Project owners can track Compozy-backed work without operator translation.

## Success Metrics

| Metric | Target | Measurement |
| --- | --- | --- |
| Lifecycle state coverage | 100% of active Compozy PRD Runs expose a valid lifecycle category | Self-dogfooding checks and acceptance coverage for planning, execution, review, blocked, failed, skipped, completed, and handoff states |
| Surface consistency | 100% agreement between Runtime State, Terminal Console, and Web Dashboard on lifecycle category and PR readiness | QA comparison of the three operator surfaces during representative runs |
| Not-PR-ready clarity | 100% of terminal but non-ready runs show a reason | Acceptance scenarios for failed, skipped, blocked, policy-disabled, and handoff-failure outcomes |
| Aggregate PR correctness | 0 per-step pull requests in batch mode | Pull-request handoff records and manual dogfood verification |
| Eligible PR count | No more than 1 aggregate Batch Pull Request per successfully completed Compozy PRD Run | Pull-request handoff records for completed runs |
| Operator comprehension | Under 2 minutes to identify state and PR readiness in a dogfood scenario | Timed operator walkthrough using dashboard and terminal output |
| Backward compatibility | 0 regressions in current Compozy Task Step progress interpretation | Existing Compozy progress checks plus user-visible acceptance scenarios |

## Risks and Mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Status labels become decorative instead of trustworthy | Operators may make wrong decisions from misleading state | Require each visible lifecycle category to have clear user meaning and acceptance scenarios. |
| Users confuse task-step terminal progress with PR readiness | Failed or skipped work may appear ready for review | Add a distinct not-PR-ready state with reason and keep PR readiness separate from task-step counts. |
| All-surface visibility expands into dashboard redesign | V1 may become too large | Limit V1 to current operator surfaces and required lifecycle or readiness fields. |
| Operators expect repair controls after seeing blocked reasons | Product promise may exceed V1 scope | Document diagnostics-only behavior and defer guided repair to Phase 3. |
| Pull-request handoff failures are mistaken for failed work | Operators may rerun the wrong part of the workflow | Show handoff failure as a separate readiness or handoff outcome, not as completed implementation work. |
| Existing Compozy users see unfamiliar states | Adoption friction | Use documentation and consistent labels to explain the difference between run lifecycle and task-step progress. |

## Architecture Decision Records

- [ADR-001: Represent Compozy lifecycle at PRD Run level](adrs/adr-001.md) — Lifecycle status belongs to the Compozy PRD Run, while Compozy Task Step statuses remain execution progress; aggregate Batch Pull Requests require successful run completion plus safe final integration.
- [ADR-002: Use full V1 operator trust as the PRD product approach](adrs/adr-002.md) — V1 must expose lifecycle and PR readiness across Runtime State, Terminal Console, and Web Dashboard while deferring analytics and repair automation.

## Open Questions

- What exact user-facing label should represent the execution phase: `in_progress`, `in_execution`, or existing product copy.
- What exact user-facing label should represent pull-request handoff: `pr_handoff`, `opening_pr`, `pr_ready`, or existing product copy.
- Should pull-request handoff failure appear as part of not-PR-ready state, as its own handoff state, or as both.
- What concise reason text should each blocked or not-PR-ready category use in Terminal Console and Web Dashboard.
- Which self-dogfooding scenario should be the first acceptance walkthrough for the under-2-minute operator comprehension target.
