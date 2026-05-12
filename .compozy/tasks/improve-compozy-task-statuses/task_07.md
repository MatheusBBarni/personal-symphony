---
status: pending
title: "Render lifecycle in the Web Dashboard"
type: frontend
complexity: medium
dependencies:
  - task_02
  - task_05
---

# Task 07: Render lifecycle in the Web Dashboard

## Overview
Update the Web Dashboard to parse and show the extended Compozy PRD Run lifecycle from Runtime State snapshots. The dashboard should make lifecycle, Stage Agent, PR readiness, and reasons visible without replacing existing Compozy Task Step progress counts.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST parse extended `compozy_progress` lifecycle fields from Runtime State snapshots in ReScript sources.
- R2 MUST render lifecycle state, PR readiness, Stage Agent, handoff status, and reason in the existing PRD run progress panel when present.
- R3 MUST keep current step, completed, failed, skipped, and total Compozy Task Step metrics visible.
- R4 MUST accept older snapshots without lifecycle fields without dashboard crashes.
- R5 MUST edit `.res` sources only and must not commit generated `apps/frontend/src/*.res.js` files.
- R6 SHOULD keep Web Dashboard copy consistent with Terminal Console labels from task_06.
</requirements>

## Subtasks
- [ ] 7.1 Extend ReScript Runtime State snapshot types for lifecycle and readiness fields.
- [ ] 7.2 Map lifecycle fields into the dashboard snapshot model.
- [ ] 7.3 Render lifecycle and PR readiness details in the PRD run progress panel.
- [ ] 7.4 Preserve existing step-count and current-step dashboard behavior.
- [ ] 7.5 Add frontend live-state and render tests for new fields and old snapshots.
- [ ] 7.6 Run ReScript/frontend verification without committing generated `.res.js` files.

## Implementation Details
Follow TechSpec "Frontend ReScript Dashboard" and "Monitoring and Observability". Keep the Live Dashboard Connection as Runtime State snapshots and limit V1 UI scope to the existing PRD run progress panel.

### Relevant Files
- `apps/frontend/src/RuntimeStateSnapshot.res` — Runtime State payload types and mapping into dashboard props.
- `apps/frontend/src/Pages/Dashboard.res` — Dashboard `compozyProgress` type and PRD run progress panel rendering.
- `apps/frontend/src/RuntimeState.res` — Existing normalization helpers for runtime snapshot values.
- `apps/frontend/test/liveState.test.mjs` — Live Dashboard Connection, snapshot mapping, and rendered markup tests.

### Dependent Files
- `apps/backend/lib/runtime_state.ml` — Backend JSON contract parsed by the frontend.
- `apps/backend/lib/server.ml` — Live Dashboard Connection source of Runtime State snapshots.
- `apps/frontend/src/*.res.js` — Generated ReScript files are ignored artifacts and must not be committed.

### Related ADRs
- [ADR-002: Use full V1 operator trust as the PRD product approach](adrs/adr-002.md) — Requires Web Dashboard lifecycle and readiness visibility in V1.
- [ADR-003: Persist dispatch-aware Compozy lifecycle in Runtime Home](adrs/adr-003.md) — Requires frontend consumers to read lifecycle fields from `compozy_progress`.

## Deliverables
- ReScript Runtime State snapshot parsing for extended `compozy_progress` fields.
- Web Dashboard PRD run progress panel displaying lifecycle, PR readiness, Stage Agent, handoff, and reason.
- Frontend tests covering lifecycle rendering and older snapshot compatibility.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for Live Dashboard Connection snapshot rendering **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] `snapshotFromState` maps `lifecycle_state`, `dispatch_state`, `stage_agent`, `pr_readiness`, `reason`, and `handoff_status` into dashboard props.
  - [ ] `snapshotFromState` accepts a Compozy progress payload without lifecycle fields and preserves existing count strings.
  - [ ] Dashboard markup contains lifecycle and PR readiness labels when fields are present.
  - [ ] Dashboard markup contains reason text for a not-PR-ready Compozy PRD Run.
  - [ ] Dashboard markup still shows current step, completed, failed, skipped, and total metrics.
- Integration tests:
  - [ ] Live Dashboard Connection test ingests extended Runtime State JSON and renders the PRD run progress panel without using fetch polling.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Web Dashboard users can identify Compozy PRD Run lifecycle and PR readiness from the existing dashboard.
- ReScript source changes build successfully and generated `.res.js` files remain uncommitted.
