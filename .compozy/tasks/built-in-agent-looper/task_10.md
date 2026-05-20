---
status: completed
title: "Render Goal Loop state in Web Dashboard"
type: frontend
complexity: medium
dependencies:
  - task_05
  - task_08

---

# Task 10: Render Goal Loop state in Web Dashboard

## Overview
This task exposes Goal Loop state in the Web Dashboard using the existing Runtime State live snapshot flow. It adds ReScript snapshot mapping and a focused dashboard card near Goal Usage and Context Status so the browser surface matches the backend and Terminal Console truth.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- REQ-01 MUST map `goal_loops` from Runtime State snapshots in ReScript.
- REQ-02 MUST render Goal Loop status, stop outcome, evidence, budget status, and next action in Web Dashboard task details.
- REQ-03 MUST preserve compatibility with snapshots that omit `goal_loops`.
- REQ-04 MUST keep Live Dashboard Connection as a Runtime State stream, not a command channel.
- REQ-05 MUST build ReScript output through the existing frontend build path and avoid committing generated `.res.js` files.
</requirements>

## Subtasks
- [ ] 10.1 Add Goal Loop snapshot types and mapping helpers.
- [ ] 10.2 Add dashboard issue/task association for Goal Loop state.
- [ ] 10.3 Render Goal Loop details near Goal Usage and Context Status.
- [ ] 10.4 Add old-snapshot compatibility tests.
- [ ] 10.5 Run frontend ReScript and live-state tests.

## Implementation Details
Use the TechSpec "API Endpoints" and "Surface Integration" sections. Keep the visual treatment work-focused and consistent with current Dashboard cards; do not add a new command surface.

### Relevant Files
- `apps/frontend/src/RuntimeStateSnapshot.res` — maps Runtime State JSON into Dashboard props.
- `apps/frontend/src/Pages/Dashboard.res` — renders task details, Goal Usage, Context Status, Harness, and Sandbox cards.
- `apps/frontend/src/LiveState.res` — consumes the live Runtime State stream.
- `apps/frontend/test/liveState.test.mjs` — existing live-state and snapshot compatibility tests.
- `.agents/rules/frontend.md` — package rules for frontend changes.

### Dependent Files
- `apps/backend/lib/runtime_state.ml` — source JSON shape from task_05.
- `apps/backend/lib/orchestrator.ml` — terminal loop states from task_08.
- `apps/backend/test/test_backend.ml` — backend snapshot tests that frontend relies on.

### Related ADRs
- [ADR-001: Goal Loop Runtime Scope](adrs/adr-001.md) — Requires Web Dashboard visibility.
- [ADR-003: Stage-Scoped Goal Loop Runtime State](adrs/adr-003.md) — Requires top-level Runtime State projection.

## Deliverables
- ReScript snapshot mapping for Goal Loop state.
- Web Dashboard rendering for Goal Loop details.
- Compatibility tests for snapshots without `goal_loops`.
- Unit tests with 80%+ coverage **(REQUIRED)**.
- Integration/live-state tests **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] Snapshot with `goal_loops` maps status, stop outcome, evidence, next action, and budget fields.
  - [ ] Snapshot without `goal_loops` renders without errors.
  - [ ] Dashboard card hides empty optional fields.
  - [ ] Dashboard card displays `needs_attention` and `budget_exhausted` distinctly.
- Integration tests:
  - [ ] Live-state test confirms Goal Loop data survives Runtime State mapping.
  - [ ] `pnpm frontend:build` succeeds without committing generated `.res.js` files.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Web Dashboard renders the same Goal Loop facts as Runtime State.
- Existing dashboard behavior remains compatible with old snapshots.
