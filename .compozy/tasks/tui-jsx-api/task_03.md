---
status: pending
title: "Add JSX Wrappers For Existing Patterns"
type: backend
complexity: high
dependencies:
  - task_01
  - task_02
---

# Task 03: Add JSX Wrappers For Existing Patterns

## Overview
This task extends the JSX authoring surface to the higher-level `Tui.Patterns` helpers used by realistic terminal applications. It gives external users a JSX path for command-center and workflow UIs without duplicating pattern semantics.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- REQ-01 MUST add JSX wrappers for most existing `Patterns` helpers used by standalone terminal tools.
- REQ-02 MUST exclude edge-case presets from V1 wrapper scope unless needed by the parity example.
- REQ-03 MUST preserve `Patterns` behavior and delegate to existing helpers.
- REQ-04 MUST support the pattern wrappers needed by the `agent_workspace` parity example.
- REQ-05 MUST add tests for representative shell, message, timeline, composer, and command/footer pattern wrappers.
</requirements>

## Subtasks
- [ ] 3.1 Review `patterns.re` and define the V1 pattern wrapper set.
- [ ] 3.2 Add wrappers for app shell, header, modal, and rule-panel style patterns.
- [ ] 3.3 Add wrappers for message, timeline, composer, command bar, footer, and navigation patterns.
- [ ] 3.4 Add wrappers for dashboard-style patterns such as metric cards and log feed.
- [ ] 3.5 Add parity tests for representative pattern groups.
- [ ] 3.6 Run the TUI package test/build commands after pattern wrapper coverage is added.

## Implementation Details
Use the wrapper namespace from task 01 and the component wrappers from task 02. The pattern wrappers should delegate to `Patterns.rule_panel`, `modal`, `header`, `metric_card`, `log_feed`, `section_title`, `nav_item`, `message`, `timeline`, `composer`, `command_bar`, `footer`, and `app_shell` where applicable. Reference the TechSpec "Key Decisions" section for the preset exclusion and `agent_workspace` priority.

### Relevant Files
- `apps/tui/lib/patterns.re` — canonical pattern helper implementations.
- `apps/tui/examples/agent_workspace.ml` — uses app shell, split, panel, scroll box, composer, message, timeline, nav item, and section title patterns.
- `apps/tui/examples/operations_dashboard.ml` — useful dashboard/status reference for metric and log-feed wrappers.
- `apps/tui/test/test_tui.re` — existing tests for modal, app shell, and pattern helpers.

### Dependent Files
- `apps/tui/lib/components/*` — pattern wrappers depend on component wrappers and direct component behavior.
- `apps/tui/examples/agent_workspace.ml` — later JSX parity example depends on these wrappers.
- `apps/tui/examples/README.md` — later docs need the supported pattern set.

### Related ADRs
- [ADR-003: Select Adoption-Ready Public JSX Kit Approach](adrs/adr-003.md) — Requires examples and documentation around the recommended JSX path.
- [ADR-004: Implement JSX As Wrapper Modules Over Existing TUI Components](adrs/adr-004.md) — Requires pattern wrappers to stay thin and return `Tui.Node.t`.

## Deliverables
- JSX wrappers for most existing `Patterns` helpers, excluding edge-case presets.
- Pattern wrapper tests for realistic terminal UI structures.
- Coverage for all patterns required by the `agent_workspace` parity target.
- Unit tests with 80%+ coverage for pattern wrapper groups **(REQUIRED)**.
- Integration tests for composed pattern-wrapper screens **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] App shell wrapper renders title, subtitle, badges, body, and footer items equivalent to direct pattern usage.
  - [ ] Message and timeline wrappers render representative entries equivalent to direct pattern usage.
  - [ ] Composer, command bar, footer, section title, and nav item wrappers render expected labels and metadata.
  - [ ] Metric card and log feed wrappers render representative dashboard content.
- Integration tests:
  - [ ] A composed wrapper screen using app shell, navigation, messages, timeline, and composer renders through `Renderer.render_to_string`.
  - [ ] `pnpm --filter @symphony-orchestrator/tui test` passes after pattern wrapper expansion.
  - [ ] `pnpm --filter @symphony-orchestrator/tui build` passes after pattern wrapper expansion.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing.
- Test coverage >=80%.
- Most existing `Patterns` used by standalone terminal tools are available through `Tui.Jsx`.
- Pattern wrappers preserve existing direct pattern behavior.
- `agent_workspace` has all JSX wrapper support needed for parity work.
