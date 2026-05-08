---
status: pending
title: "Refactor orchestrator to use the selected Issue Tracker"
type: backend
complexity: high
dependencies:
  - task_02
  - task_04
---

# Task 05: Refactor orchestrator to use the selected Issue Tracker

## Overview
Refactor orchestration polling, dispatch filtering, active/terminal checks, status moves, and tracker poll failures to use the selected `Issue_tracker` boundary. This task enables one end-to-end GitHub-free local run while preserving GitHub behavior.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST remove shared orchestrator dependence on `Github_tracker.t`.
- R2 MUST fetch candidates through the selected Issue Tracker.
- R3 MUST move dispatch, success, retry, attention, and merge statuses through the selected Issue Tracker.
- R4 MUST preserve GitHub rate-limit pause behavior through generic tracker poll errors.
- R5 MUST support a minibeads issue dispatch without GitHub settings or token.
</requirements>

## Subtasks
- [ ] 5.1 Change orchestrator tracker fields and injected function types to the shared boundary.
- [ ] 5.2 Replace direct GitHub active/terminal checks with selected tracker checks.
- [ ] 5.3 Replace GitHub-specific poll error handling with generic tracker poll errors.
- [ ] 5.4 Ensure status transitions call the selected tracker.
- [ ] 5.5 Add an end-to-end minibeads adapter stub dispatch test.

## Implementation Details
Follow TechSpec "System Architecture" and "Development Sequencing" step 6. Preserve existing stage, retry, Stage Commit, Stage Push, Task Branch Integration, and Batch Pull Request behavior.

### Relevant Files
- `apps/backend/lib/orchestrator.ml` — Main orchestration polling, status movement, retry, dispatch, and queue filtering.
- `apps/backend/lib/issue_tracker.ml` — New selected tracker contract.
- `apps/backend/lib/github_tracker.ml` — Existing behavior behind GitHub adapter.
- `apps/backend/test/test_backend.ml` — Existing orchestrator dispatch, retry, rate-limit, and status movement tests.

### Dependent Files
- `apps/backend/bin/main.ml` — Constructs orchestrator and selected tracker.
- `apps/backend/lib/runtime_state.ml` — Receives issue snapshots from orchestrator.
- `apps/backend/lib/manual_merge.ml` — Later merge status updates use the same tracker semantics.

### Related ADRs
- [ADR-003: Introduce a shared Issue Tracker boundary](adrs/adr-003.md) — Primary orchestration boundary.
- [ADR-004: Use the mb CLI as the minibeads integration boundary](adrs/adr-004.md) — minibeads status writes use `mb`.
- [ADR-005: Keep PR handoff independent of tracker kind](adrs/adr-005.md) — Status updates remain selected-tracker operations.

## Deliverables
- Orchestrator uses `Issue_tracker.t` for shared tracker operations.
- Generic tracker poll errors preserve rate-limit and failure handling.
- End-to-end local dispatch test using a minibeads stub.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for GitHub and minibeads orchestration behavior **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Generic rate-limit poll error pauses tracking for the existing retry delay.
  - [ ] Generic failed poll error updates Runtime State last error.
  - [ ] Active/terminal checks call selected tracker behavior.
  - [ ] Status update failure routes to existing retry/attention behavior.
- Integration tests:
  - [ ] minibeads stub issue dispatches, starts, completes, and writes status without GitHub settings or token.
  - [ ] Existing GitHub dispatch, retry, terminal filtering, and status movement tests continue to pass.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- One local issue can complete the core Symphony orchestration loop through the selected tracker.
