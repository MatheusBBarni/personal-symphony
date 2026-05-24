---
status: completed
title: Preserve Queue Presence in Terminal Console Projection
type: backend
complexity: medium
dependencies: []

---

# Task 01: Preserve Queue Presence in Terminal Console Projection

## Overview
Extend the Terminal Console projection so it preserves the semantic difference between no Ordered Queue and a present Ordered Queue with no visible rows. This gives later TUI work a reliable source for Queue tab visibility and status-first inspect content without changing Runtime State or orchestration behavior.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- MUST preserve `Runtime_state.ordered_queue = None` separately from `Some` queue values in `Terminal_console_model.t`.
- MUST keep present empty, completed, skipped, failed, filtered, and attention queue states representable for downstream TUI rendering.
- MUST expose inspect-ready status detail for task-like rows and readiness rows without adding lifecycle mutation behavior.
- MUST sanitize all projected display text using existing Terminal Console model sanitization patterns.
- MUST keep `Runtime_state.t` schema and runtime orchestration semantics unchanged.
</requirements>

## Subtasks
- [x] 1.1 Update the Terminal Console projection type to carry Queue presence.
- [x] 1.2 Preserve Queue presence during projection from `Runtime_state.t`.
- [x] 1.3 Add bounded inspect-detail projection helpers for task rows and readiness rows.
- [x] 1.4 Keep existing status, attention, Goal Usage, Goal Loop, and Context Status projection behavior intact.
- [x] 1.5 Add focused projection tests for absent Queue, present empty Queue, and inspect detail ordering.
- [x] 1.6 Confirm no Runtime State, Runtime Contract, or orchestration schema changes are introduced.

## Implementation Details
Modify the projection layer described in the TechSpec "Core Interfaces" and "Data Models" sections. Keep the change local to the read-only Terminal Console projection surface, and avoid adding a new module unless the existing projection file becomes materially harder to read.

### Relevant Files
- `apps/backend/lib/terminal_console_model.re` — Owns `Terminal_console_model.t`, Runtime State projection, display rows, sanitization, and status labels.
- `apps/backend/lib/runtime_state.re` — Defines `ordered_queue` as optional source data that must remain unchanged.
- `apps/backend/test/test_backend.ml` — Contains existing Terminal Console projection tests near the current model coverage.

### Dependent Files
- `apps/backend/bin/terminal_console_tui.re` — Will consume Queue presence and inspect details in later tasks.
- `apps/backend/bin/terminal_console_preview.ml` — May need compile compatibility if the projection type shape changes.
- `apps/backend/bin/dune` — Builds the Terminal Console shell against the projection type.

### Related ADRs
- [ADR-002: Adopt Unified Terminal Console Inspect Mode](adrs/adr-002.md) — Establishes unified inspect behavior across non-Logs tabs.
- [ADR-003: Use Status-First Inspect Mode for the PRD](adrs/adr-003.md) — Defines the product ordering for detail content.
- [ADR-004: Use Projection-Backed Inline Inspect State](adrs/adr-004.md) — Requires Queue presence and inspect-ready projection data.

## Deliverables
- Updated `Terminal_console_model.t` projection that preserves Queue presence.
- Projection helpers or fields that support status-first inspect detail for task-like and readiness rows.
- Focused model tests for Queue absence versus present empty Queue.
- Focused model tests for inspect detail content and sanitization.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for Terminal Console projection compatibility **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] `Runtime_state.ordered_queue = None` projects as Queue absent while keeping active tasks intact.
  - [ ] `Runtime_state.ordered_queue = Some { entries = [] }` projects as Queue present with zero Queue rows.
  - [ ] Queue entries with skipped, failed, completed, and attention states preserve status-first detail inputs.
  - [ ] Task-like inspect detail places status, blocker, error, remediation, and attention context before provenance and progress evidence.
  - [ ] Projected inspect detail sanitizes untrusted task titles, details, errors, and remediation text.
- Integration tests:
  - [ ] Existing Terminal Console model fixtures still compile and render from the updated projection shape.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Queue absence and present empty Queue are distinguishable from the projection alone.
- Inspect detail data is available without changing Runtime State or task lifecycle state.
- Existing Terminal Console projection behavior remains compatible except for the intentional Queue presence addition.
