---
status: pending
title: "Wire Runtime Callbacks Into Terminal Console"
type: backend
complexity: medium
dependencies:
  - task_01
  - task_03
---

# Task 04: Wire Runtime Callbacks Into Terminal Console

## Overview
This task connects the persistence and dashboard service layers to the Terminal Console runtime without adding the final settings modal UI. It gives the TUI runtime explicit callbacks for loading settings, saving settings, and starting or reusing the dashboard against the active Runtime State handoff.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- REQ-01 MUST extend Terminal Console runtime wiring with settings and dashboard callbacks.
- REQ-02 MUST pass callbacks through readiness-blocked and orchestrator Terminal Console branches.
- REQ-03 MUST ensure dashboard callbacks use the same Runtime State handoff the Terminal Console displays.
- REQ-04 MUST surface callback failures as Terminal Console status results rather than process crashes where practical.
- REQ-05 MUST preserve existing safe local aid behavior for refresh and path inspection.
- REQ-06 MUST keep orchestration lifecycle state untouched by callback wiring.
- REQ-07 MUST ensure dashboard callbacks read the latest handoff state, not only the initial Runtime State snapshot.
</requirements>

## Subtasks
- [ ] 4.1 Review Terminal Console runtime handoff and current safe aid callback wiring.
- [ ] 4.2 Add callback fields to the Terminal Console runtime contract used by the TUI shell.
- [ ] 4.3 Wire settings persistence callbacks from runtime startup into Terminal Console modes.
- [ ] 4.4 Wire dashboard start/reuse callbacks to the active Runtime State handoff.
- [ ] 4.5 Add tests for callback propagation, failure reporting, and non-mutation.

## Implementation Details
Use the TechSpec "Component Overview" and "Development Sequencing" sections. This task should create the runtime plumbing that task 05 and task 06 consume, while keeping product-specific UI behavior in backend Terminal Console files.

### Relevant Files
- `apps/backend/bin/terminal_console_runtime.ml` — Runtime State handoff and Terminal Console runtime construction.
- `apps/backend/bin/main.ml` — Builds Terminal Console runtime inputs for readiness and orchestrator branches.
- `apps/backend/bin/terminal_console_tui.ml` — Runtime record shape consumed by the TUI shell.
- `apps/backend/bin/terminal_console_preview.ml` — Preview runtime may need default callbacks.
- `apps/backend/lib/terminal_console_model.ml` — Current safe aid model still includes `Show_web_handoff`; keep safe-aid changes deliberate.
- `apps/backend/test/test_backend.ml` — Existing tests for safe aids, handoff, readiness mode, and orchestrator notifications.

### Dependent Files
- `apps/backend/lib/terminal_console_settings.re` — Provides settings load/save callbacks from task 01.
- `apps/backend/lib/dashboard_service.re` — Provides dashboard start/reuse callback from task 03.
- `apps/backend/lib/server.ml` — Serves the Web Dashboard started through dashboard callbacks.

### Related ADRs
- [ADR-001: Scope the Terminal Console Settings MVP](adrs/adr-001.md) — Requires local service action without orchestration mutation.
- [ADR-003: Terminal Console Settings and Dashboard Service Architecture](adrs/adr-003.md) — Selects runtime callbacks and shared Runtime State handoff.

## Deliverables
- Terminal Console runtime callbacks for settings and dashboard actions.
- Main runtime startup wiring for readiness-blocked and orchestrator modes.
- Preview-safe defaults for any new runtime fields.
- Unit tests with 80%+ coverage for callback wiring **(REQUIRED)**.
- Integration tests for handoff sharing and non-mutation **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] Runtime construction includes default settings and dashboard callbacks when none are provided.
  - [ ] Readiness Terminal Console mode receives settings and dashboard callbacks.
  - [ ] Orchestrator Terminal Console mode receives settings and dashboard callbacks.
  - [ ] Callback failure is converted into a status result visible to the TUI layer.
  - [ ] Existing `test_terminal_console_runtime_safe_aid_handler_records_non_mutating_aids` is updated if `w` stops using the safe-aid path.
- Integration tests:
  - [ ] Dashboard callback reads the latest Runtime State handoff after a published state update.
  - [ ] Existing refresh safe aid still records only `Refresh_view`.
  - [ ] Existing path inspection remains validated and UI-local.
  - [ ] Callback wiring does not mutate tracker status, queue state, Task Branches, or orchestration lifecycle state.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- TUI code can call settings and dashboard actions through explicit runtime callbacks.
- Dashboard startup uses the same Runtime State stream as the visible Terminal Console.
- Existing non-mutating Terminal Console aids remain intact.
- `terminal_console_preview.ml` remains runnable with default no-op callbacks.
