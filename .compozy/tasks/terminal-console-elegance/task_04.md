---
status: pending
title: Replace Panel-Centric Interaction With Semantic Mode Navigation
type: backend
complexity: medium
dependencies:
  - task_02
  - task_03
---

# Task 04: Replace Panel-Centric Interaction With Semantic Mode Navigation

## Overview
Replace the current panel-centric interaction model with semantic top-level mode navigation and mode-aware selection behavior. This task makes `Tab` change meaning instead of only shifting focus, while preserving the existing UI-only filtering, help, and safe-aid boundaries that keep the **Terminal Console** read-first.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- MUST replace panel-centric focus state with top-level mode selection plus per-mode row or detail selection state.
- MUST make `Tab` and equivalent navigation keys switch semantic modes rather than only cycling fixed panels.
- MUST keep filtering, help, footer hints, refresh, Web Dashboard handoff, and validated local path inspection as UI-only or non-mutating behaviors.
- MUST make footer and help content mode-aware so shortcuts match the operator’s current context.
- MUST preserve the existing safe-aid contract and MUST NOT introduce any task lifecycle mutation.
- SHOULD minimize churn outside `terminal_console_mosaic.ml` unless a helper in `terminal_console_model.ml` is genuinely needed for mode-specific row visibility.
</requirements>

## Subtasks
- [ ] 4.1 Replace panel-focused interaction state with semantic mode and per-mode selection state.
- [ ] 4.2 Update tab-switching and directional navigation to follow top-level mode semantics.
- [ ] 4.3 Make filtering and search operate correctly within the selected mode without mutating projected state.
- [ ] 4.4 Update footer and help content so it reflects the selected mode and available safe aids.
- [ ] 4.5 Extend reducer and runtime tests to prove mode navigation stays UI-local and non-mutating.

## Implementation Details
Modify `apps/backend/bin/terminal_console_mosaic.ml` in line with the TechSpec "UI State", "Render Tests", and "Key Decisions" sections. The current `apply_key` and reducer loop are already isolated; the work here is to reshape those reducers around semantic modes instead of fixed panel order.

If mode-specific row visibility requires small helper changes in `apps/backend/lib/terminal_console_model.ml`, keep them narrow and projection-oriented. Do not move reducer state into the projection.

### Relevant Files
- `apps/backend/bin/terminal_console_mosaic.ml` — Current reducer, key handling, footer/help behavior, and safe-aid invocation path.
- `apps/backend/lib/terminal_console_model.ml` — Source of mode-specific content that selection and filtering may need to traverse.
- `apps/backend/test/test_backend.ml` — Existing navigation, filtering, safe-aid, footer/help, and runtime safe-aid tests.
- `apps/backend/bin/terminal_console_runtime.ml` — Useful for validating that interaction changes do not alter runtime handoff or safe-aid authority.

### Dependent Files
- `apps/backend/test/test_backend.ml` — Interaction assertions will move from focused-panel behavior to selected-mode behavior.
- `apps/backend/bin/terminal_console_mosaic.ml` — Final user-facing behavior of tabs, footer hints, and per-mode selection depends on this task.
- `README.md` — Later docs work may need updated wording for key navigation semantics and safe-aid discoverability.

### Related ADRs
- [ADR-001: Scope the Terminal Console elegance redesign as a two-mode presentation refactor](../adrs/adr-001.md) — Requires real top-level mode behavior rather than cosmetic panel focus changes.
- [ADR-002: Prioritize active-run elegance as the MVP product approach](../adrs/adr-002.md) — Keeps interaction optimized for the heavy daily operator’s live-monitoring workflow.
- [ADR-004: Redesign the Terminal Console around explicit mode models over the existing in-process seam](../adrs/adr-004.md) — Interaction must align with explicit mode bodies.
- [ADR-006: Preserve 80x24 support with compact single-column mode rendering](../adrs/adr-006.md) — Mode navigation must stay coherent in compact layouts.

## Deliverables
- Semantic mode-selection state in the Terminal Console reducer.
- Mode-aware navigation, footer hints, help content, filtering, and selection behavior.
- Preserved non-mutating safe-aid behavior under the new interaction model.
- Unit tests with 80%+ coverage for reducer and interaction behavior **(REQUIRED)**.
- Integration tests proving runtime safe-aid invocations remain non-mutating after the navigation redesign **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] `Tab` or equivalent keys switch the selected top-level mode rather than only cycling fixed panels.
  - [ ] Per-mode row or detail selection remains stable and UI-local when navigating within active-run and readiness modes.
  - [ ] Filtering updates only UI state and leaves the projected snapshot unchanged.
  - [ ] Footer and help content change with the selected mode and available safe aids.
  - [ ] Refresh, Web Dashboard handoff, and local path inspection continue to produce only non-mutating safe-aid effects.
- Integration tests:
  - [ ] Existing runtime safe-aid handler tests still record only non-mutating actions under the redesigned interaction model.
  - [ ] Representative active-run and readiness-mode interaction flows complete without requiring runtime or orchestration changes.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Top-level mode navigation is semantic and no longer panel-centric.
- Filtering, help, and safe aids remain UI-local or non-mutating.
- No task lifecycle mutation paths are introduced by the new interaction model.
