---
status: completed
title: "Complete orchestrator lifecycle transitions for dispatch, retry, blocked, completion, and handoff"
type: backend
complexity: high
dependencies:
  - task_01
  - task_02
---

# Task 03: Complete orchestrator lifecycle transitions for dispatch, retry, blocked, completion, and handoff

## Overview
Finish the run-level transition matrix in orchestration so planners, engineers, reviewers, retries, blocked outcomes, completions, and Batch Pull Request handoff all update lifecycle and readiness consistently. This task covers the highest-risk behavioral paths because it determines whether operator-facing status changes are actually emitted at the right time.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST map planner, engineer, and reviewer dispatch to `in_planning`, `in_execution`, and `in_review` respectively.
- R2 MUST keep retrying Compozy PRD Runs in lifecycle state `in_execution` while recording retry reasons and non-ready status.
- R3 MUST mark over-limit or terminal task-step failures as `failed` with a concise operator-facing reason.
- R4 MUST mark merge attention, protected-path attention, and non-retryable completion failures as `blocked` without implying successful completion.
- R5 MUST mark successful run completion as `completed` with readiness `ready` or `disabled` according to Pull Request Policy.
- R6 MUST keep Batch Pull Request handoff modeled as lifecycle phase `pr_handoff` with readiness `handoff_attempting`, `handoff_completed`, or `handoff_failed`.
- R7 MUST prevent non-ready terminal states from appearing handoff-ready or triggering aggregate handoff success semantics.
</requirements>

## Subtasks
- [x] 3.1 Audit existing Compozy transition writes across dispatch, retry, blocked, completion, and handoff paths.
- [x] 3.2 Align stage-started transitions for planner, engineer, and reviewer dispatch.
- [x] 3.3 Tighten retry and failure transitions so retrying, failed, and blocked outcomes remain distinct.
- [x] 3.4 Preserve completion and Batch Pull Request handoff semantics for ready, disabled, and failed handoff paths.
- [x] 3.5 Add focused backend integration coverage for representative transition sequences.

## Implementation Details
Reference TechSpec "Implementation Design" mapping rules, TechSpec "Integration Tests", and ADR-004 through ADR-006. Keep the implementation centered on Compozy lifecycle update calls inside `orchestrator.ml`; do not redesign Stage Agent orchestration or Pull Request Policy defaults.

### Relevant Files
- `apps/backend/lib/orchestrator.ml` — Owns dispatch, retry, failure, blocked attention, completion, and Batch Pull Request handoff transitions.
- `apps/backend/lib/compozy_lifecycle.ml` — Supplies lifecycle transition helpers invoked by orchestration.
- `apps/backend/test/test_backend.ml` — Already contains Compozy dispatch, blocked, completion, and handoff tests to expand.

### Dependent Files
- `apps/backend/lib/runtime_state.ml` — Surfaces will expose the lifecycle and readiness outcomes this task emits.
- `apps/backend/lib/terminal_console.ml` — Later tasks render the transition results for operators.
- `apps/frontend/test/liveState.test.mjs` — Frontend checks should eventually mirror the final transition semantics.

### Related ADRs
- [ADR-004: Treat Compozy statuses as an explicit transition contract](adrs/adr-004.md) — Requires complete transition coverage rather than new status labels.
- [ADR-005: Use a cross-surface transition contract as the PRD approach](adrs/adr-005.md) — Makes orchestration transition correctness a first-class operator outcome.
- [ADR-006: Reconcile Compozy lifecycle from task-step progress while keeping readiness separate](adrs/adr-006.md) — Requires readiness and handoff outcomes to remain separate from lifecycle phase semantics.

## Deliverables
- Orchestrator transition paths emit the approved lifecycle and readiness states for dispatch, retry, failure, blocked, completion, and handoff scenarios.
- Representative transition paths have integration coverage in the backend suite.
- Batch Pull Request handoff failure remains visible as `pr_handoff` plus failed readiness instead of a fake successful completion.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for Compozy lifecycle transition coverage **(REQUIRED)**

## Tests
- Unit tests:
  - [x] Planner dispatch records `in_planning` and reviewer dispatch records `in_review`.
  - [x] Engineer dispatch and retrying task-step failure keep lifecycle `in_execution` with non-ready status.
  - [x] Final failed task-step over retry limit records lifecycle `failed` with a reason.
  - [x] Non-retryable completion and protected-path attention record lifecycle `blocked`.
  - [x] Batch Pull Request handoff helper records `handoff_attempting`, `handoff_completed`, and `handoff_failed` while lifecycle remains `pr_handoff`.
- Integration tests:
  - [x] Successful Compozy PRD Run completion records `completed` and the expected readiness for Pull Request Policy mode.
  - [x] Failed, skipped, blocked, and handoff-failed runs never appear ready for an aggregate Batch Pull Request.
  - [x] Existing Compozy orchestration paths still avoid per-step pull requests in batch mode.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Orchestration emits the approved lifecycle transition set for the representative active, blocked, completion, and handoff paths.
- Non-ready outcomes never contradict visible Pull Request readiness semantics.
