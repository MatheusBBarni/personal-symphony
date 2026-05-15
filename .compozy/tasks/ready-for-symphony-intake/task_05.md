---
status: pending
title: "Expose intake eligibility in Runtime State and dashboard"
type: frontend
complexity: high
dependencies:
  - task_04
---

# Task 05: Expose intake eligibility in Runtime State and dashboard

## Overview
Expose first-admission eligibility and blocking reasons through Runtime State so operators can tell why a work item will start, is waiting, or will not start. This task must keep intake explanations tracker-neutral and additive to existing Runtime State snapshots rather than replacing lifecycle, queue, or Compozy progress projections.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details - do not duplicate here
- FOCUS ON "WHAT" - describe what needs to be accomplished, not how
- MINIMIZE CODE - show code only to illustrate current structure or problem areas
- TESTS REQUIRED - every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST add a Runtime State projection for first-admission eligibility keyed to tracker-visible work items.
- R2 MUST surface tracker-neutral reasons for ready, not-ready, queue-blocked, or parse-blocked intake states without rewriting lifecycle semantics.
- R3 MUST keep frontend state decoding and dashboard rendering compatible with existing Runtime State snapshots.
- R4 MUST preserve Ordered Queue and Compozy progress views while adding intake-specific operator visibility.
- R5 MUST include backend and frontend test coverage for state serialization, snapshot decoding, and dashboard rendering of intake eligibility.
</requirements>

## Subtasks
- [ ] 5.1 Add intake-eligibility projection fields to Runtime State serialization and live state output.
- [ ] 5.2 Update frontend Runtime State decoding to understand the new intake-eligibility shape.
- [ ] 5.3 Render tracker-neutral intake explanations in dashboard state views without collapsing existing lifecycle or queue status.
- [ ] 5.4 Extend backend and frontend tests for state projection and UI rendering compatibility.

## Implementation Details
Reference the TechSpec "API Endpoints", "Runtime State Projection", and "Monitoring and Observability" sections. Keep this task focused on state projection and operator visibility; it should not change tracker semantics, queue policy, or run lifecycle ownership introduced by earlier tasks.

### Relevant Files
- `apps/backend/lib/runtime_state.ml` - Runtime State model and JSON projection that should gain intake-eligibility fields.
- `apps/backend/lib/server.ml` - State API endpoints that must expose the new projection consistently.
- `apps/frontend/src/RuntimeStateSnapshot.res` - Frontend decoder for Runtime State snapshots.
- `apps/frontend/src/Pages/Dashboard.res` - Web Dashboard rendering of runtime status and tracker-facing explanations.
- `apps/backend/test/test_backend.ml` - Backend state snapshot tests to extend with the new fields.

### Dependent Files
- `apps/backend/bin/terminal_console_runtime.ml` - Terminal Console consumers may reuse the new intake-eligibility messages.
- `apps/backend/lib/terminal_console_model.ml` - Shared console projection may need the same intake-eligibility view as the dashboard.
- `apps/frontend/src` - Other snapshot consumers may need decoding compatibility if they read shared Runtime State types.
- `README.md` - Later docs task will explain new operator-facing intake diagnostics.

### Related ADRs
- [ADR-003: Put Symphony-ready status at the tracker boundary with exact-match first-admission semantics](adrs/adr-003.md) - Requires runtime visibility for first-admission rules.
- [ADR-004: Read Compozy Symphony-ready status from _tasks.md while keeping task-step state separate](adrs/adr-004.md) - Intake visibility must not blur Compozy lifecycle and task-step semantics.

## Deliverables
- Runtime State projection for intake eligibility and blocking reasons.
- Frontend decoding and dashboard rendering for tracker-neutral intake explanations.
- Backend and frontend tests covering serialization, snapshot compatibility, and UI rendering.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for state and dashboard behavior **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Runtime State JSON includes intake-eligibility fields for ready and non-ready tracker-visible items.
  - [ ] Frontend Runtime State snapshot decoding accepts the new fields without breaking existing snapshots.
  - [ ] Dashboard rendering distinguishes intake-blocked items from terminal or lifecycle-completed items.
- Integration tests:
  - [ ] Live state output shows queue-blocked or not-ready reasons while preserving Ordered Queue progress.
  - [ ] Compozy runs with ready-status parse failures surface intake-specific explanations without replacing Compozy PRD Run progress rendering.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Operators can see why tracker-visible work is ready, blocked, or excluded from first admission.
- Runtime State and dashboard consumers gain intake visibility without regressing existing queue or lifecycle views.
