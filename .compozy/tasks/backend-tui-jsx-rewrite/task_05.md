---
status: pending
title: Close TUI JSX Wrapper Gaps And Parity Coverage
type: refactor
complexity: medium
dependencies:
  - task_04
---

# Task 5: Close TUI JSX Wrapper Gaps And Parity Coverage

## Overview
Finish the JSX coverage audit after the backend view tree has been converted. Any remaining direct backend view construction must be replaced with existing JSX wrappers or with narrowly reusable `apps/tui` wrappers that delegate to existing primitives.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details - do not duplicate here
- FOCUS ON "WHAT" - describe what needs to be accomplished, not how
- MINIMIZE CODE - show code only to illustrate current structure or problem areas
- TESTS REQUIRED - every task MUST include tests in deliverables
</critical>

<requirements>
1. MUST audit `Terminal_console_tui` for remaining direct `Tui.Components` or `Tui.Patterns` calls that produce Terminal Console UI nodes.
2. MUST convert remaining backend UI node construction to literal `Tui.Jsx` tags or JSX wrapper calls.
3. MUST allow direct lower-level usage only for non-node helper data such as spans, styles, tones, colors, or existing primitive constants where JSX is not the view-authoring surface.
4. MUST add `apps/tui/lib/jsx.re` wrappers only when exact backend parity is blocked and the wrapper maps to an existing reusable TUI primitive.
5. MUST add `apps/tui/test/test_tui.re` wrapper parity coverage if any reusable JSX wrapper is added or changed.
6. MUST not add backend-specific behavior to the reusable TUI Toolkit Package.
</requirements>

## Subtasks
- [ ] 5.1 Audit backend Terminal Console view construction for remaining direct component or pattern node calls.
- [ ] 5.2 Replace any remaining direct backend UI node construction with existing JSX wrappers where possible.
- [ ] 5.3 Add narrow reusable JSX wrappers only for existing package primitives that are required for exact Terminal Console parity.
- [ ] 5.4 Add TUI wrapper parity tests if `apps/tui/lib/jsx.re` changes.
- [ ] 5.5 Record a JSX coverage note identifying allowed lower-level direct usages that are not view construction.
- [ ] 5.6 Re-run backend and TUI checks required by the files touched.

## Implementation Details
Use the TechSpec "Technical Considerations" wrapper policy. This task is the package-boundary gate: product-specific behavior remains in `apps/backend`, while `apps/tui` only receives general-purpose JSX wrappers over existing primitives.

### Relevant Files
- `apps/backend/bin/terminal_console_tui.re` - backend JSX coverage audit target.
- `apps/tui/lib/jsx.re` - reusable JSX wrapper surface if a wrapper gap blocks exact parity.
- `apps/tui/test/test_tui.re` - required parity coverage for any new or changed wrapper.
- `apps/tui/examples/agent_workspace_jsx.re` - style reference for wrapper usage in Reason JSX.
- `apps/backend/test/test_backend.ml` - backend parity coverage for final view behavior.

### Dependent Files
- `apps/tui/lib/tui.re` - package namespace export for `Tui.Jsx` must remain compatible if wrappers change.
- `apps/tui/README.md` - docs may need later wording updates if wrapper capabilities change.
- `apps/backend/bin/terminal_console_preview.ml` - preview output remains the backend parity artifact.
- `.compozy/tasks/backend-tui-jsx-rewrite/evidence/terminal-console-baseline.md` - comparison source for final JSX coverage.

### Related ADRs
- [ADR-002: Select Complete Backend Terminal Console JSX Rewrite](adrs/adr-002.md) - Requires full backend Terminal Console JSX coverage.
- [ADR-003: Select Complete Coverage With Strict Parity PRD Approach](adrs/adr-003.md) - Prevents calling partial coverage complete.
- [ADR-004: Implement Terminal Console View Rewrite As Reason JSX With Preserved Module Contract](adrs/adr-004.md) - Defines the narrow wrapper policy and package boundary.

## Deliverables
- JSX coverage audit for backend Terminal Console UI construction.
- Remaining backend UI node construction converted to JSX.
- Narrow reusable TUI JSX wrappers and wrapper tests, only if required for exact parity.
- Unit tests with 80%+ coverage for touched behavior **(REQUIRED)**.
- Integration tests for backend and TUI wrapper parity when applicable **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] Run `pnpm test` after backend view-authoring changes.
  - [ ] Run `pnpm --filter @symphony-orchestrator/tui test` if `apps/tui/lib/jsx.re` or TUI wrapper tests change.
  - [ ] Confirm wrapper tests compare JSX wrapper output to direct component or pattern output for each new wrapper.
- Integration tests:
  - [ ] Run `pnpm backend:build` after backend compile-surface changes.
  - [ ] Run `pnpm --filter @symphony-orchestrator/tui build` if `apps/tui` compile surface changes.
  - [ ] Run `terminal_console_preview` and compare output against the task 1 baseline.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Backend Terminal Console UI node construction has complete JSX coverage.
- Any remaining direct `Components` or `Patterns` usage is documented as lower-level non-view helper usage or an accepted primitive dependency.
- Any `apps/tui` change is reusable, covered by wrapper parity tests, and free of backend-specific Terminal Console behavior.
- No operator-visible behavior, Runtime State, Runtime Settings, lifecycle, or safe-aid semantics are changed.
