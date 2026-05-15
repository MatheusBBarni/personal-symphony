/goal {"kind":"Stage Goal Context","issue_identifier":"compozy:improve-compozy-task-statuses","title":"Compozy PRD run: improve-compozy-task-statuses","description":null,"comments":[],"url":null,"current_project_status":"in_review","labels":[],"priority":null,"blocker_references":[],"attempt":1,"stage_agent_name":"reviewer"}

---

You are the Reviewer agent for the Symphony Orchestrator Repository.

Review completed engineer work before it moves to Done.

Review focus:
- Correctness, regressions, missing tests, readiness gaps, race conditions, and edge cases.
- Compliance with CONTEXT.md terminology and AGENTS.md boundaries.
- Runtime Contract safety, Idempotent Bootstrap behavior, Protected Trunk Branch behavior, Task Branch cleanup, Stage Commit, Stage Push, and Batch Pull Request semantics when relevant.
- Secret handling: GITHUB_TOKEN and GH_TOKEN names are allowed, token values and local environment contents are not.
- Frontend source hygiene: .res edits only, no committed generated .res.js files.
- Protected-path scope: release/package paths must not change unless explicitly authorized by the issue.

Run focused checks when practical. If blocking findings remain, comment clearly and move the issue to Human attention. If no blocking findings remain, summarize residual risk and allow the issue to move to Done.

---

Stage agent: reviewer

# Compozy PRD Run Stage

Run: compozy:improve-compozy-task-statuses
PRD directory: improve-compozy-task-statuses
Task step status: completed
Completed task steps: 6/6

## Completed Compozy Task Steps

- task_01.md: Reconcile Compozy lifecycle metadata from task-step truth
- task_02.md: Use reconciled lifecycle state in the Compozy tracker adapter
- task_03.md: Complete orchestrator lifecycle transitions for dispatch, retry, blocked, completion, and handoff
- task_04.md: Align Runtime State and Terminal Console with the shared Compozy status contract
- task_05.md: Align Dashboard snapshot parsing and rendering with the shared Compozy status contract
- task_06.md: Update operator documentation and examples for Compozy lifecycle semantics

## PRD (`_prd.md`)

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

## TechSpec (`_techspec.md`)

# TechSpec: Improve Compozy Task Lifecycle Statuses

## Executive Summary

This implementation tightens the existing Compozy PRD Run lifecycle architecture instead of introducing a new status subsystem. The codebase already persists run-level lifecycle metadata in Runtime Home, already extends `Runtime_state.compozy_progress`, and already renders lifecycle fields in the Terminal Console and Web Dashboard. V1 should focus on making those existing pieces obey one explicit transition contract across Compozy Task Step progress, run lifecycle state, dispatch state, and Batch Pull Request readiness.

The key technical trade-off is keeping two state sources while making only one of them authoritative for execution truth. Compozy Task Step files remain the source of truth for current-step selection and terminal counts. Runtime Home lifecycle metadata remains the persisted operator-facing summary for run phase, dispatch state, stage agent, readiness, and concise reasons, but it must reconcile to task-step progress whenever those disagree. This preserves backward-compatible Compozy Task Step behavior and keeps the current cross-surface payload shape, at the cost of stricter reconciliation logic and more focused regression coverage.

## System Architecture

### Component Overview

| Component | Responsibility | Boundary |
| --- | --- | --- |
| `Compozy_tasks_tracker` | Parse Compozy Task Steps, select the current step, and derive completed, failed, skipped, and total counts for a Compozy PRD Run. | Remains the authoritative execution-progress source. |
| `Compozy_lifecycle` | Persist Runtime Home lifecycle metadata, derive initial lifecycle state, reconcile stale metadata against Compozy Task Step truth, and provide transition helpers. | Owns run-level lifecycle summary, not task-step progress. |
| `Issue_tracker.compozy` | Fetch Compozy PRD Run candidates, use lifecycle-backed dispatch state for tracker semantics, and persist dispatch-facing status updates. | Preserves the Compozy-backed Local Issue Tracker boundary and does not require GitHub API access. |
| `Orchestrator` | Apply lifecycle transitions during dispatch, retry, failure, blocked attention, completion, and Batch Pull Request handoff. | Continues to own orchestration timing and Stage Agent routing. |
| `Runtime_state` | Assemble one extended `compozy_progress` object from task-step truth plus reconciled lifecycle metadata. | Remains the shared payload for Runtime State, Terminal Console, and Web Dashboard. |
| `Terminal_console` | Render Compozy PRD Run counts, lifecycle, readiness, handoff status, and reasons without contradicting Runtime State. | No new console mode or alternate payload. |
| Frontend ReScript snapshot parser | Parse the existing extended `compozy_progress` payload from backend snapshots. | Must preserve compatibility with older snapshots missing lifecycle fields. |
| Frontend Dashboard | Render the same run story the Terminal Console and Runtime State expose. | Must distinguish counts from lifecycle and readiness without inventing new backend semantics. |
| Existing pull-request runtime records | Keep detailed Batch Pull Request attempt and failure evidence. | Remain the detailed handoff record; lifecycle only summarizes handoff phase and readiness. |

### Data Flow

1. `Compozy_tasks_tracker.discover_prd_runs` loads Compozy PRD Runs from `.compozy/tasks/<slug>/`.
2. `Compozy_lifecycle.load_or_backfill_reconciled` loads Runtime Home lifecycle metadata or derives it from Compozy Task Step progress when missing.
3. `Issue_tracker.compozy` exposes the Compozy PRD Run as one tracker issue and uses lifecycle-backed `dispatch_state` for active and terminal checks.
4. `Orchestrator.dispatch_issue` calls `Compozy_lifecycle.mark_stage_started` to map planner, engineer, or reviewer dispatch into run-level lifecycle.
5. Retry, failure, blocked attention, completion, and Batch Pull Request handoff paths call the matching lifecycle transition helpers.
6. `Runtime_state.compozy_progress_of_prd_run` merges Compozy Task Step counts with reconciled lifecycle metadata into one payload.
7. Runtime State snapshots, the Terminal Console, and the Web Dashboard render that shared payload within one poll cycle.

## Implementation Design

### Core Interfaces

The implementation stays in OCaml, but this Go struct documents the cross-surface payload contract that backend and frontend must keep aligned:

```go
type CompozyProgress struct {
    RunID          string  `json:"run_id"`
    Slug           string  `json:"slug"`
    CurrentStep    *string `json:"current_step,omitempty"`
    Completed      int     `json:"completed"`
    Failed         int     `json:"failed"`
    Skipped        int     `json:"skipped"`
    Total          int     `json:"total"`
    LifecycleState *string `json:"lifecycle_state,omitempty"`
    DispatchState  *string `json:"dispatch_state,omitempty"`
    StageAgent     *string `json:"stage_agent,omitempty"`
    PRReadiness    *string `json:"pr_readiness,omitempty"`
    Reason         *string `json:"reason,omitempty"`
    HandoffStatus  *string `json:"handoff_status,omitempty"`
}
```

Primary backend contracts:

- `Compozy_lifecycle.load_or_backfill_reconciled : Config.t -> Compozy_tasks_tracker.prd_run -> (Compozy_lifecycle.t, string) result`
- `Compozy_lifecycle.mark_stage_started : Config.t -> Compozy_tasks_tracker.prd_run -> stage_agent:string option -> dispatch_state:string -> (Compozy_lifecycle.t, string) result`
- `Compozy_lifecycle.mark_retrying : Config.t -> Compozy_tasks_tracker.prd_run -> reason:string -> (Compozy_lifecycle.t, string) result`
- `Compozy_lifecycle.mark_failed : Config.t -> Compozy_tasks_tracker.prd_run -> reason:string -> (Compozy_lifecycle.t, string) result`
- `Compozy_lifecycle.mark_blocked : Config.t -> Compozy_tasks_tracker.prd_run -> reason:string -> (Compozy_lifecycle.t, string) result`
- `Compozy_lifecycle.mark_completed : Config.t -> Compozy_tasks_tracker.prd_run -> (Compozy_lifecycle.t, string) result`
- `Compozy_lifecycle.mark_pr_handoff : Config.t -> Compozy_tasks_tracker.prd_run -> status:string -> reason:string option -> (Compozy_lifecycle.t, string) result`
- `Runtime_state.compozy_progress_of_prd_run : ?lifecycle:Compozy_lifecycle.t -> Compozy_tasks_tracker.prd_run -> Runtime_state.compozy_progress`

All new or updated helper calls should continue returning `(value, string) result` to match existing backend error handling.

### Data Models

#### 1. Compozy Task Step truth

Compozy Task Step frontmatter remains the source of truth for:

- `current_step`
- `completed`
- `failed`
- `skipped`
- `total`

Allowed task-step statuses remain unchanged:

- `pending`
- `in_progress`
- `completed`
- `failed`
- `skipped`

V1 must not add run-level meaning to task-step statuses.

#### 2. Runtime Home lifecycle summary

Runtime Home lifecycle metadata remains stored at:

```text
.symphony/state/compozy-lifecycle/<slug>.json
```

Persisted JSON shape remains:

```json
{
  "version": 1,
  "run_id": "compozy:improve-compozy-task-statuses",
  "slug": "improve-compozy-task-statuses",
  "lifecycle_state": "in_review",
  "dispatch_state": "In review",
  "stage_agent": "reviewer",
  "pr_readiness": "not_ready",
  "reason": "Reviewer found failing verification.",
  "updated_at": "2026-05-13T20:00:00Z"
}
```

Canonical persisted lifecycle states remain:

| `lifecycle_state` | Meaning |
| --- | --- |
| `pending` | The Compozy PRD Run exists but has not entered active work. |
| `in_planning` | Planner-stage work is active. |
| `in_execution` | Engineer-stage work or active step execution is in progress. |
| `in_review` | Reviewer-stage work is active. |
| `blocked` | The run requires operator attention and is not progressing normally. |
| `completed` | The run completed successfully from the lifecycle perspective. |
| `failed` | The run ended with failed work and is not PR-ready. |
| `skipped` | The run ended with skipped work and is not PR-ready. |
| `not_pr_ready` | The run is terminal or stalled in a way that prevents Batch Pull Request readiness without being a normal success path. |
| `pr_handoff` | The run is in Batch Pull Request handoff, including attempting, completed, or failed handoff outcomes. |

Canonical persisted readiness states remain:

| `pr_readiness` | Meaning |
| --- | --- |
| `disabled` | Pull Request Policy disables automatic Batch Pull Requests. |
| `not_ready` | The run is not eligible for a Batch Pull Request. |
| `ready` | The run is complete and eligible for one aggregate Batch Pull Request. |
| `handoff_attempting` | Batch Pull Request handoff is in progress. |
| `handoff_completed` | Batch Pull Request handoff succeeded or reused an existing pull request. |
| `handoff_failed` | Batch Pull Request handoff failed. |

#### 3. Operator-facing mapping rules

V1 keeps lifecycle, dispatch, and readiness separate instead of flattening them into one label.

| Source | Role | Example |
| --- | --- | --- |
| Task-step status | Execution progress | `task_02.md` is `in_progress` |
| `lifecycle_state` | Operator-visible run phase | `in_review` |
| `dispatch_state` | Config-driven routing/tracker status | `In review` or `Human attention` |
| `pr_readiness` | Batch Pull Request eligibility | `not_ready` or `handoff_failed` |

Approved mapping rules:

- planner dispatch maps to `lifecycle_state = in_planning`
- reviewer dispatch maps to `lifecycle_state = in_review`
- engineer dispatch and active task-step execution map to `lifecycle_state = in_execution`
- retry does not add a new lifecycle value; it remains `in_execution` plus the existing retrying Runtime State context and a retry reason
- attention-oriented dispatch states such as `Human attention` remain config-driven `dispatch_state` values while lifecycle shows `blocked`
- failed Batch Pull Request handoff remains `lifecycle_state = pr_handoff` with `pr_readiness = handoff_failed` and `handoff_status = handoff_failed`

#### 4. Reconciliation rules

`Compozy_lifecycle.load_or_backfill_reconciled` becomes the required read path for Runtime State assembly and tracker candidate fetches.

Reconciliation rules:

- if lifecycle metadata is missing, derive it from current Compozy Task Step truth and persist it
- if task-step progress shows a terminal failed, skipped, blocked, or otherwise non-ready outcome, stale lifecycle metadata must be downgraded to match that terminal outcome
- task-step truth wins for `current_step` and terminal counts even when lifecycle metadata says `completed` or `ready`
- lifecycle metadata may enrich the run with `stage_agent`, `dispatch_state`, `pr_readiness`, and `reason` only after reconciliation
- handoff details stay summarized in lifecycle and fully detailed in existing pull-request runtime records

#### 5. Shared Runtime State payload

V1 keeps the existing single `Runtime_state.compozy_progress` object. It must continue exposing:

- `run_id`
- `slug`
- `current_step`
- `completed`
- `failed`
- `skipped`
- `total`
- `lifecycle_state`
- `dispatch_state`
- `stage_agent`
- `pr_readiness`
- `reason`
- `handoff_status`

Older snapshots without lifecycle fields must continue parsing safely.

### API Endpoints

No new API endpoint is required.

Existing surfaces continue to use the shared Runtime State payload:

| Surface | Entry point | Change |
| --- | --- | --- |
| HTTP | `GET /api/v1/state` | Must continue exposing reconciled `compozy_progress` values. |
| Live snapshot stream | Existing Runtime State snapshot broadcast | Must broadcast the same reconciled payload as HTTP. |
| Terminal Console | Existing Compozy PRD Run panel | Must render lifecycle, readiness, handoff, and reason from the same payload. |
| Web Dashboard | Existing ReScript snapshot parser and dashboard panel | Must parse and render the same payload without inventing alternate state meaning. |

## Integration Points

This feature does not add a new external integration.

Existing system boundaries remain:

- the Compozy-backed Local Issue Tracker remains local-file based
- GitHub API access remains unnecessary for Compozy lifecycle visibility
- existing Batch Pull Request creation continues to use current pull-request policy and handoff paths
- existing pull-request runtime records remain the detailed handoff evidence source
- Protected Trunk Branch, Task Branch Integration, and pull-request policy defaults remain unchanged

## Impact Analysis

| Component | Impact Type | Description and Risk | Required Action |
| --- | --- | --- | --- |
| `apps/backend/lib/compozy_lifecycle.ml` | Modified | Existing lifecycle helpers already exist but need to become the strict reconciliation path for runtime reads and transition writes. Risk: stale ready/completed metadata surviving task-step truth. | Tighten reconciliation rules, preserve schema, and keep handoff semantics separate from lifecycle phase. |
| `apps/backend/lib/compozy_tasks_tracker.ml` | Modified | Must continue to define current-step and terminal counts without lifecycle drift. Risk: accidental semantic changes to task-step progress. | Keep task-step status model unchanged and add only helper usage needed for lifecycle reconciliation. |
| `apps/backend/lib/issue_tracker.ml` | Modified | Must consistently use reconciled lifecycle metadata for dispatch-facing status behavior. Risk: dispatch active/terminal checks diverge from visible lifecycle state. | Route candidate fetches and status persistence through reconciled lifecycle helpers. |
| `apps/backend/lib/orchestrator.ml` | Modified | Already records lifecycle transitions in many paths; V1 needs complete coverage and consistent reasons. Risk: missing transition writes on retry, blocked completion, or handoff paths. | Consolidate all Compozy transition writes through existing lifecycle helper calls. |
| `apps/backend/lib/runtime_state.ml` | Modified | Already carries the extended payload; V1 must ensure task-step truth always wins on merge. Risk: Runtime State surfaces stale lifecycle data. | Keep one shared payload and assemble it from task-step truth plus reconciled lifecycle metadata. |
| `apps/backend/lib/terminal_console.ml` | Modified | Already renders lifecycle fields. Risk: surface wording drifts from Runtime State semantics. | Keep labels aligned with payload semantics and always show readiness or handoff when present. |
| `apps/frontend/src/RuntimeStateSnapshot.res` | Modified | Already parses lifecycle fields. Risk: parser and backend drift apart on optional fields. | Preserve backward compatibility for absent fields and keep field names unchanged. |
| `apps/frontend/src/Pages/Dashboard.res` | Modified | Already renders Compozy lifecycle details. Risk: dashboard implies a different story than the Terminal Console. | Render lifecycle, dispatch, readiness, and reason from the shared payload with clear separation from counts. |
| `apps/frontend/test/liveState.test.mjs` | Modified | Existing live-state tests already cover lifecycle-rich snapshots. Risk: new semantics land without UI regression protection. | Expand focused snapshot and render assertions for transition consistency and handoff failure semantics. |
| `apps/backend/test/test_backend.ml` | Modified | Existing backend coverage is strong but must close remaining transition and reconciliation gaps. Risk: regressions hide inside the large integration suite. | Add targeted cases near current Compozy lifecycle tests; do not split the file. |
| `CONTEXT.md` and operator docs | Modified if needed | Current glossary already defines Compozy lifecycle and readiness terms. Risk: operator-facing copy diverges from the glossary. | Update only if implementation introduces new operator wording that changes domain language. |

## Testing Approach

### Unit Tests

Backend-focused coverage should stay close to the existing lifecycle helper tests in `apps/backend/test/test_backend.ml`:

- lifecycle JSON round-trip and optional-field compatibility
- lifecycle backfill from active, completed, failed, skipped, and not-runnable Compozy PRD Runs
- stale ready/completed lifecycle metadata downgraded by reconciliation when Compozy Task Step truth becomes failed, skipped, blocked, or otherwise non-ready
- stage-agent mapping for planner, engineer, and reviewer dispatch
- `mark_retrying`, `mark_failed`, `mark_blocked`, `mark_completed`, and `mark_pr_handoff` preserving the approved phase-versus-readiness split

Frontend-focused coverage should stay in `apps/frontend/test/liveState.test.mjs`:

- snapshot parsing with lifecycle-rich payloads
- snapshot parsing when lifecycle fields are absent
- dashboard rendering for blocked, review, and handoff-failed Compozy PRD Runs
- dashboard rendering that keeps counts visible alongside lifecycle and readiness

### Integration Tests

Backend integration coverage in `apps/backend/test/test_backend.ml` should verify:

- candidate fetches and queue lookups use `load_or_backfill_reconciled`
- dispatch to planner, engineer, and reviewer records `in_planning`, `in_execution`, and `in_review`
- retry keeps the run in `in_execution` while exposing retry context and reason
- non-retryable completion errors, merge attention, and protected-path attention record `blocked`
- final failed and skipped Compozy PRD Runs record terminal non-ready lifecycle states
- successful completion records `completed` plus `ready` or `disabled` based on Pull Request Policy
- failed handoff records `lifecycle_state = pr_handoff` and `pr_readiness = handoff_failed`
- terminal non-ready runs do not attempt or appear eligible for Batch Pull Request handoff
- batch mode never opens per-step pull requests for Compozy Task Steps

Cross-surface verification should use existing tests instead of a new harness:

- Terminal Console line rendering for lifecycle, readiness, reason, and handoff fields
- HTTP Runtime State payload assertions
- live snapshot assertions
- frontend snapshot-to-dashboard render assertions

Verification commands:

- `pnpm test`
- `pnpm frontend:test`
- `pnpm frontend:build`
- `pnpm backend:build`

## Development Sequencing

### Build Order

1. Tighten `Compozy_lifecycle` reconciliation and transition helper semantics around the approved contract. This step has no dependencies.
2. Update `Issue_tracker.compozy` to consistently read reconciled lifecycle metadata and persist dispatch-state changes through lifecycle helpers. This step depends on step 1.
3. Update `Orchestrator` transition writes so planner, engineer, reviewer, retry, blocked, completion, and handoff paths all use the approved lifecycle and readiness semantics. This step depends on steps 1 and 2.
4. Update `Runtime_state.compozy_progress_of_prd_run` so task-step truth always wins while lifecycle enrichments come from reconciled metadata. This step depends on step 1.
5. Align Terminal Console rendering with the shared payload and approved lifecycle-versus-readiness split. This step depends on step 4.
6. Align `apps/frontend/src/RuntimeStateSnapshot.res` and `apps/frontend/src/Pages/Dashboard.res` with the same payload semantics and backward-compatible parsing. This step depends on step 4.
7. Expand focused backend lifecycle tests in `apps/backend/test/test_backend.ml`. This step depends on steps 1 through 4.
8. Expand focused frontend snapshot and render checks in `apps/frontend/test/liveState.test.mjs`. This step depends on step 6.
9. Update glossary or operator docs only if the final implementation changes domain wording. This step depends on steps 5 and 6.
10. Run verification and fix root causes. This step depends on steps 7, 8, and 9.

### Technical Dependencies

- No new third-party packages are required.
- Runtime Home `.symphony/state/` remains the persistence location for lifecycle metadata.
- Existing `yojson`, Runtime State snapshot machinery, and ReScript frontend parsing are sufficient.
- Existing pull-request runtime records remain the handoff detail source; no new storage file is required.

## Monitoring and Observability

V1 should rely on existing observability surfaces instead of adding a new metrics system.

Operational visibility should come from:

- Runtime Home lifecycle JSON under `.symphony/state/compozy-lifecycle/`
- Runtime State `compozy_progress` payload in HTTP and live snapshots
- Terminal Console Compozy PRD Run lines for lifecycle, readiness, handoff, and reason
- existing pull-request runtime records for handoff attempts, completions, and failures

Important observable events:

- lifecycle metadata backfilled for a run with no persisted record
- stale lifecycle metadata reconciled downward to a failed, skipped, blocked, or not-ready outcome
- stage dispatch mapped to planner, engineer, or reviewer lifecycle
- Batch Pull Request handoff moved to attempting, completed, or failed
- blocked attention reason recorded for protected-path or merge-attention outcomes

Alerting is not a separate infrastructure task in V1. The practical guardrail is test-backed consistency across Runtime State, Terminal Console, and Web Dashboard.

## Technical Considerations

### Key Decisions

- **Decision:** Keep one extended `Runtime_state.compozy_progress` payload.
  - **Rationale:** The backend, Terminal Console, and Web Dashboard already depend on this shared shape.
  - **Trade-off:** Conceptual layers stay in one object, so field semantics must be explicit.
  - **Alternatives rejected:** separate lifecycle and readiness payloads would add churn without improving operator trust in V1.

- **Decision:** Keep Compozy Task Step progress authoritative for current-step and terminal-count truth.
  - **Rationale:** Task-step files are the closest execution record and must not regress.
  - **Trade-off:** Runtime Home lifecycle metadata must reconcile instead of assuming it is correct.
  - **Alternatives rejected:** making lifecycle metadata authoritative would allow stale operator state.

- **Decision:** Keep `dispatch_state` config-driven and separate from operator-facing `lifecycle_state`.
  - **Rationale:** Routing and tracker semantics already depend on configured tracker states such as `Human attention`.
  - **Trade-off:** Operators may need both fields in some scenarios.
  - **Alternatives rejected:** flattening dispatch into lifecycle would lose configured tracker behavior.

- **Decision:** Keep failed Batch Pull Request handoff as `pr_handoff` plus failed readiness.
  - **Rationale:** Handoff failure is a readiness outcome within the handoff phase, not a new lifecycle phase.
  - **Trade-off:** Some states require reading both `lifecycle_state` and `pr_readiness`.
  - **Alternatives rejected:** adding a dedicated handoff-failed lifecycle state would create redundant vocabulary.

- **Decision:** Expand focused regression coverage instead of introducing a new status test harness.
  - **Rationale:** The repository already has strong backend Compozy lifecycle coverage and frontend live-state tests.
  - **Trade-off:** The large backend test file remains large.
  - **Alternatives rejected:** a new harness would increase maintenance cost without changing the core risk.

### Known Risks

- **Risk:** Reconciliation misses a terminal downgrade path and leaves stale ready/completed metadata visible.
  - **Likelihood:** Medium
  - **Mitigation:** Add explicit backend cases for stale lifecycle repair across failed, skipped, blocked, and not-ready outcomes.

- **Risk:** Surface wording diverges even when the payload is correct.
  - **Likelihood:** Medium
  - **Mitigation:** Use the shared payload as the single contract and extend Terminal Console plus frontend render assertions.

- **Risk:** Retry and handoff semantics remain hard to read because they span more than one field.
  - **Likelihood:** Medium
  - **Mitigation:** Require reason and handoff-status visibility when those states are present; keep lifecycle labels canonical.

- **Risk:** Implementation accidentally changes Compozy Task Step semantics while tightening lifecycle logic.
  - **Likelihood:** Low to medium
  - **Mitigation:** Keep no-regression assertions for current-step selection and visible counts in backend and frontend tests.

## Architecture Decision Records

- [ADR-001: Represent Compozy lifecycle at PRD Run level](adrs/adr-001.md) — Lifecycle belongs to the Compozy PRD Run, not to individual Compozy Task Steps.
- [ADR-002: Use full V1 operator trust as the PRD product approach](adrs/adr-002.md) — V1 should make lifecycle and readiness visible across current operator surfaces.
- [ADR-003: Persist dispatch-aware Compozy lifecycle in Runtime Home](adrs/adr-003.md) — Runtime Home stores the lifecycle summary while Compozy Task Step files keep execution progress.
- [ADR-004: Treat Compozy statuses as an explicit transition contract](adrs/adr-004.md) — The problem is status mapping and transition coverage, not missing labels alone.
- [ADR-005: Use a cross-surface transition contract as the PRD approach](adrs/adr-005.md) — Runtime State, Terminal Console, and Web Dashboard must tell the same run story.
- [ADR-006: Reconcile Compozy lifecycle from task-step progress while keeping readiness separate](adrs/adr-006.md) — Task-step truth wins, lifecycle enriches, dispatch stays separate, and handoff failure remains a readiness outcome.

