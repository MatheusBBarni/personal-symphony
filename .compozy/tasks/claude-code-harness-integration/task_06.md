---
status: completed
title: "Update Frontend Live State And Dashboard For Provider-Neutral State"
type: frontend
complexity: medium
dependencies:
  - task_05
---

# Task 06: Update Frontend Live State And Dashboard For Provider-Neutral State

## Overview
This task updates the ReScript frontend to consume provider-neutral Runtime State from the backend. It replaces `codex_totals` usage, accepts Harness identity on running rows, and displays mixed-Harness runs without Codex-specific assumptions.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- MUST edit `.res` sources only for frontend implementation.
- MUST NOT commit generated `apps/frontend/src/*.res.js` files.
- MUST rename frontend Runtime State typing from `codex_totals` to `usage_totals`.
- MUST accept `harness_name` and `harness_kind` in running task rows.
- SHOULD display selected Harness identity in dashboard task details or cards.
- MUST update live-state tests for the new snapshot shape.
</requirements>

## Subtasks
- [x] 6.1 Update ReScript Runtime State types to use `usage_totals`.
- [x] 6.2 Add Harness identity fields to frontend running row types.
- [x] 6.3 Update dashboard snapshot derivation for token totals.
- [x] 6.4 Surface Harness identity in the dashboard where running task details are shown.
- [x] 6.5 Update frontend live-state tests with `usage_totals` and Harness fields.
- [x] 6.6 Run ReScript/frontend verification commands.

## Implementation Details
Modify `apps/frontend/src/Main.res` and related `.res` files only. Reference the TechSpec "Runtime State changes" and task_05 backend output shape. Build-generated `.res.js` files are ignored and must not be committed.

### Relevant Files
- `apps/frontend/src/Main.res` — owns Runtime State decoding types and snapshot mapping.
- `apps/frontend/src/Pages/Dashboard.res` — owns dashboard display of running tasks and summary data.
- `apps/frontend/test/liveState.test.mjs` — tests live-state snapshot handling.

### Dependent Files
- `apps/backend/lib/runtime_state.ml` — task_05 defines the backend JSON shape this task consumes.
- `apps/frontend/rescript.json` — existing build configuration for ReScript compilation.
- `apps/frontend/package.json` — frontend test/build scripts.

### Related ADRs
- [ADR-004: Provider-Neutral Runtime State and Claude Stream Events](adrs/adr-004.md) — Requires provider-neutral totals and Harness identity in Runtime State.

## Deliverables
- Frontend state types updated for `usage_totals`.
- Dashboard uses provider-neutral totals and displays selected Harness identity.
- Frontend live-state tests updated for new snapshot shape.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for live-state snapshot handling **(REQUIRED)**

## Tests
- Unit tests:
  - [x] Live-state snapshot with `usage_totals.total_tokens` maps to the dashboard token summary.
  - [x] Live-state snapshot without `codex_totals` does not fail decoding.
  - [x] Running row with `harness_name` and `harness_kind` is accepted.
  - [x] Running row without Harness fields remains tolerated only if backend compatibility requires it.
- Integration tests:
  - [x] `pnpm frontend:test` passes with updated live-state fixtures.
  - [x] `pnpm frontend:build` passes after ReScript changes.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Frontend no longer references `codex_totals`.
- Dashboard gives operators visibility into selected Harness identity.
