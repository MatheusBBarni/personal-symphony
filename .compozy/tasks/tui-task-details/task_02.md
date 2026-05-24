---
status: pending
title: Derive Dynamic Terminal Console Tabs
type: backend
complexity: medium
dependencies:
  - task_01
---

# Task 02: Derive Dynamic Terminal Console Tabs

## Overview
Update the Terminal Console TUI so visible tabs are derived from the projection instead of being a static list. Queue should disappear only when the projection says no Ordered Queue exists, and Tasks should become the starting surface in that case.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- MUST hide the Queue tab only when the Terminal Console projection marks Queue as absent.
- MUST preserve Queue tab visibility for present empty queues and present queues with no currently visible rows.
- MUST initialize the active tab to Tasks when Queue is absent.
- MUST keep Queue as the initial active tab when Queue is present.
- MUST clamp active tab state away from hidden Queue after snapshot changes.
- MUST preserve existing navigation behavior across the remaining visible tabs.
</requirements>

## Subtasks
- [ ] 2.1 Replace static visible tab use with projection-derived visible tabs.
- [ ] 2.2 Update initial interaction state so the default active tab reflects Queue presence.
- [ ] 2.3 Clamp active tab and selected row state when a refreshed snapshot hides Queue.
- [ ] 2.4 Preserve present-empty Queue panel behavior and empty-state messaging.
- [ ] 2.5 Update tab-rendering tests for absent Queue, present empty Queue, and tab navigation.
- [ ] 2.6 Verify Logs, Tasks, Readiness, and Needs attention remain reachable when Queue is hidden.

## Implementation Details
Build on Task 01's Queue-presence projection. Reference the TechSpec "Implementation Design" and "Development Sequencing" sections for the intended visible-tab ownership and clamping behavior.

### Relevant Files
- `apps/backend/bin/terminal_console_tui.re` — Owns `active_tab`, tab order, active-tab clamping, selected row state, and tab rendering.
- `apps/backend/lib/terminal_console_model.re` — Provides the Queue presence value introduced by Task 01.
- `apps/backend/test/test_backend.ml` — Contains existing TUI tests for initial model state, project title and tabs, active panels, and scroll-box content.

### Dependent Files
- `apps/backend/bin/terminal_console_preview.ml` — May surface visual changes in manual preview fixtures.
- `apps/backend/bin/dune` — Compiles the TUI shell library and preview entrypoints.
- `.compozy/tasks/tui-task-details/_techspec.md` — Defines Queue absence and present empty Queue behavior that this task must preserve.

### Related ADRs
- [ADR-003: Use Status-First Inspect Mode for the PRD](adrs/adr-003.md) — Requires Tasks as the default surface when Queue is absent.
- [ADR-004: Use Projection-Backed Inline Inspect State](adrs/adr-004.md) — Requires visible tabs to derive from projection-backed Queue presence.

## Deliverables
- Dynamic visible-tab derivation in the Terminal Console TUI.
- Initial active-tab behavior that starts on Tasks when Queue is absent.
- Active-tab clamping that prevents focus from staying on a hidden Queue tab.
- Focused TUI tests for absent Queue, present empty Queue, and tab navigation.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for Terminal Console tab rendering **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] A snapshot with Queue absent renders no Queue tab text.
  - [ ] A snapshot with Queue absent initializes active tab state to Tasks.
  - [ ] A snapshot with Queue present and zero entries still renders the Queue tab.
  - [ ] Active tab clamping moves Queue focus to Tasks when a refreshed snapshot hides Queue.
  - [ ] Left/right tab movement skips hidden Queue and preserves ordering for Logs, Tasks, Readiness, and Needs attention.
- Integration tests:
  - [ ] Active tab content uses the derived visible-tab set for render output and scroll-box content.
  - [ ] Existing present-Queue render fixtures retain Queue panel empty-state behavior.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Queue is hidden for absent Ordered Queue snapshots only.
- Tasks is the default surface when Queue is hidden.
- Present empty Queue snapshots remain visibly distinguishable from Queue absence.
