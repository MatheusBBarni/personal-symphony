---
status: completed
title: "Add Compozy task-step retry and skip behavior"
type: backend
complexity: high
dependencies:
  - task_07
---

# Task 08: Add Compozy task-step retry and skip behavior

## Overview
Implement the Compozy-specific retry limit for task steps. A failed task step retries up to `tracker.compozy.maxTaskStepRetries`, then records a failed or skipped state and advances to the next runnable step.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST use `tracker.compozy.maxTaskStepRetries` for Compozy task-step retry limits.
- R2 MUST retry the same task step until the configured limit is reached.
- R3 MUST persist retry count and last error in task file frontmatter.
- R4 MUST mark failed-over-limit task steps as failed or skipped and advance to the next runnable task step.
- R5 MUST surface failed/skipped counts in Runtime State.
- R6 MUST leave GitHub retry behavior unchanged.
</requirements>

## Subtasks
- [x] 8.1 Track task-step retry counts in Compozy task frontmatter.
- [x] 8.2 Apply the configured retry limit for failed Compozy task steps.
- [x] 8.3 Mark failed-over-limit steps and advance to the next runnable task.
- [x] 8.4 Surface failed and skipped step counts in Runtime State.
- [x] 8.5 Add tests for retry, skip, and GitHub regression behavior.

## Implementation Details
Use TechSpec "Known Risks" and ADR-006 for final state visibility. Make failed/skipped states obvious because continuing after failures can otherwise hide broken work.

### Relevant Files
- `apps/backend/lib/compozy_tasks_tracker.ml` — Persists retry count, last error, and failed/skipped status.
- `apps/backend/lib/orchestrator.ml` — Handles failed child processes and retry decisions.
- `apps/backend/lib/runtime_state.ml` — Exposes failed/skipped counts.
- `apps/backend/test/test_backend.ml` — Existing retry tests and orchestrator failure cases.

### Dependent Files
- `apps/backend/lib/config.ml` — Supplies `maxTaskStepRetries`.
- `apps/frontend/src/Pages/Dashboard.res` — Later task will display failed/skipped counts.

### Related ADRs
- [ADR-004: Persist task-step progress in Compozy task files](adrs/adr-004.md) — Stores retry state in frontmatter.
- [ADR-006: Configure task-step retries in Compozy tracker settings](adrs/adr-006.md) — Defines retry limit setting and advance-after-limit behavior.

## Deliverables
- Compozy task-step retry handling.
- Failed/skipped step frontmatter updates.
- Runtime State failed/skipped counts.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for retry-limit advancement **(REQUIRED)**

## Tests
- Unit tests:
  - [x] Failed Compozy task step increments `symphony_retry_count`.
  - [x] Retry count below limit relaunches the same task step.
  - [x] Retry count at limit marks the task failed or skipped.
  - [x] Failed-over-limit task advances to the next runnable task step.
  - [x] GitHub retry behavior remains unchanged.
- Integration tests:
  - [x] Two-step PRD run with first task failing over limit proceeds to second task and records failed/skipped count.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Configured task-step retry limit controls Compozy failures.
- Failed-over-limit steps are visible and do not silently disappear.
