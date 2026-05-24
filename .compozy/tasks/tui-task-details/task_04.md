---
status: completed
title: Preserve Queue Compatibility and Update Console Guidance
type: backend
complexity: medium
dependencies:
  - task_03

---

# Task 04: Preserve Queue Compatibility and Update Console Guidance

## Overview
Finalize the Terminal Console user-facing behavior by keeping Space-based Queue expansion compatible while updating footer and help copy for the new Enter inspect command. This task also performs the accepted verification gate for the full TUI task details change.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- MUST preserve Space as the Queue stage expansion command.
- MUST keep Queue expansion independent from Enter-based inspect state.
- MUST update contextual footer text so inspectable tabs advertise Enter inspect behavior.
- MUST update Queue guidance to distinguish Enter inspect from Space expand.
- MUST omit inspect guidance from Logs.
- MUST run focused Terminal Console Alcotest coverage and `pnpm backend:build` before completion.
</requirements>

## Subtasks
- [ ] 4.1 Confirm Space still toggles Queue expansion for the selected Queue row.
- [ ] 4.2 Keep Queue expansion and inline inspect state independent in rendering and key transitions.
- [ ] 4.3 Update contextual footer text for Queue, Tasks, Readiness, Needs attention, and Logs.
- [ ] 4.4 Update full help copy for inspect and Queue expansion behavior.
- [ ] 4.5 Add or adjust tests for Queue compatibility and guidance copy.
- [ ] 4.6 Run the focused Terminal Console Alcotest command and `pnpm backend:build`.

## Implementation Details
Build on Task 03 after inspect mode exists. Reference the TechSpec "Testing Approach", "Technical Considerations", and ADR-006 for the required verification gate.

### Relevant Files
- `apps/backend/bin/terminal_console_tui.re` — Owns `help_commands`, contextual footer rendering, Space key handling, Queue expansion rendering, and Enter inspect state.
- `apps/backend/test/test_backend.ml` — Contains Queue Space expansion tests, navigation tests, and TUI render assertions that should cover guidance copy.
- `package.json` — Defines `backend:build` and project test commands.

### Dependent Files
- `apps/backend/bin/terminal_console_preview.ml` — Provides manual preview coverage for guidance and Queue detail layout.
- `apps/backend/bin/dune` — Compiles the Terminal Console shell and preview.
- `.compozy/tasks/tui-task-details/_techspec.md` — Defines focused Alcotest plus backend build as the accepted verification gate.

### Related ADRs
- [ADR-005: Use Enter for Inspect and Keep Space Queue-Compatible](adrs/adr-005.md) — Requires preserving Space for Queue expansion while using Enter for inspect mode.
- [ADR-006: Verify with Focused Alcotest and Backend Build](adrs/adr-006.md) — Defines the verification commands required before completion.

## Deliverables
- Queue Space expansion preserved and covered by tests.
- Help and footer text updated to reflect Enter inspect and Queue Space expansion accurately.
- Tests covering Queue compatibility, inspect guidance, and Logs guidance exclusion.
- Focused Terminal Console Alcotest evidence.
- Successful `pnpm backend:build` evidence.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for Terminal Console guidance and Queue compatibility **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Space on Queue still toggles `expanded_queue_id` for the selected queue stage.
  - [ ] Enter inspect on Queue does not clear or hijack Space-based Queue expansion.
  - [ ] Contextual footer for Queue mentions both Enter inspect and Space expand.
  - [ ] Contextual footer for Tasks, Readiness, and Needs attention mentions Enter inspect.
  - [ ] Contextual footer for Logs does not advertise inspect mode.
  - [ ] Full help copy describes inspect behavior without suggesting lifecycle mutations.
- Integration tests:
  - [ ] Focused Terminal Console Alcotest cases pass for projection, dynamic tabs, inspect toggling, inline details, Queue compatibility, Logs exclusion, and read-only behavior.
  - [ ] `pnpm backend:build` completes successfully after the TUI and projection type changes.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Space Queue expansion behavior remains backward compatible.
- Help and footer copy accurately describe inspect behavior for each active tab family.
- Focused Alcotest coverage and backend build both pass before the feature is marked complete.
