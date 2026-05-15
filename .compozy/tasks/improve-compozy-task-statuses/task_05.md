---
status: completed
title: "Align Dashboard snapshot parsing and rendering with the shared Compozy status contract"
type: frontend
complexity: medium
dependencies:
  - task_04

---

# Task 05: Align Dashboard snapshot parsing and rendering with the shared Compozy status contract

## Overview
Bring the Web Dashboard into line with the backend contract so operators see the same Compozy PRD Run story in the browser that they see in Runtime State and the Terminal Console. This task keeps the frontend payload mapping backward-compatible while making lifecycle, readiness, reason, and handoff details clear alongside step counts.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST parse the existing `compozy_progress` payload fields without inventing alternate lifecycle or readiness semantics.
- R2 MUST preserve compatibility for older snapshots that omit lifecycle-related fields.
- R3 MUST render lifecycle, dispatch state, stage agent, readiness, handoff status, and reason distinctly from step-count progress.
- R4 MUST keep the dashboard wording and data model aligned with the backend payload and approved operator terminology.
- R5 MUST update only `.res` sources and must not commit generated `.res.js` files.
- R6 MUST include live-state tests that verify lifecycle-rich and legacy Compozy snapshots.
</requirements>

## Subtasks
- [x] 5.1 Audit frontend snapshot parsing for lifecycle-rich and lifecycle-absent Compozy payloads.
- [x] 5.2 Align dashboard data mapping with the backend payload field semantics.
- [x] 5.3 Tighten Compozy PRD Run panel rendering for lifecycle, readiness, handoff, and reason details.
- [x] 5.4 Keep current-step and count presentation separate from lifecycle and readiness presentation.
- [x] 5.5 Expand frontend live-state and render tests, then rebuild frontend artifacts without committing generated files.

## Implementation Details
Reference TechSpec "Shared Runtime State payload", "API Endpoints", and "Testing Approach". Keep the work in ReScript source files plus the existing live-state test file; generated `apps/frontend/src/*.res.js` files remain ignored.

### Relevant Files
- `apps/frontend/src/RuntimeStateSnapshot.res` — Parses optional lifecycle fields and maps them into dashboard snapshot structures.
- `apps/frontend/src/Pages/Dashboard.res` — Renders Compozy PRD Run progress, lifecycle, readiness, handoff, and reason details.
- `apps/frontend/test/liveState.test.mjs` — Already verifies Compozy snapshot parsing and dashboard markup, and should be extended with the final contract cases.

### Dependent Files
- `apps/backend/lib/runtime_state.ml` — Supplies the payload shape and semantics the frontend must match.
- `apps/backend/lib/terminal_console.ml` — Backend console rendering should stay semantically aligned with dashboard rendering.
- `README.md` — Operator documentation should describe the same visible fields the dashboard renders.

### Related ADRs
- [ADR-005: Use a cross-surface transition contract as the PRD approach](adrs/adr-005.md) — Requires the Dashboard to tell the same story as other operator surfaces.
- [ADR-006: Reconcile Compozy lifecycle from task-step progress while keeping readiness separate](adrs/adr-006.md) — Requires the frontend to preserve the separation between progress, lifecycle, dispatch, and readiness fields.

## Deliverables
- Frontend snapshot parsing aligned with the shared Compozy payload contract.
- Dashboard rendering that shows lifecycle, readiness, handoff, and reason without obscuring task-step progress.
- Frontend live-state tests and build verification covering lifecycle-rich and legacy Compozy snapshots.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for Dashboard lifecycle and readiness rendering **(REQUIRED)**

## Tests
- Unit tests:
  - [x] Snapshot parsing preserves lifecycle-rich Compozy payload fields including `lifecycle_state`, `dispatch_state`, `pr_readiness`, `reason`, and `handoff_status`.
  - [x] Snapshot parsing preserves backward compatibility when lifecycle fields are absent.
  - [x] Dashboard snapshot mapping keeps current-step counts separate from lifecycle and readiness fields.
- Integration tests:
  - [x] Dashboard markup for a lifecycle-rich Compozy payload shows lifecycle, dispatch state, stage agent, readiness, handoff, reason, and counts together.
  - [x] Dashboard markup for a legacy Compozy payload still shows current-step and count information without lifecycle placeholders.
  - [x] `pnpm frontend:test` and `pnpm frontend:build` pass after ReScript source updates.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- The Web Dashboard reflects the same Compozy status contract exposed by Runtime State and the Terminal Console.
- Legacy snapshots still render safely while lifecycle-rich snapshots show the full operator-facing story.
