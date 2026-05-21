---
status: completed
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
- REQ-01 MUST expand `Tui.Jsx` to the approved V1 component wrapper set: `RichText`, `VerticalRule`, `Spacer`, `Input`, `Option`, `Select`, `ScrollBox`, `ProgressBar`, `Sparkline`, `Row`, `Column`, `Panel`, `Badge`, `TabBar`, `KeyValue`, `Table`, `Split`, `Divider`, `Callout`, `EmptyState`, `Toolbar`, and `Meter`, while preserving the task 01 `Text` and `Box` conventions.
- REQ-02 MUST preserve the direct component-call behavior for each wrapped component.
- REQ-03 MUST keep wrapper props aligned with existing component labels unless a JSX-friendly name is clearly required and documented later.
- REQ-04 MUST keep text explicit and MUST NOT add implicit string-child conversion.
- REQ-05 MUST leave `Components.repeat` and `Components.fit` as direct-call table helpers in V1 and MUST NOT expose them as JSX modules.
- REQ-06 MUST add parity tests for representative primitive, layout, input/select, status, and data-display wrappers.
</requirements>

## Subtasks
- [ ] 2.1 Confirm `Components_core` still matches the approved V1 wrapper inventory before editing and note any unexpected export drift.
- [ ] 2.2 Add wrappers for primitive nodes and layout components in the approved V1 inventory.
- [ ] 2.3 Add wrappers for interactive and data-display components in the approved V1 inventory.
- [ ] 2.4 Add wrappers for status and supporting widgets in the approved V1 inventory, leaving `repeat` and `fit` direct-call only.
- [ ] 2.5 Add representative parity tests for each supported component group plus a namespace smoke case covering wrapper availability.
- [ ] 2.6 Run TUI package tests and build after component wrapper coverage is added.

## Implementation Details
Use the namespace and conventions from task 01. The approved V1 component wrapper inventory for this task is `Text`, `Box`, `RichText`, `VerticalRule`, `Spacer`, `Input`, `Option`, `Select`, `ScrollBox`, `ProgressBar`, `Sparkline`, `Row`, `Column`, `Panel`, `Badge`, `TabBar`, `KeyValue`, `Table`, `Split`, `Divider`, `Callout`, `EmptyState`, `Toolbar`, and `Meter`. `Text` and `Box` are already established by task 01 and remain the convention anchors for the rest of the wrapper set. `Option` belongs in scope as the JSX-side helper constructor for `Select` options even though it does not return `Tui.Node.t`. `repeat` and `fit` stay direct `Components` utilities because they are table-formatting helpers rather than JSX authoring constructors. Reference the TechSpec "Impact Analysis" and "Testing Approach" sections for parity expectations.

### Relevant Files
- `apps/tui/lib/components/components_core.re` — canonical list of component exports.
- `apps/tui/lib/node.re` — source of primitive node and select-option constructor shapes used by wrappers.
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
- JSX wrappers for the approved V1 `Components` surface under `Tui.Jsx`.
- `repeat` and `fit` intentionally left as direct-call helpers rather than JSX modules.
- Representative component parity tests in the TUI test suite plus a namespace smoke case for wrapper availability.
- No behavior change to direct component calls.
- Focused unit tests for each component wrapper group **(REQUIRED)**.
- Integration tests for rendering component wrappers together **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] Wrapper row/column/panel composition renders equivalent layout text to direct components.
  - [ ] Wrapper `RichText`, `VerticalRule`, `Spacer`, `ProgressBar`, and `Sparkline` nodes render representative visible output equivalent to direct components.
  - [ ] Wrapper input/select/option construction preserves placeholder, options, and focusable behavior.
  - [ ] Wrapper table, key/value, and split components render aligned data from representative rows.
  - [ ] Wrapper badge, tab bar, divider, callout, empty state, toolbar, and meter components render visible labels equivalent to direct components.
  - [ ] A namespace smoke test proves the remaining approved wrapper constructors are callable from `Tui.Jsx`.
- Integration tests:
  - [ ] A mixed wrapper tree using layout, data, status, and utility wrappers renders through `Renderer.render_to_string`.
  - [ ] `pnpm --filter @symphony-orchestrator/tui test` passes after wrapper expansion.
  - [ ] `pnpm --filter @symphony-orchestrator/tui build` passes after wrapper expansion.
- All tests must pass

## Success Criteria
- All tests passing.
- The approved V1 component wrapper inventory is available through `Tui.Jsx`, with `repeat` and `fit` remaining direct-call utilities by design.
- Wrapper outputs are behaviorally equivalent to direct component calls.
- No JSX wrapper introduces implicit text conversion or separate runtime state.
