---
status: pending
title: "Wire Goal Loop lifecycle into orchestration dispatch and activity"
type: backend
complexity: high
dependencies:
  - task_03
  - task_04
  - task_05
---

# Task 07: Wire Goal Loop lifecycle into orchestration dispatch and activity

## Overview
This task connects the pure Goal Loop model to orchestration lifecycle events before completion gating is added. It creates and updates loop state during dispatch, running activity, retrying, stop, and budget transitions while preserving existing task lifecycle behavior.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- REQ-01 MUST create Goal Loop state when a Goal Loop-enabled stage dispatches an agent.
- REQ-02 MUST update attempt count, harness identity, latest activity, budget status, and next action during orchestration.
- REQ-03 MUST persist each canonical state update and project it into Runtime State.
- REQ-04 MUST not change Stage Commit, Stage Push, merge, PR, or status transition behavior in this task.
- REQ-05 MUST distinguish Goal Loop state from optional provider Goal Usage.
</requirements>

## Subtasks
- [ ] 7.1 Create loop state at dispatch for enabled stages.
- [ ] 7.2 Update loop state when agent output or workspace activity changes.
- [ ] 7.3 Update loop state when an existing retry is scheduled.
- [ ] 7.4 Record budget exhaustion as a visible stop state.
- [ ] 7.5 Add orchestration tests proving existing lifecycle behavior is unchanged.

## Implementation Details
Use the TechSpec "Integration Points" and "Development Sequencing" sections. This task should populate lifecycle state, but the evidence gate itself belongs to task_08.

### Relevant Files
- `apps/backend/lib/orchestrator.ml` — owns dispatch, child refresh, retry, timeout, blocked state, and completion flow.
- `apps/backend/lib/runtime_state.ml` — exposes the loop projection from task_05.
- `apps/backend/lib/config.ml` — supplies validated stage Goal Loop settings from task_03.
- `apps/backend/test/test_backend.ml` — contains orchestrator dispatch, retry, Goal Usage, and Runtime State tests.

### Dependent Files
- `apps/backend/lib/terminal_console_model.ml` — later reads lifecycle state in task_09.
- `apps/frontend/src/RuntimeStateSnapshot.res` — later reads lifecycle state in task_10.
- `apps/backend/lib/orchestrator.ml` completion path — task_08 adds evidence gating.

### Related ADRs
- [ADR-001: Goal Loop Runtime Scope](adrs/adr-001.md) — Requires Runtime-owned state without delivery authority.
- [ADR-003: Stage-Scoped Goal Loop Runtime State](adrs/adr-003.md) — Requires canonical persisted state and Runtime State projection.

## Deliverables
- Orchestrator lifecycle wiring for Goal Loop state creation and updates.
- Persistence calls for active and terminal loop states.
- Runtime State updates reflecting dispatch, running, retrying, and budget outcomes.
- Unit tests with 80%+ coverage **(REQUIRED)**.
- Integration tests for dispatch and retry state projection **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] Dispatching a Goal Loop-enabled stage creates a `running` loop state.
  - [ ] Dispatching a non-enabled stage does not create loop state.
  - [ ] Agent output updates latest activity without overwriting Goal Usage.
  - [ ] Existing retry scheduling updates Goal Loop attempt and next action.
  - [ ] Budget exhaustion creates a `budget_exhausted` stop outcome.
- Integration tests:
  - [ ] Runtime State snapshot shows loop state for an active dispatched task.
  - [ ] Existing Stage Goal Handoff prompt composition remains unchanged.
  - [ ] Existing Stage Commit/status behavior remains unchanged before task_08.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Goal Loop state follows orchestration lifecycle events.
- No existing delivery behavior changes before evidence gating is implemented.
