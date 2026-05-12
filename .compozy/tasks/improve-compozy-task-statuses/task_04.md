---
status: pending
title: "Update orchestrator lifecycle transitions"
type: backend
complexity: high
dependencies:
  - task_03
---

# Task 04: Update orchestrator lifecycle transitions

## Overview
Teach orchestration paths to update Compozy PRD Run lifecycle metadata as Stage Agents start, retry, fail, complete, or require attention. This makes the lifecycle trustworthy during active execution while preserving existing Compozy Task Step status and retry behavior.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST mark planner Stage Agent dispatch as `in_planning` at the Compozy PRD Run lifecycle level.
- R2 MUST mark engineer or task-step execution dispatch as `in_execution` while preserving task-step `in_progress` updates.
- R3 MUST mark reviewer Stage Agent dispatch as `in_review` at the Compozy PRD Run lifecycle level.
- R4 MUST mark failed, skipped, blocked, and attention outcomes with concise operator-facing reasons.
- R5 MUST mark successful final Compozy PRD Run completion without implying PR readiness until readiness rules are evaluated.
- R6 MUST preserve existing retry, current-step advancement, Agent Worktree, Task Branch, and Task Branch Integration behavior.
</requirements>

## Subtasks
- [ ] 4.1 Record lifecycle state when a Compozy PRD Run is dispatched to a Stage Agent.
- [ ] 4.2 Record lifecycle state during Compozy Task Step retry and over-limit failure paths.
- [ ] 4.3 Record lifecycle state when execution advances to the next Compozy Task Step.
- [ ] 4.4 Record lifecycle state when the final task step completes successfully.
- [ ] 4.5 Record blocked or attention lifecycle reasons for merge, protected-path, and non-retryable completion failures.
- [ ] 4.6 Add focused orchestrator tests for planner, engineer, reviewer, failure, completion, and attention transitions.

## Implementation Details
Follow TechSpec "Data Flow" and "Development Sequencing" steps for orchestrator transitions. Centralize writes through `Compozy_lifecycle` helpers and avoid changing the Compozy Task Step progress rules in `Compozy_tasks_tracker`.

### Relevant Files
- `apps/backend/lib/orchestrator.ml` — Dispatch, retry, failure, completion, blocked, Task Branch Integration, and state-update paths.
- `apps/backend/lib/compozy_lifecycle.ml` — Transition helpers for Stage Agent start, not-PR-ready, failure, blocked, and completion updates.
- `apps/backend/lib/compozy_tasks_tracker.ml` — Task-step status and retry behavior that must remain authoritative for current-step progress.
- `apps/backend/lib/config.ml` — Stage Agent status mappings and Pull Request Policy fields used during orchestration decisions.
- `apps/backend/test/test_backend.ml` — Existing Compozy orchestration tests for sequential steps, retry, and final-step behavior.

### Dependent Files
- `apps/backend/lib/runtime_state.ml` — Must reflect lifecycle changes in current snapshots.
- `apps/backend/lib/issue_tracker.ml` — Supplies lifecycle-backed issue state to dispatch filtering.
- `apps/backend/bin/main.ml` — Later renders lifecycle transitions to the Terminal Console.

### Related ADRs
- [ADR-001: Represent Compozy lifecycle at PRD Run level](adrs/adr-001.md) — Requires Stage Agent phases to be run-level lifecycle, not task-step statuses.
- [ADR-002: Use full V1 operator trust as the PRD product approach](adrs/adr-002.md) — Requires lifecycle visibility for planner, engineer, reviewer, blocked, failed, skipped, and completed states.
- [ADR-003: Persist dispatch-aware Compozy lifecycle in Runtime Home](adrs/adr-003.md) — Requires durable dispatch-aware lifecycle transitions.

## Deliverables
- Orchestrator lifecycle updates for Stage Agent dispatch and active execution.
- Orchestrator lifecycle updates for retry, failure, blocked, attention, skipped, and successful completion outcomes.
- Preservation of existing Compozy Task Step progress and retry semantics.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for Compozy lifecycle transitions through orchestration **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Dispatching a planner-stage Compozy PRD Run records `lifecycle_state = in_planning` with `stage_agent = planner`.
  - [ ] Dispatching an engineer-stage Compozy PRD Run records `lifecycle_state = in_execution` and preserves task-step `in_progress`.
  - [ ] Dispatching a reviewer-stage Compozy PRD Run records `lifecycle_state = in_review` with `stage_agent = reviewer`.
  - [ ] A failed task step below retry limit keeps lifecycle non-ready and preserves retry behavior.
  - [ ] A failed task step over retry limit records failed lifecycle with a reason and advances only according to existing step rules.
  - [ ] A final successful Compozy PRD Run records completed lifecycle without losing step counts.
- Integration tests:
  - [ ] Merge attention, protected-path attention, and non-retryable completion errors record blocked or not-ready lifecycle reasons in Runtime State.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Operators can distinguish planning, execution, review, failure, blocked, and completion from Runtime State after orchestration transitions.
- Existing Compozy Task Step current-step and retry tests remain passing.
