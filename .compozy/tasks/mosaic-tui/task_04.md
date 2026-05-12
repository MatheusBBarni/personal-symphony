---
status: pending
title: "Render MVP Active-Run Panels"
type: backend
complexity: high
dependencies:
  - task_03
---

# Task 04: Render MVP Active-Run Panels

## Overview
Implement the Mosaic panels that make the default Terminal Console useful for active-run comprehension. This task renders the read-first MVP surfaces from the view-model projection: active work, readiness and attention, Ordered Queue progress, Compozy PRD Run progress, and task details.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- MUST render an Active Work Home View that answers what is happening now without requiring navigation.
- MUST render running work, retrying work, task attention conditions, next queued work, token totals, and last state update context when present.
- MUST render Readiness Gaps and remediation text while preserving readability in narrow terminal widths.
- MUST render Ordered Queue entry states, skipped-entry reasons, and next work when queue state exists.
- MUST render Compozy PRD Run current step and completed/failed/skipped/total counts when present.
- MUST render task detail summaries for issue metadata, stage state, harness identity, Goal Usage, context status, and current error summaries when present.
- MUST keep the UI usable without color and avoid overwhelming users with full logs by default.
</requirements>

## Subtasks
- [ ] 4.1 Add the Active Work Home View layout.
- [ ] 4.2 Add Readiness and Attention panels.
- [ ] 4.3 Add Ordered Queue and Compozy PRD Run progress panels.
- [ ] 4.4 Add task detail summary panels for selected active work.
- [ ] 4.5 Add responsive behavior for minimum terminal dimensions and narrow widths.
- [ ] 4.6 Add rendering tests or projection-backed snapshot tests for MVP panel states.

## Implementation Details
Modify `apps/backend/bin/terminal_console_mosaic.ml` and supporting executable-side modules. Render from `Terminal_console_model.t` only. Reference the TechSpec "Component Overview", "Terminal Environment", and "Testing Approach" sections for panel boundaries and validation expectations.

Use TUI design principles: fixed panel positions where possible, contextual footer visibility, no color-only meaning, and a clear minimum-size message. Keep full logs out of the default panels.

### Relevant Files
- `apps/backend/bin/terminal_console_mosaic.ml` — Mosaic rendering implementation.
- `apps/backend/lib/terminal_console_model.ml` — Source projection for panel data.
- `apps/frontend/src/Pages/Dashboard.res` — Existing dashboard display priorities for Runtime State, Ordered Queue, and Compozy progress.
- `apps/frontend/src/RuntimeStateSnapshot.res` — Existing mapping for Goal Usage, context status, readiness text, and queue progress.
- `apps/backend/test/test_backend.ml` — Location for focused backend panel/projection tests.

### Dependent Files
- `apps/backend/bin/main.ml` — Uses the Mosaic runtime wired in task 03.
- `apps/backend/lib/runtime_state.ml` — Must remain unchanged unless a genuine PRD display gap is discovered.
- `CONTEXT.md` — Domain language must remain consistent if labels are documented later.

### Related ADRs
- [ADR-001: Scope Mosaic Terminal Console as a Runtime State command center](adrs/adr-001.md) — Requires Runtime State-backed presentation.
- [ADR-002: Make the read-first Terminal Console with safe local aids the MVP approach](adrs/adr-002.md) — Defines active-run comprehension as the MVP focus.
- [ADR-005: Use a pure Terminal Console view-model projection](adrs/adr-005.md) — Requires rendering through the projected model.

## Deliverables
- Mosaic Active Work Home View.
- Readiness and Attention panels with remediation text.
- Ordered Queue and Compozy progress panels.
- Task detail summary panel for active/retrying/attention work.
- Responsive minimum-size and no-color friendly rendering behavior.
- Unit tests with 80%+ coverage for panel data selection and formatting helpers **(REQUIRED)**.
- Integration tests or snapshot-style tests for MVP panel states **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] Active Work Home View chooses running/retrying/attention/next-work rows from the projection.
  - [ ] Readiness panel formats multiple requirement/remediation pairs without dropping remediation text.
  - [ ] Ordered Queue panel distinguishes pending, running, retrying, completed, and skipped entries.
  - [ ] Compozy panel formats current step plus completed/failed/skipped/total counts.
  - [ ] Task detail panel includes Goal Usage and context status when present and omits absent optional fields cleanly.
  - [ ] No-color formatting keeps text labels or symbols that distinguish running, retrying, attention, readiness, and idle states.
- Integration tests:
  - [ ] Rendering from representative Runtime State fixtures succeeds for idle, readiness-blocked, running, retrying, and Compozy scenarios.
  - [ ] Minimum-size terminal scenario produces a resize/help message instead of crashing.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- The default view can show active state without navigation.
- Readiness, attention, queue, Compozy, and task details are available from projected state.
- Rendering does not require Runtime State schema changes or Web Dashboard parity.
