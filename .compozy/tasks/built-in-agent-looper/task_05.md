---
status: pending
title: "Expose Goal Loop state through Runtime State JSON"
type: backend
complexity: medium
dependencies:
  - task_04
---

# Task 05: Expose Goal Loop state through Runtime State JSON

## Overview
This task projects canonical Goal Loop state into the existing Runtime State snapshot. It gives the backend, Terminal Console, Web Dashboard, HTTP state endpoint, and live connection one shared source for loop visibility.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- REQ-01 MUST add a top-level `goal_loops` collection to Runtime State JSON.
- REQ-02 MUST include the fields defined by the TechSpec "Data Models" section.
- REQ-03 MUST preserve compatibility for old snapshots or clients that omit `goal_loops`.
- REQ-04 MUST keep `/api/v1/state` and the Live Dashboard Connection as the delivery mechanism.
- REQ-05 SHOULD expose row-level lookup helpers for issue-associated loop state when useful.
</requirements>

## Subtasks
- [ ] 5.1 Add Runtime State Goal Loop types and JSON serialization.
- [ ] 5.2 Add top-level `goal_loops` to Runtime State snapshots.
- [ ] 5.3 Add helpers to look up loop state by issue id.
- [ ] 5.4 Add JSON compatibility tests for snapshots with and without Goal Loop data.
- [ ] 5.5 Add HTTP/websocket snapshot coverage if Runtime State test coverage requires it.

## Implementation Details
Use the TechSpec "API Endpoints" section. Do not add new endpoints; extend the existing Runtime State payload and let existing server delivery continue to carry the full snapshot.

### Relevant Files
- `apps/backend/lib/runtime_state.ml` — owns Runtime State types and JSON serialization.
- `apps/backend/lib/server.ml` — serves `/api/v1/state` and live snapshots from Runtime State.
- `apps/backend/test/test_backend.ml` — has Runtime State, HTTP state, and websocket snapshot tests.
- `apps/frontend/src/RuntimeStateSnapshot.res` — later frontend task consumes the JSON contract.

### Dependent Files
- `apps/backend/lib/terminal_console_model.ml` — task_09 consumes Runtime State loop projection.
- `apps/frontend/src/RuntimeStateSnapshot.res` — task_10 consumes `goal_loops`.
- `apps/backend/lib/orchestrator.ml` — task_07 and task_08 populate state.

### Related ADRs
- [ADR-003: Stage-Scoped Goal Loop Runtime State](adrs/adr-003.md) — Requires top-level Runtime State projection.

## Deliverables
- Runtime State `goal_loops` types and JSON.
- Compatibility behavior for missing `goal_loops`.
- Tests for serialization and snapshot delivery.
- Unit tests with 80%+ coverage **(REQUIRED)**.
- Integration tests for HTTP/live snapshot shape **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] `Runtime_state.to_yojson` includes `goal_loops` when loop state exists.
  - [ ] Empty Runtime State serializes `goal_loops` as an empty list or compatible absent-safe value.
  - [ ] Goal Loop JSON includes issue id, run id, state, stop outcome, evidence, next action, and timestamp.
  - [ ] Missing optional fields serialize as `null` or are omitted consistently with existing Runtime State conventions.
- Integration tests:
  - [ ] `/api/v1/state` includes `goal_loops`.
  - [ ] Live Dashboard initial websocket snapshot includes `goal_loops`.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Goal Loop state is visible from Runtime State without new endpoints.
- Existing Runtime State consumers remain compatible.
