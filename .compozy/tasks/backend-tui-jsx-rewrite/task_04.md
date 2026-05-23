---
status: completed
title: Convert Modal Header Active Panel And Root Layout To Literal JSX
type: backend
complexity: high
dependencies:
  - task_03

---

# Task 4: Convert Modal Header Active Panel And Root Layout To Literal JSX

## Overview
Rewrite the remaining high-level Terminal Console view tree to literal `Tui.Jsx` tags. This covers modals, header composition, tab strip layout, active panel rendering, scroll boxes, footer placement, and root layout while keeping the rendered operator experience unchanged.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details - do not duplicate here
- FOCUS ON "WHAT" - describe what needs to be accomplished, not how
- MINIMIZE CODE - show code only to illustrate current structure or problem areas
- TESTS REQUIRED - every task MUST include tests in deliverables
</critical>

<requirements>
1. MUST convert help modal, settings modal, header, tab row, active panel, scroll-box composition, footer placement, and root layout to literal `Tui.Jsx` tags.
2. MUST preserve modal IDs, modal tones, dimensions, root sizing, root padding, gaps, theme selection, and active-tab panel tone.
3. MUST preserve the rule that settings and help modals are layered as root children and are not appended to active panel lines.
4. MUST preserve log-tab scroll-box content selection versus normal content-line selection.
5. MUST keep interaction, keyboard transition, safe-aid dispatch, settings validation, and runtime update logic behavior-equivalent.
6. MUST not redesign Terminal Console layout, shortcut semantics, modal text, or tab order.
</requirements>

## Subtasks
- [x] 4.1 Convert help modal and settings modal node construction to literal JSX with identical IDs, titles, tones, dimensions, and content.
- [x] 4.2 Convert header title, subtitle, badge row, and container layout to literal JSX with identical theme and style behavior.
- [x] 4.3 Convert tab strip and active panel composition to literal JSX while preserving active tab selection and panel title fallback behavior.
- [x] 4.4 Convert scroll-box and root layout composition to literal JSX while preserving sizing, padding, gap, and theme behavior.
- [x] 4.5 Preserve modal layering behavior for settings and help states.
- [x] 4.6 Add focused parity coverage for converted high-level layout behavior only where existing tests are insufficient.

## Implementation Details
Reference the TechSpec "Development Sequencing" steps for modal, header, root layout, active panel, and scroll-box conversion. Keep `render_model`, panel shaping, `apply_key`, `update`, runtime handoff, and safe-aid dispatch behavior unchanged except where source syntax must adapt.

### Relevant Files
- `apps/backend/bin/terminal_console_tui.re` - high-level view tree and runtime shell module.
- `apps/backend/test/test_backend.ml` - tests for root theme, active panels, modal behavior, settings flows, keyboard interactions, and safe aids.
- `apps/tui/lib/jsx.re` - existing JSX wrappers for `Box`, `Row`, `Column`, `Panel`, `ScrollBox`, `Modal`, `Badge`, and rich text primitives.
- `apps/tui/examples/agent_workspace_jsx.re` - literal JSX style reference for nested layout composition.

### Dependent Files
- `apps/backend/bin/terminal_console_preview.ml` - preview output should remain stable after root view conversion.
- `apps/backend/bin/main.ml` - settings and handoff caller compatibility must remain intact.
- `apps/backend/bin/terminal_console_runtime.ml` - runtime handoff and `run` caller compatibility must remain intact.
- `.compozy/tasks/backend-tui-jsx-rewrite/evidence/terminal-console-baseline.md` - comparison source for root and modal parity.

### Related ADRs
- [ADR-002: Select Complete Backend Terminal Console JSX Rewrite](adrs/adr-002.md) - Requires complete backend Terminal Console coverage.
- [ADR-003: Select Complete Coverage With Strict Parity PRD Approach](adrs/adr-003.md) - Requires strict operator-facing parity.
- [ADR-004: Implement Terminal Console View Rewrite As Reason JSX With Preserved Module Contract](adrs/adr-004.md) - Defines literal Reason JSX and preserved contract requirements.

## Deliverables
- High-level Terminal Console view tree rewritten to literal JSX.
- Settings and help modal behavior preserved as separate root-layer UI states.
- Active panel, tab strip, scroll box, header, and footer layout parity preserved.
- Unit tests with 80%+ coverage for touched behavior **(REQUIRED)**.
- Integration tests for preview output after high-level view conversion **(REQUIRED)**.

## Tests
- Unit tests:
  - [x] Run Terminal Console tests for active home panel, readiness, attention, ordered queue, logs, task detail, root theme, footer help, settings modal, help modal, navigation, filtering, and safe aids.
  - [x] Add focused assertions if root-child modal layering, active-tab panel selection, or scroll-box content selection is not already covered.
  - [x] Run `pnpm test` after backend view tree changes.
- Integration tests:
  - [x] Run `pnpm backend:build` to confirm the literal JSX root view compiles.
  - [x] Run `terminal_console_preview` and compare the rendered output against the task 1 baseline.
  - [x] Confirm the preview output still shows the same tabs, footer commands, headings, readiness content, attention content, queue content, and logs content.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Modal, header, tab strip, active panel, scroll-box, footer, and root layout construction use literal JSX.
- Help and settings modal flows remain separate from active panel content.
- Preview output remains behavior-equivalent to the task 1 baseline.
- No Runtime State, Runtime Settings, lifecycle, Web Dashboard handoff, or safe-aid semantics are changed.
