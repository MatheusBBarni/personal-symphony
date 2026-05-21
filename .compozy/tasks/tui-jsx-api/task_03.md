---
status: completed
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
- REQ-01 MUST expand `Tui.Jsx` to the approved V1 `Patterns` wrapper set: `RulePanel`, `Modal`, `Header`, `MetricCard`, `LogFeed`, `SectionTitle`, `NavItem`, `Message`, `Timeline`, `Composer`, `CommandBar`, `Footer`, and `AppShell`.
- REQ-02 MUST keep `Tui.Presets.Open_code.*` preset helpers and any other non-`Tui.Patterns` compatibility aliases out of JSX V1 scope unless a later parity task explicitly reopens that decision.
- REQ-03 MUST preserve the direct `Tui.Patterns` behavior for each wrapped helper by delegating to the existing pattern implementation rather than re-implementing pattern semantics.
- REQ-04 MUST keep wrapper props aligned with existing pattern labels unless a JSX-friendly name is clearly required and documented later.
- REQ-05 MUST cover every pattern wrapper required by the JSX `agent_workspace` parity target: `AppShell`, `SectionTitle`, `NavItem`, `Message`, `Timeline`, `Composer`, and any supporting shell/footer wrapper used by that example.
- REQ-06 MUST add representative parity tests for structural, workflow, and dashboard pattern groups, including the `Footer` convenience alias over `CommandBar`.
</requirements>

## Subtasks
- [ ] 3.1 Confirm `apps/tui/lib/patterns.re` still matches the approved V1 wrapper inventory before editing and note any unexpected export drift.
- [ ] 3.2 Add wrappers for structural shell patterns: `RulePanel`, `Modal`, `Header`, and `AppShell`.
- [ ] 3.3 Add wrappers for workflow and navigation patterns: `SectionTitle`, `NavItem`, `Message`, `Timeline`, `Composer`, `CommandBar`, and `Footer`.
- [ ] 3.4 Add wrappers for dashboard-supporting patterns: `MetricCard` and `LogFeed`.
- [ ] 3.5 Add parity tests for representative pattern groups.
- [ ] 3.6 Run the TUI package test/build commands after pattern wrapper coverage is added.

## Implementation Details
Use the wrapper namespace from task 01 and the component wrappers from task 02. The approved V1 pattern wrapper inventory for this task is `RulePanel`, `Modal`, `Header`, `MetricCard`, `LogFeed`, `SectionTitle`, `NavItem`, `Message`, `Timeline`, `Composer`, `CommandBar`, `Footer`, and `AppShell`. These wrappers should delegate to `Patterns.rule_panel`, `modal`, `header`, `metric_card`, `log_feed`, `section_title`, `nav_item`, `message`, `timeline`, `composer`, `command_bar`, `footer`, and `app_shell` respectively. `Footer` remains in scope even though it delegates to `command_bar`, because external users should be able to match the existing pattern API through `Tui.Jsx`. `Tui.Presets.Open_code.*` stays direct-call only in V1 because those helpers are presets rather than general JSX authoring patterns. Reference the TechSpec "Key Decisions" section for the preset exclusion and `agent_workspace` priority.

### Relevant Files
- `apps/tui/lib/jsx.re` — existing JSX namespace implementation that receives the new pattern wrappers.
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
- JSX wrappers for the approved V1 `Patterns` inventory under `Tui.Jsx`.
- `Tui.Presets.Open_code.*` intentionally left as direct-call preset helpers rather than JSX modules.
- Pattern wrapper tests for realistic terminal UI structures.
- Coverage for all patterns required by the `agent_workspace` parity target.
- Focused unit tests for each pattern wrapper group **(REQUIRED)**.
- Integration tests for composed pattern-wrapper screens **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] App shell, header, and footer/command-bar wrappers render title, subtitle, badges, body, and shortcut items equivalent to direct pattern usage.
  - [ ] Rule-panel and modal wrappers render representative shell structure equivalent to direct pattern usage.
  - [ ] Message and timeline wrappers render representative entries equivalent to direct pattern usage.
  - [ ] Composer, command bar, footer, section title, and nav item wrappers render expected labels and metadata.
  - [ ] Metric card and log feed wrappers render representative dashboard content.
- Integration tests:
  - [ ] A composed wrapper screen using app shell, navigation, messages, timeline, and composer renders through `Renderer.render_to_string`.
  - [ ] `pnpm --filter @symphony-orchestrator/tui test` passes after pattern wrapper expansion.
  - [ ] `pnpm --filter @symphony-orchestrator/tui build` passes after pattern wrapper expansion.
- All tests must pass

## Success Criteria
- All tests passing.
- The approved V1 pattern wrapper inventory is available through `Tui.Jsx`, with presets intentionally remaining direct-call only.
- Pattern wrappers preserve existing direct pattern behavior.
- `agent_workspace` has all JSX wrapper support needed for parity work.
