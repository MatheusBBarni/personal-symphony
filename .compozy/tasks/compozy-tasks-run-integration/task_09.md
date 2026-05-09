---
status: completed
title: "Add Compozy progress to terminal and dashboard surfaces"
type: frontend
complexity: medium
dependencies:
  - task_05
  - task_08
---

# Task 09: Add Compozy progress to terminal and dashboard surfaces

## Overview
Expose Compozy PRD-run progress in operator-facing Runtime State surfaces. This task updates frontend parsing and compact dashboard/terminal wording without building a full project-management interface.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST parse optional `tracker_kind` and `compozy_progress` in frontend Runtime State.
- R2 MUST keep older Runtime State snapshots compatible.
- R3 MUST replace GitHub/project-specific wording where Compozy tracker runs need tracker-neutral labels.
- R4 MUST show compact PRD-run progress including current step, completed count, failed count, skipped count, and total count.
- R5 MUST NOT add full assignment, comments, history, or cross-workflow project-management UI.
- R6 MUST run ReScript/frontend verification after changes.
</requirements>

## Subtasks
- [x] 9.1 Add optional Compozy progress fields to ReScript Runtime State parsing.
- [x] 9.2 Update dashboard labels to be tracker-neutral where appropriate.
- [x] 9.3 Render compact PRD-run progress when Compozy progress is present.
- [x] 9.4 Update terminal output for Compozy progress if backend console rendering requires it.
- [x] 9.5 Add frontend tests and run ReScript build.

## Implementation Details
Reference TechSpec "Runtime State Projection" and "Monitoring and Observability". Keep UI changes compact and consistent with the existing operational dashboard.

### Relevant Files
- `apps/frontend/src/RuntimeStateSnapshot.res` — Typed snapshot parsing and dashboard model conversion.
- `apps/frontend/src/Pages/Dashboard.res` — Current dashboard copy and issue board rendering.
- `apps/frontend/src/AudioNotifications.res` — May need compatibility if Runtime State type changes.
- `apps/backend/bin/main.ml` — Terminal console summary rendering if backend output needs Compozy progress.

### Dependent Files
- `apps/backend/lib/runtime_state.ml` — Provides optional fields.
- `apps/frontend/src/*.res.js` — Generated files are ignored; do not commit them.

### Related ADRs
- [ADR-002: Treat a Compozy PRD run as the local issue](adrs/adr-002.md) — Requires PRD-run presentation.
- [ADR-005: Relaunch task steps sequentially in one worktree](adrs/adr-005.md) — Requires current-step visibility.
- [ADR-006: Configure task-step retries in Compozy tracker settings](adrs/adr-006.md) — Requires failed/skipped step visibility.

## Deliverables
- Frontend Runtime State parsing for Compozy progress.
- Compact dashboard/terminal progress display.
- Tracker-neutral wording for Compozy runs.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for frontend live-state rendering **(REQUIRED)**

## Tests
- Unit tests:
  - [x] Snapshot parsing succeeds when `tracker_kind` and `compozy_progress` are absent.
  - [x] Snapshot parsing captures Compozy current step and counts when present.
  - [x] Dashboard model exposes Compozy progress values.
- Integration tests:
  - [x] `pnpm frontend:test` covers Compozy Runtime State rendering.
  - [x] `pnpm frontend:build` succeeds after ReScript changes.
- Test coverage target: >=80%
- All tests must pass

Coverage note: this repository has no configured frontend coverage command or coverage dependency. Task 09 verification uses focused live-state/model/render assertions plus the required frontend test and build gates.

## Success Criteria
- All tests passing
- Test coverage >=80%
- Operators can see compact Compozy PRD-run progress.
- No generated `.res.js` files are committed.
