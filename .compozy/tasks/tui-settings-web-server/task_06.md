---
status: completed
title: "Change `w` From Handoff to Start or Reuse Action"
type: backend
complexity: medium
dependencies:
  - task_03
  - task_04
  - task_05

---

# Task 06: Change `w` From Handoff to Start or Reuse Action

## Overview
This task changes the existing `w` key from guidance-only Web Dashboard handoff to the V1 start-or-reuse action. It must report started, reused, conflict, and failure outcomes in the Terminal Console without adding browser-open, stop, restart, or lifecycle controls.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- REQ-01 MUST make `w` call the dashboard start/reuse runtime callback.
- REQ-02 MUST show the dashboard URL when a dashboard is started.
- REQ-03 MUST show the dashboard URL when a compatible dashboard is reused.
- REQ-04 MUST show a clear conflict message for unrelated listeners or identity mismatches.
- REQ-05 MUST show a clear failure message when dashboard startup fails.
- REQ-06 MUST keep Terminal Console dashboard controls loopback-only in V1.
- REQ-07 MUST NOT mutate tracker status, queue state, Task Branches, pull requests, or orchestration lifecycle state.
- REQ-08 MUST update tests and labels that currently describe `w` as guidance-only.
- REQ-09 MUST stop using `Show_web_handoff` as the primary `w` action once the dashboard callback path is available.
</requirements>

## Subtasks
- [ ] 6.1 Review current `w` key handling, safe aid recording, and handoff tests.
- [ ] 6.2 Replace guidance-only behavior with dashboard callback invocation.
- [ ] 6.3 Render started, reused, conflict, failed, and unavailable dashboard statuses.
- [ ] 6.4 Keep local service action distinct from orchestration/task lifecycle controls.
- [ ] 6.5 Update Terminal Console tests and non-mutation assertions for the new `w` semantics.

## Implementation Details
Use the TechSpec "API Endpoints", "Monitoring and Observability", and "Known Risks" sections. The TUI should display concise local setup feedback and leave automatic browser opening out of scope.

### Relevant Files
- `apps/backend/bin/terminal_console_tui.ml` — Existing `w` key behavior, status messages, help/footer copy, and update loop.
- `apps/backend/bin/terminal_console_runtime.ml` — Runtime callback path from task 04.
- `apps/backend/bin/main.ml` — Supplies dashboard service callback and configured port.
- `apps/backend/lib/dashboard_service.re` — Result states from task 03.
- `apps/backend/lib/terminal_console_model.ml` — Current safe aid projection includes `Show_web_handoff`.
- `apps/backend/test/test_backend.ml` — Existing `w` handoff, safe aid, and non-mutation tests that need semantic updates.

### Dependent Files
- `apps/backend/lib/server.ml` — Dashboard server identity and Runtime State routes.
- `apps/backend/lib/terminal_console_settings.re` — Supplies persisted dashboard port used by the action.
- `CONTEXT.md` and `README.md` — Later task documents that `w` is now local service control.

### Related ADRs
- [ADR-001: Scope the Terminal Console Settings MVP](adrs/adr-001.md) — Defines `w` as idempotent Web Dashboard local service action.
- [ADR-002: Select Narrow Setup MVP Product Approach](adrs/adr-002.md) — Requires clear feedback for start, reuse, and conflict.
- [ADR-003: Terminal Console Settings and Dashboard Service Architecture](adrs/adr-003.md) — Requires identity-based reuse and lifecycle non-mutation.

## Deliverables
- `w` starts or reuses a compatible loopback Web Dashboard.
- User-facing status messages for started, reused, conflict, failure, and unavailable outcomes.
- Updated tests replacing guidance-only expectations.
- Unit tests with 80%+ coverage for key handling and status rendering **(REQUIRED)**.
- Integration tests for dashboard callback outcomes and non-mutation **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] `w` displays started dashboard URL when callback returns started.
  - [ ] `w` displays reused dashboard URL when callback returns reused.
  - [ ] `w` displays incompatible listener conflict text when callback returns conflict.
  - [ ] `w` displays startup failure text when callback returns failed.
  - [ ] `w` does not advertise guidance-only command text as the primary behavior.
  - [ ] Existing footer/help tests keep `w` discoverable without describing it as handoff-only.
- Integration tests:
  - [ ] `w` uses persisted dashboard port from Runtime Settings.
  - [ ] `w` starts or reuses a dashboard backed by the same Runtime State handoff.
  - [ ] `w` does not update tracker status, queues, Task Branches, pull requests, or orchestration lifecycle state.
  - [ ] Existing refresh and local path inspection aids remain non-mutating.
  - [ ] Existing safe-aid handler tests verify `w` through the dashboard callback path rather than `Show_web_handoff`.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Pressing `w` gives a working dashboard URL or a clear local failure reason.
- Compatible reuse is identity-based.
- Task lifecycle state remains protected.
- Focused runtime-state, server, and CLI tests pass before full backend verification.
