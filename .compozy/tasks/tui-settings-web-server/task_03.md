---
status: pending
title: "Extract Dashboard Start and Reuse Service"
type: backend
complexity: high
dependencies:
  - task_02
---

# Task 03: Extract Dashboard Start and Reuse Service

## Overview
This task extracts Web Dashboard startup into a reusable backend service that can be called from both CLI Web Dashboard mode and the Terminal Console. The service must start loopback dashboards in the background for Terminal Console use, reuse compatible dashboards by identity, and report conflicts clearly.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- REQ-01 MUST add a backend ReasonML dashboard service for start, reuse, conflict, and failure outcomes.
- REQ-02 MUST probe the identity endpoint before reusing an existing listener.
- REQ-03 MUST treat mismatched Workspace Repository, mismatched Runtime Home, mismatched mode, or missing identity as conflicts.
- REQ-04 MUST start Terminal Console dashboard servers on loopback only.
- REQ-05 MUST run the blocking `Server.serve` loop on a background thread when called from Terminal Console mode.
- REQ-06 MUST preserve existing `symphony --web` foreground behavior and startup messaging.
- REQ-07 MUST not log token values or local secret contents.
- REQ-08 MUST keep Terminal Console-backed dashboards tied to the active Runtime State handoff and broadcast state changes through the Live Dashboard Connection.
</requirements>

## Subtasks
- [ ] 3.1 Review current Web Dashboard startup branches in `main.ml`.
- [ ] 3.2 Add dashboard service outcomes for started, reused, conflict, and failed states.
- [ ] 3.3 Add identity probing and compatibility checks for the configured loopback port.
- [ ] 3.4 Extract foreground and background server startup paths without changing existing CLI behavior.
- [ ] 3.5 Add tests for no-listener startup, compatible reuse, incompatible listener, and bind failure behavior.

## Implementation Details
Use the TechSpec "Component Overview", "Integration Points", and "Monitoring and Observability" sections. Keep the service backend-owned and avoid adding stop, restart, kill, or browser-open controls.

### Relevant Files
- `apps/backend/lib/dashboard_service.re` — New ReasonML module for identity probing and dashboard start/reuse outcomes.
- `apps/backend/lib/server.ml` — Existing blocking server loop and identity route from task 02.
- `apps/backend/lib/dune` — Library stanza may need to include the new service module.
- `apps/backend/bin/main.ml` — Current CLI Web Dashboard startup path to extract or reuse.
- `apps/backend/bin/terminal_console_runtime.ml` — Runtime State handoff that later Terminal Console dashboard startup must share.
- `apps/backend/lib/runtime_home.ml` — Workspace Repository and Runtime Home values for identity matching.
- `apps/backend/lib/config.ml` — Server host and port config shape.
- `apps/backend/test/test_backend.ml` — Existing CLI/server tests and new dashboard service tests.

### Dependent Files
- `apps/backend/bin/terminal_console_runtime.ml` — Later task will call the service from Terminal Console runtime callbacks.
- `apps/backend/bin/terminal_console_tui.ml` — Later task will render started, reused, conflict, and failed messages.
- `README.md` — Later task will document start/reuse behavior after it is wired into the TUI.

### Related ADRs
- [ADR-001: Scope the Terminal Console Settings MVP](adrs/adr-001.md) — Changes `w` from handoff to local service action.
- [ADR-002: Select Narrow Setup MVP Product Approach](adrs/adr-002.md) — Keeps dashboard controls loopback-only.
- [ADR-003: Terminal Console Settings and Dashboard Service Architecture](adrs/adr-003.md) — Selects in-process dashboard service and identity reuse.

## Deliverables
- Dashboard service with explicit result states.
- Identity-based reuse and conflict detection.
- Shared startup path that preserves `symphony --web`.
- Unit tests with 80%+ coverage for compatibility decisions **(REQUIRED)**.
- Integration tests for service startup and CLI behavior preservation **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] Matching identity for the same Workspace Repository and Runtime Home returns a reuse result.
  - [ ] Mismatched Workspace Repository returns a conflict result.
  - [ ] Mismatched Runtime Home returns a conflict result.
  - [ ] Auth mismatch returns a conflict result.
  - [ ] Missing or malformed identity response returns a conflict result instead of reuse.
  - [ ] Bind failure returns a failed result with a secret-free message.
- Integration tests:
  - [ ] No listener on the configured loopback port starts a dashboard service.
  - [ ] Compatible existing listener is reused without starting a second server.
  - [ ] Started dashboard serves the current Runtime State.
  - [ ] Live Dashboard Connection receives updates when the Terminal Console handoff publishes state.
  - [ ] Existing `symphony --web` readiness-state path still serves Runtime State.
  - [ ] Existing `symphony --web` orchestrator path still serves live Runtime State.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Dashboard reuse is identity-based, not port-only.
- Terminal Console callers can start a loopback dashboard without blocking the UI loop.
- Existing Web Dashboard CLI behavior remains equivalent.
- Focused server, runtime-state, and CLI Alcotest coverage passes before full backend verification.
