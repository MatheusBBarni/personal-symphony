---
status: pending
title: "Add JSX Wrappers For Existing Components"
type: backend
complexity: high
dependencies:
  - task_01
---

# Task 02: Add JSX Wrappers For Existing Components

## Overview
This task expands the JSX namespace across the existing `Tui.Components` surface. It makes the adoption-ready public kit useful for normal standalone TUI screens while keeping direct components as the semantic source of truth.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- REQ-01 MUST add JSX wrappers for most existing `Components` primitives and widgets, excluding presets.
- REQ-02 MUST preserve the direct component-call behavior for each wrapped component.
- REQ-03 MUST keep wrapper props aligned with existing component labels unless a JSX-friendly name is clearly required and documented later.
- REQ-04 MUST keep text explicit and MUST NOT add implicit string-child conversion.
- REQ-05 MUST add parity tests for representative layout, input/select, status, and data-display wrappers.
</requirements>

## Subtasks
- [ ] 2.1 Review the component list in `Components_core` and identify the V1 wrapper set.
- [ ] 2.2 Add wrappers for primitive nodes and layout components.
- [ ] 2.3 Add wrappers for interactive and data-display components.
- [ ] 2.4 Add wrappers for status, empty state, divider, toolbar, and meter components.
- [ ] 2.5 Add representative parity tests for the supported component groups.
- [ ] 2.6 Run TUI package tests and build after component wrapper coverage is added.

## Implementation Details
Use the namespace and conventions from task 01. The component wrappers should delegate to `Components.text`, `rich_text`, `vertical_rule`, `box`, `input`, `option`, `select`, `scroll_box`, `progress_bar`, `sparkline`, `spacer`, `row`, `column`, `panel`, `badge`, `tab_bar`, `key_value`, `table`, `split`, `divider`, `callout`, `empty_state`, `toolbar`, and `meter` where applicable. Reference the TechSpec "Impact Analysis" and "Testing Approach" sections for coverage expectations.

### Relevant Files
- `apps/tui/lib/components/components_core.re` — canonical list of component exports.
- `apps/tui/lib/components/component_layout.re` — row and column behavior.
- `apps/tui/lib/components/component_panel.re` — panel behavior and style merging.
- `apps/tui/lib/components/component_table.re` — table width and fit behavior.
- `apps/tui/lib/components/component_key_value.re` — key/value display behavior.
- `apps/tui/test/test_tui.re` — existing tests for components and rendering.

### Dependent Files
- `apps/tui/lib/tui.re` — public export should continue to expose the JSX namespace.
- `apps/tui/examples/agent_workspace.ml` — later parity example depends on component wrappers.
- `apps/tui/README.md` — later docs depend on the supported component set.

### Related ADRs
- [ADR-002: Adopt Public JSX Kit Scope](adrs/adr-002.md) — Requires enough public surface for adoption.
- [ADR-004: Implement JSX As Wrapper Modules Over Existing TUI Components](adrs/adr-004.md) — Requires thin wrappers and parity with existing components.

## Deliverables
- JSX wrappers for the supported `Components` surface.
- Representative component parity tests in the TUI test suite.
- No behavior change to direct component calls.
- Unit tests with 80%+ coverage for component wrapper groups **(REQUIRED)**.
- Integration tests for rendering component wrappers together **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] Wrapper row/column/panel composition renders equivalent layout text to direct components.
  - [ ] Wrapper input/select construction preserves placeholder, options, and focusable behavior.
  - [ ] Wrapper table and key/value components render aligned data from representative rows.
  - [ ] Wrapper badge, divider, callout, empty state, toolbar, and meter render visible labels equivalent to direct components.
- Integration tests:
  - [ ] A mixed wrapper tree using layout, data, and status components renders through `Renderer.render_to_string`.
  - [ ] `pnpm --filter @symphony-orchestrator/tui test` passes after wrapper expansion.
  - [ ] `pnpm --filter @symphony-orchestrator/tui build` passes after wrapper expansion.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing.
- Test coverage >=80%.
- Most existing `Components` are available through `Tui.Jsx`.
- Wrapper outputs are behaviorally equivalent to direct component calls.
- No JSX wrapper introduces implicit text conversion or separate runtime state.
