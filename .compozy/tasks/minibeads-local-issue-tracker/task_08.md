---
status: pending
title: "Add tracker kind Runtime State and tracker-neutral dashboard wording"
type: frontend
complexity: medium
dependencies:
  - task_01
  - task_05
---

# Task 08: Add tracker kind Runtime State and tracker-neutral dashboard wording

## Overview
Expose the selected tracker kind in Runtime State and update Terminal Console and Web Dashboard wording so local tracker runs do not show GitHub/project-specific language. V1 intentionally avoids rich local metadata dashboard cards.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST add `tracker_kind` to Runtime State snapshots.
- R2 MUST keep Runtime State parsing backward compatible when `tracker_kind` is absent.
- R3 MUST update Terminal Console and Web Dashboard wording away from GitHub/project-only labels.
- R4 MUST NOT add full local metadata dashboard rendering in V1.
- R5 MUST edit ReScript `.res` sources only and not commit generated `.res.js`.
</requirements>

## Subtasks
- [ ] 8.1 Add `tracker_kind` to backend Runtime State.
- [ ] 8.2 Include selected tracker kind when constructing Runtime State.
- [ ] 8.3 Update frontend Runtime State type/parsing with a safe default.
- [ ] 8.4 Replace dashboard copy such as "Project board" and "project issues" with tracker-neutral wording.
- [ ] 8.5 Add backend and frontend live-state parsing tests.

## Implementation Details
Follow TechSpec "API Endpoints" and "Runtime State additions". Keep UI changes scoped to copy and tracker context.

### Relevant Files
- `apps/backend/lib/runtime_state.ml` — Runtime State type and JSON serialization.
- `apps/backend/lib/orchestrator.ml` — Constructs Runtime State.
- `apps/backend/bin/main.ml` — Terminal copy and startup output.
- `apps/frontend/src/Main.res` — Runtime State frontend type and mapping.
- `apps/frontend/src/Pages/Dashboard.res` — Dashboard copy and labels.
- `apps/frontend/test/liveState.test.mjs` — Frontend live-state parsing tests.

### Dependent Files
- `apps/backend/lib/server.ml` — Serves Runtime State snapshots unchanged except payload content.
- `apps/frontend/src/LiveState.res` — Receives live snapshot payloads.
- `apps/backend/test/test_backend.ml` — Backend Runtime State JSON tests.

### Related ADRs
- [ADR-002: Prioritize a first-class local tracker experience for V1](adrs/adr-002.md) — Requires visible local tracker context.
- [ADR-006: Constrain V1 local identifiers and dashboard impact](adrs/adr-006.md) — Limits V1 dashboard scope.

## Deliverables
- Runtime State includes `tracker_kind`.
- Terminal and Web Dashboard wording is tracker-neutral.
- Frontend parsing remains backward compatible.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for live-state parsing **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] `Runtime_state.to_yojson` includes `tracker_kind` when provided.
  - [ ] Runtime State defaults remain compatible when tracker kind is omitted.
  - [ ] Frontend mapping handles snapshots with `tracker_kind = "minibeads"`.
  - [ ] Frontend mapping handles older snapshots without `tracker_kind`.
- Integration tests:
  - [ ] `pnpm frontend:test` passes after ReScript changes.
  - [ ] Backend Runtime State tests verify tracker kind in `/api/v1/state` payload shape.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Runtime State and dashboard copy no longer imply every tracker is GitHub Projects.
