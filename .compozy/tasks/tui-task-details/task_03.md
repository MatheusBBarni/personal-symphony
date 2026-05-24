---
status: pending
title: Add Enter-Toggled Inline Inspect Mode
type: backend
complexity: medium
dependencies:
  - task_01
  - task_02
---

# Task 03: Add Enter-Toggled Inline Inspect Mode

## Overview
Add explicit inspect state to the Terminal Console interaction model and use Enter to toggle inline details for Queue, Tasks, Readiness, and Needs attention. Logs remains scroll-focused and excluded from inspect mode.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- MUST use Enter in normal mode to toggle inspect details for Queue, Tasks, Readiness, and Needs attention.
- MUST leave Enter behavior in search and settings modes unchanged.
- MUST leave Logs unchanged: Enter does not open inspect mode and Logs scrolling remains the only row interaction.
- MUST render detail inline beneath the selected row rather than in a modal or split pane.
- MUST lead inspect content with status, blockers, errors, remediation, and next attention before provenance or progress evidence.
- MUST keep inspect mode read-only and avoid emitting lifecycle, tracker, git, or safe-aid actions.
</requirements>

## Subtasks
- [ ] 3.1 Add interaction state for the currently inspected tab and row.
- [ ] 3.2 Toggle inspect state with Enter only for inspectable tabs in normal mode.
- [ ] 3.3 Clear or clamp inspect state when selection, active tab, filter, or snapshot changes make the target invalid.
- [ ] 3.4 Render inline details below selected Queue, Tasks, Readiness, and Needs attention rows.
- [ ] 3.5 Keep Logs Enter behavior as a no-op while preserving scroll behavior.
- [ ] 3.6 Add focused tests for inspect toggling, inline rendering, exclusion, and read-only transitions.

## Implementation Details
Use the projection details from Task 01 and visible-tab behavior from Task 02. Reference the TechSpec "Core Interfaces", "Testing Approach", and ADR-005 for key handling and status-first detail ordering; do not duplicate the shape-only interface in the task implementation.

### Relevant Files
- `apps/backend/bin/terminal_console_tui.re` — Owns interaction state, key handling, row rendering, Queue panel, Tasks panel, Readiness panel, Attention panel, and existing task detail panel helpers.
- `apps/backend/lib/terminal_console_model.re` — Provides projected status, detail, error, Goal Usage, Goal Loop, Context Status, queue, readiness, and attention data.
- `apps/backend/test/test_backend.ml` — Contains current key transition, row rendering, Queue expansion, and task detail tests.

### Dependent Files
- `apps/backend/bin/terminal_console_preview.ml` — Useful for manual visual confirmation of inline detail placement.
- `apps/backend/bin/dune` — Compiles shell and preview entrypoints that consume the changed TUI module.
- `.agents/rules/backend.md` — Requires focused Alcotest coverage for Terminal Console behavior changes.

### Related ADRs
- [ADR-002: Adopt Unified Terminal Console Inspect Mode](adrs/adr-002.md) — Requires the shared inspect experience across non-Logs tabs.
- [ADR-003: Use Status-First Inspect Mode for the PRD](adrs/adr-003.md) — Requires status-first inspect content ordering.
- [ADR-004: Use Projection-Backed Inline Inspect State](adrs/adr-004.md) — Requires inline inspect state backed by projection data.
- [ADR-005: Use Enter for Inspect and Keep Space Queue-Compatible](adrs/adr-005.md) — Defines Enter as the inspect key and excludes Logs.

## Deliverables
- TUI interaction state for inline inspect targets.
- Enter key handling for inspectable tabs with search/settings Enter behavior preserved.
- Inline detail rendering for Queue, Tasks, Readiness, and Needs attention.
- Focused tests proving Logs ignores inspect mode and inspect transitions are read-only.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for inline inspect rendering **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Enter on a selected Queue row toggles inline inspect detail for that row.
  - [ ] Enter on a selected Tasks row toggles inline inspect detail for that row.
  - [ ] Enter on a selected Readiness row toggles inline remediation detail for that row.
  - [ ] Enter on a selected Needs attention row toggles inline inspect detail for that row.
  - [ ] Enter on Logs leaves inspect state closed and preserves existing scroll behavior.
  - [ ] Search mode Enter and settings mode Enter continue to perform their existing flows.
  - [ ] Inspect toggling leaves snapshot identity unchanged and emits no lifecycle mutation safe aids.
- Integration tests:
  - [ ] Render output places inline detail directly under the selected inspected row.
  - [ ] Filter or snapshot changes clamp or clear invalid inspect targets without stale detail output.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Enter toggles inline inspect details for all V1 inspectable tab families.
- Logs remains excluded from inspect mode.
- Inspect behavior is visibly status-first and read-only.
