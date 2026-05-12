---
status: pending
title: "Build Terminal Console View-Model Projection"
type: backend
complexity: medium
dependencies: []
---

# Task 01: Build Terminal Console View-Model Projection

## Overview
Build the pure backend projection that turns Runtime State into the Terminal Console view model required by the Mosaic MVP. This task creates the safety and classification boundary that later UI and runtime tasks depend on, without introducing Mosaic or changing orchestration behavior.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- MUST create a pure Terminal Console view-model projection from `Runtime_state.t` as described in the TechSpec "Core Interfaces" and "Data Models" sections.
- MUST classify Runtime State into MVP display modes for idle, running, retrying, attention, and readiness-blocked scenarios.
- MUST expose projected rows for active work, Readiness Gaps, Ordered Queue entries, Compozy PRD Run progress, Goal Usage, context status, and last error summaries.
- MUST sanitize untrusted display text before it reaches any Terminal Console renderer.
- MUST NOT change `Runtime_state.t`, Runtime State JSON, orchestration behavior, tracker semantics, or task lifecycle behavior.
- SHOULD keep the projection small and limited to fields required by the MVP panels and safe aids.
</requirements>

## Subtasks
- [ ] 1.1 Add the Terminal Console projection module in the backend library.
- [ ] 1.2 Add display-mode classification for Runtime State scenarios required by the PRD.
- [ ] 1.3 Add sanitized task, readiness, queue, and Compozy progress rows for downstream rendering.
- [ ] 1.4 Add safe-aid descriptors for non-mutating MVP actions.
- [ ] 1.5 Add focused backend tests for projection behavior and sanitization.
- [ ] 1.6 Confirm no Runtime State schema or orchestration code changes are introduced.

## Implementation Details
Create `apps/backend/lib/terminal_console_model.ml` and expose it through the existing backend library. Keep the module pure and Mosaic-independent. Reference the TechSpec "Core Interfaces", "Terminal Console View Model", and "Sanitization Model" sections for the expected projection boundary.

Add targeted test cases in `apps/backend/test/test_backend.ml` near the existing Runtime State serialization and live-state tests. Do not split the large backend test file as part of this task.

### Relevant Files
- `apps/backend/lib/runtime_state.ml` — Source data model for the projection.
- `apps/backend/lib/issue.ml` — Issue fields used in task rows.
- `apps/frontend/src/RuntimeStateSnapshot.res` — Existing Web Dashboard projection to compare display semantics, not to copy implementation.
- `apps/backend/test/test_backend.ml` — Existing Alcotest suite and Runtime State fixture patterns.
- `apps/backend/lib/dune` — Backend library module discovery and dependencies.

### Dependent Files
- `apps/backend/bin/terminal_console_mosaic.ml` — Later renderer will consume this projection.
- `apps/backend/bin/main.ml` — Later runtime wiring will pass Runtime State through this projection.
- `apps/backend/lib/runtime_state.ml` — Must remain schema-compatible; tests should guard against unnecessary changes.

### Related ADRs
- [ADR-001: Scope Mosaic Terminal Console as a Runtime State command center](adrs/adr-001.md) — Requires Runtime State to remain the visible source of truth.
- [ADR-002: Make the read-first Terminal Console with safe local aids the MVP approach](adrs/adr-002.md) — Defines the non-mutating MVP scope.
- [ADR-005: Use a pure Terminal Console view-model projection](adrs/adr-005.md) — Primary technical decision implemented by this task.

## Deliverables
- `Terminal_console_model` backend module with Runtime State projection and sanitization.
- Projected data for active work, readiness, queue, Compozy progress, and safe-aid availability.
- Unit tests with 80%+ coverage for the new projection module **(REQUIRED)**.
- Integration-oriented tests that verify projection from representative Runtime State fixtures **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] Empty Runtime State projects to idle mode with no active rows.
  - [ ] Runtime State with one running issue projects to running mode with sanitized issue identifier and title.
  - [ ] Runtime State with retrying work projects retry attempt, due time, and error summary.
  - [ ] Runtime State with `issue_errors` projects attention mode and task error summaries.
  - [ ] Runtime State with Readiness Gaps projects requirement/remediation pairs and readiness-blocked mode when no work is active.
  - [ ] Ordered Queue entries project pending/running/retrying/completed/skipped states and skip reasons.
  - [ ] Compozy PRD Run progress projects current step and completed/failed/skipped/total counts.
  - [ ] Sanitization strips ANSI escape sequences and unsafe control characters from issue titles, branch-like text, and agent messages.
- Integration tests:
  - [ ] Existing Runtime State JSON tests still pass without schema changes.
  - [ ] Projection fixtures cover Goal Usage and context status fields already exposed by Runtime State.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Runtime State JSON remains backward-compatible.
- No task lifecycle mutation or tracker behavior is added.
- Downstream Mosaic tasks can render from the projection without importing raw orchestration state.
