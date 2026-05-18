---
status: completed
title: "Allow idle startup and enforce ready-status dispatch semantics"
type: backend
complexity: high
dependencies:
  - task_01
  - task_02
  - task_03

---

# Task 04: Allow idle startup and enforce ready-status dispatch semantics

## Overview
Update orchestration startup and dispatch so a Workspace Repository with no ready work remains in valid Orchestration Idle state, while first admission and Ordered Queue selection both respect the Symphony-ready Status rule. This task ties the tracker-owned admission decisions into runtime readiness and dispatch without changing post-admission lifecycle, retry, or stage-routing behavior.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details - do not duplicate here
- FOCUS ON "WHAT" - describe what needs to be accomplished, not how
- MINIMIZE CODE - show code only to illustrate current structure or problem areas
- TESTS REQUIRED - every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST treat the absence of ready work as valid Orchestration Idle state rather than a startup Readiness Gap.
- R2 MUST use tracker admission decisions when evaluating first dispatch eligibility in the poll loop.
- R3 MUST require Ordered Queue entries to satisfy the Symphony-ready Status rule before first admission.
- R4 MUST preserve existing retry timing, stage routing, active-run tracking, and post-admission lifecycle behavior for already admitted work.
- R5 MUST keep structural tracker failures and malformed queue entries as real Readiness Gaps.
- R6 MUST include backend test coverage for idle startup, queue precedence, ready admission, and preserved post-admission behavior.
</requirements>

## Subtasks
- [x] 4.1 Remove "nothing ready" as a readiness-blocking startup condition while preserving structural readiness validation.
- [x] 4.2 Enforce tracker admission decisions during first dispatch in the orchestrator poll loop.
- [x] 4.3 Apply the same ready-status rule to Ordered Queue admission without letting queue selection bypass tracker eligibility.
- [x] 4.4 Extend backend tests for idle startup, queue gating, and preserved post-admission lifecycle semantics.

## Implementation Details
Reference the TechSpec "System Architecture", "Impact Analysis", and "Monitoring and Observability" sections, especially the idle-startup decision and queue interaction rules. Keep this task focused on readiness, policy, and dispatch semantics; operator-facing Runtime State explanations and dashboard rendering belong to the next task.

### Relevant Files
- `apps/backend/lib/runtime_readiness.ml` - Startup readiness evaluation that currently treats unavailable tracker work as a gap in some paths.
- `apps/backend/lib/runtime_policy.ml` - Runtime launch policy that decides whether orchestration can run or only serve readiness output.
- `apps/backend/lib/orchestrator.ml` - Poll loop and first-dispatch path that must consume tracker admission decisions.
- `apps/backend/lib/ordered_queue.ml` - Ordered Queue validation and matching must respect ready-status eligibility for first admission.
- `apps/backend/test/test_backend.ml` - Existing readiness, queue, and orchestration integration tests to extend near related flows.

### Dependent Files
- `apps/backend/bin/main.ml` - Runtime startup path that depends on readiness and policy behavior.
- `apps/backend/bin/terminal_console_runtime.ml` - Terminal Console behavior will inherit the new idle-versus-gap semantics.
- `apps/backend/lib/runtime_state.ml` - Later task will expose why a ready-looking item is blocked or excluded.

### Related ADRs
- [ADR-002: Use a standard Symphony-ready status convention across trackers](adrs/adr-002.md) - Requires status-driven intake and healthy idle startup.
- [ADR-003: Put Symphony-ready status at the tracker boundary with exact-match first-admission semantics](adrs/adr-003.md) - Requires queue and dispatch to respect tracker admission.

## Deliverables
- Startup behavior that enters Orchestration Idle when no work is ready.
- Dispatch and Ordered Queue admission logic that respects tracker-owned ready-status eligibility.
- Backend tests covering idle startup, queue gating, and preserved post-admission lifecycle behavior.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for startup and dispatch semantics **(REQUIRED)**

## Tests
- Unit tests:
  - [x] Runtime readiness returns no readiness gap when the selected tracker is structurally valid but has zero ready items.
  - [x] Ordered Queue validation rejects a queue entry that is visible but not ready for first admission.
  - [x] Orchestrator first-admission filtering uses the tracker admission decision instead of broader active-state checks.
- Integration tests:
  - [x] Startup with valid GitHub or Compozy tracker settings and zero ready items enters Orchestration Idle rather than readiness-only mode.
  - [x] A queued item does not dispatch until it satisfies the Symphony-ready Status rule, even when it is otherwise visible in the selected Issue Tracker.
  - [x] Already admitted work continues through retry or later stage handling without being ejected by the new first-admission rule.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Symphony can stay running in healthy idle state when no work is ready.
- First dispatch and Ordered Queue admission both honor tracker-owned ready-status eligibility without changing post-admission lifecycle behavior.
