---
status: pending
title: "Implement Settings Modal and Theme Application"
type: backend
complexity: high
dependencies:
  - task_01
  - task_04
---

# Task 05: Implement Settings Modal and Theme Application

## Overview
This task adds the focused Terminal Console settings UI opened by `s`. It lets the user review, edit, save, or cancel the Terminal Console theme and Web Dashboard port while keeping the UI product-specific to the backend Terminal Console shell.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- REQ-01 MUST open a focused settings modal from the Terminal Console with `s`.
- REQ-02 MUST show `s` in relevant footer and help affordances.
- REQ-03 MUST expose only Terminal Console theme and Web Dashboard port in V1.
- REQ-04 MUST support `cursor-dark`, `dark`, `light`, `high-contrast`, and `no-color` themes.
- REQ-05 MUST let users save valid settings and cancel draft changes.
- REQ-06 MUST reject invalid port input before any persistence side effect.
- REQ-07 MUST apply the selected Terminal Console theme to the rendered TUI surface.
- REQ-08 MUST NOT add a reusable settings framework to `apps/tui`.
- REQ-09 MUST keep settings UI rendering mutually clear with the existing help modal and active panels.
</requirements>

## Subtasks
- [ ] 5.1 Review current Terminal Console model, key handling, help modal, footer, and theme code.
- [ ] 5.2 Add settings modal state and draft values to the Terminal Console interaction model.
- [ ] 5.3 Add key handling for opening, editing, saving, and cancelling settings.
- [ ] 5.4 Render settings status and validation feedback without overlapping existing panels or help.
- [ ] 5.5 Apply selected theme values to Terminal Console rendering.
- [ ] 5.6 Add focused tests for modal state, footer/help, theme selection, port validation, and cancel behavior.

## Implementation Details
Use the TechSpec "Component Overview" and "Testing Approach" sections. Keep changes centered in `apps/backend/bin/terminal_console_tui.ml` and use existing TUI component/theme patterns instead of adding toolkit-level settings primitives.

### Relevant Files
- `apps/backend/bin/terminal_console_tui.ml` — Terminal Console interaction model, key handling, footer/help text, modal rendering, and theme palette.
- `apps/backend/lib/terminal_console_settings.re` — Supported theme and port validation behavior from task 01.
- `apps/tui/lib/theme.re` — Existing reusable TUI theme primitives to reference without adding settings framework behavior.
- `apps/tui/lib/components/components.re` — Existing modal/component patterns to reuse without adding a settings framework.
- `apps/backend/test/test_backend.ml` — Existing Terminal Console TUI tests for navigation, filtering, help/footer, no-color labels, and Cursor theme.

### Dependent Files
- `apps/backend/bin/terminal_console_runtime.ml` — Supplies settings callbacks from task 04.
- `apps/backend/bin/terminal_console_preview.ml` — May need default settings values for previews.
- `README.md` — Later task documents the new `s` settings affordance.

### Related ADRs
- [ADR-001: Scope the Terminal Console Settings MVP](adrs/adr-001.md) — Limits V1 to theme and `server.port`.
- [ADR-002: Select Narrow Setup MVP Product Approach](adrs/adr-002.md) — Selects dedicated `s` shortcut and persistent setup controls.
- [ADR-003: Terminal Console Settings and Dashboard Service Architecture](adrs/adr-003.md) — Keeps settings UI product-specific.

## Deliverables
- `s` settings modal with theme and port draft state.
- Footer and help updates for settings discoverability.
- Theme application for all supported V1 themes.
- Unit tests with 80%+ coverage for modal state and validation behavior **(REQUIRED)**.
- Integration tests for save/cancel behavior through runtime callbacks **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] Pressing `s` opens the settings modal.
  - [ ] Footer includes `[s]settings` in relevant Terminal Console states.
  - [ ] Help modal includes the settings command.
  - [ ] `Escape` or cancel closes the modal without saving draft values.
  - [ ] Settings modal does not render inside the active panel or merge with the help modal.
  - [ ] Theme selection cycles or selects `cursor-dark`, `dark`, `light`, `high-contrast`, and `no-color`.
  - [ ] Invalid port input shows a validation message and does not call save.
  - [ ] Selected theme affects rendered spans or design theme output.
- Integration tests:
  - [ ] Saving valid settings calls the runtime save callback with the selected theme and port.
  - [ ] Cancelled settings changes leave persisted values unchanged.
  - [ ] Existing navigation, filtering, and help behavior still works when the settings modal is closed.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Users can persist Terminal Console theme and Web Dashboard port from the Terminal Console.
- Invalid settings are rejected before side effects.
- No reusable `apps/tui` settings framework is introduced.
- Existing navigation, filtering, help/footer, and no-color regression tests remain green.
