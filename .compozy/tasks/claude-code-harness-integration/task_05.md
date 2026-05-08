---
status: pending
title: "Rename Runtime State Usage Totals And Expose Harness Identity"
type: backend
complexity: medium
dependencies:
  - task_02
  - task_04
---

# Task 05: Rename Runtime State Usage Totals And Expose Harness Identity

## Overview
This task makes Runtime State provider-neutral by renaming `codex_totals` to `usage_totals` and exposing selected Harness identity on running rows. It prepares the backend snapshot shape required by the frontend update.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- MUST remove `codex_totals` from Runtime State JSON.
- MUST expose provider-neutral `usage_totals` in Runtime State JSON.
- MUST add `harness_name` and `harness_kind` to running task rows.
- MUST update aggregate usage updates to write `usage_totals`.
- MUST preserve current Runtime State delivery endpoints and live snapshot model.
- MUST update backend tests that construct or inspect Runtime State rows.
</requirements>

## Subtasks
- [ ] 5.1 Rename backend Runtime State totals field to `usage_totals`.
- [ ] 5.2 Update Runtime State JSON serialization.
- [ ] 5.3 Add selected Harness name and kind to running rows.
- [ ] 5.4 Update orchestrator state updates to populate Harness identity.
- [ ] 5.5 Update backend token total aggregation from parsed output.
- [ ] 5.6 Update backend tests for the new Runtime State shape.

## Implementation Details
Modify `apps/backend/lib/runtime_state.ml` and `apps/backend/lib/orchestrator.ml`. Also check backend CLI summaries in `apps/backend/bin/main.ml` for Codex-specific naming. Reference TechSpec "Data Models" and ADR-004.

### Relevant Files
- `apps/backend/lib/runtime_state.ml` — owns Runtime State records and JSON serialization.
- `apps/backend/lib/orchestrator.ml` — owns running row creation and aggregate usage updates.
- `apps/backend/bin/main.ml` — may render token totals in terminal summaries.
- `apps/backend/test/test_backend.ml` — contains Runtime State JSON and orchestrator state assertions.

### Dependent Files
- `apps/frontend/src/Main.res` — frontend state type must change in task_06.
- `apps/frontend/test/liveState.test.mjs` — live-state fixture must change in task_06.
- `apps/backend/lib/server.ml` — consumes `Runtime_state.to_yojson` snapshots without endpoint changes.

### Related ADRs
- [ADR-004: Provider-Neutral Runtime State and Claude Stream Events](adrs/adr-004.md) — Selects immediate `usage_totals` rename and Harness identity exposure.

## Deliverables
- Runtime State backend record and JSON key renamed to `usage_totals`.
- Running rows include selected Harness name and kind.
- Backend tests updated for new snapshot shape.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for Runtime State snapshot output **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] `Runtime_state.to_yojson` includes `usage_totals`.
  - [ ] `Runtime_state.to_yojson` does not include `codex_totals`.
  - [ ] Running row JSON includes `harness_name`.
  - [ ] Running row JSON includes `harness_kind`.
  - [ ] Usage totals still increase when output parsing reports token usage.
- Integration tests:
  - [ ] Dispatching a Codex-selected task exposes `harness_name: "codex"` and `harness_kind: "codex"`.
  - [ ] Dispatching a Claude-selected task exposes `harness_name: "claude"` and `harness_kind: "claude"`.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Backend Runtime State no longer uses Codex-specific totals naming.
- Running task state identifies the selected Harness.
