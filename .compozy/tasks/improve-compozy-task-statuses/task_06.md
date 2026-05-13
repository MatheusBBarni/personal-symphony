---
status: completed
title: "Render lifecycle in Terminal Console and backend state surfaces"
type: backend
complexity: medium
dependencies:
  - task_02
  - task_05
---

# Task 06: Render lifecycle in Terminal Console and backend state surfaces

## Overview
Expose Compozy PRD Run lifecycle and PR readiness in backend operator surfaces after the Runtime State contract is extended. The Terminal Console should show compact lifecycle lines, while HTTP and Live Dashboard Connection state should serve the same structured `compozy_progress` payload.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST render lifecycle state, dispatch state, PR readiness, reason, and handoff status in the Terminal Console when present.
- R2 MUST keep existing Compozy Task Step progress lines visible in the Terminal Console.
- R3 MUST avoid noisy placeholder text for optional lifecycle fields that are absent.
- R4 MUST ensure `GET /api/v1/state` exposes the extended `compozy_progress` payload.
- R5 MUST ensure the Live Dashboard Connection sends Runtime State snapshots with the same extended `compozy_progress` payload, not an event envelope.
- R6 SHOULD keep Terminal Console copy concise and aligned with Web Dashboard labels.
</requirements>

## Subtasks
- [x] 6.1 Add compact Terminal Console lifecycle and readiness output under PRD Run Progress.
- [x] 6.2 Preserve existing current-step and step-count output.
- [x] 6.3 Verify HTTP Runtime State contains the extended Compozy lifecycle fields.
- [x] 6.4 Verify live Runtime State snapshots contain the same extended fields.
- [x] 6.5 Add focused backend tests or golden assertions for console/state-surface output.

## Implementation Details
Follow TechSpec "API Endpoints" and "Monitoring and Observability". Do not add new endpoints or a new CLI mode; the existing Runtime State payload and Terminal Console are the surfaces for this task.

### Relevant Files
- `apps/backend/bin/main.ml` — Terminal Console rendering for PRD Run Progress.
- `apps/backend/lib/runtime_state.ml` — Extended `compozy_progress` JSON payload consumed by backend surfaces.
- `apps/backend/lib/server.ml` — Existing HTTP and Live Dashboard Connection state serving paths.
- `apps/backend/test/test_backend.ml` — Existing HTTP state and Runtime State tests to extend with lifecycle fields.

### Dependent Files
- `apps/frontend/src/LiveState.res` — Expects the Live Dashboard Connection to remain Runtime State snapshots.
- `apps/frontend/src/RuntimeStateSnapshot.res` — Frontend parsing depends on the backend payload verified here.
- `README.md` — Documentation in task_08 should use the final Terminal Console and Runtime State labels.

### Related ADRs
- [ADR-002: Use full V1 operator trust as the PRD product approach](adrs/adr-002.md) — Requires all-surface lifecycle visibility.
- [ADR-003: Persist dispatch-aware Compozy lifecycle in Runtime Home](adrs/adr-003.md) — Requires lifecycle and readiness fields in `compozy_progress`.

## Deliverables
- Terminal Console PRD Run Progress output with lifecycle, dispatch state, Stage Agent, PR readiness, handoff status, and reason when available.
- HTTP Runtime State coverage for the extended `compozy_progress` payload.
- Live Runtime State snapshot coverage that preserves the snapshot contract.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for backend Runtime State surfaces **(REQUIRED)**

## Tests
- Unit tests:
  - [x] Terminal Console rendering includes `Lifecycle`, `Dispatch state`, `Stage agent`, `PR readiness`, `Handoff`, and `Reason` when those fields are present.
  - [x] Terminal Console rendering omits absent optional lifecycle lines and still prints current step and step counts.
  - [x] Runtime State JSON includes lifecycle/readiness fields for a Compozy PRD Run with lifecycle metadata.
  - [x] Runtime State JSON remains compatible when `compozy_progress` is absent.
- Integration tests:
  - [x] `GET /api/v1/state` returns extended `compozy_progress` fields for a Compozy tracker Runtime State snapshot.
  - [x] Live Dashboard Connection payload shape remains a full Runtime State snapshot containing `compozy_progress`, not an event envelope.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Terminal Console operators can identify lifecycle state and PR readiness without reading logs.
- Backend HTTP and live state surfaces expose the same lifecycle and readiness values.
