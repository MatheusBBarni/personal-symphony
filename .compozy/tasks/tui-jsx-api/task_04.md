---
status: pending
title: "Add JSX `agent_workspace` Parity Example"
type: backend
complexity: medium
dependencies:
  - task_02
  - task_03
---

# Task 04: Add JSX `agent_workspace` Parity Example

## Overview
This task proves the adoption-ready JSX surface against a realistic standalone terminal UI. The `agent_workspace` example becomes the first parity target because it exercises navigation, messages, composer input, app shell layout, and run-state panels.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- REQ-01 MUST add a runnable JSX-authored `agent_workspace` example or paired example variant.
- REQ-02 MUST preserve the existing direct-call `agent_workspace` example behavior.
- REQ-03 MUST compare rendered output between the direct-call and JSX parity target.
- REQ-04 MUST register any new example in the TUI examples Dune stanza and examples index when applicable.
- REQ-05 MUST keep the example focused on standalone terminal-tool users and avoid Symphony-specific runtime wiring.
</requirements>

## Subtasks
- [ ] 4.1 Review the existing `agent_workspace` example and identify visible output that must remain equivalent.
- [ ] 4.2 Add the JSX-authored parity example using wrappers from tasks 02 and 03.
- [ ] 4.3 Register the example with the TUI example build if a new executable is created.
- [ ] 4.4 Add rendered parity assertions for the direct-call and JSX example outputs.
- [ ] 4.5 Run the TUI package test/build commands and the relevant example executable.

## Implementation Details
Use `apps/tui/examples/agent_workspace.ml` as the source parity target and keep it available. If a new file is added, name it clearly as the JSX variant and include it in `apps/tui/examples/dune`. Reference the TechSpec "Integration Tests" and "Development Sequencing" sections for parity requirements.

### Relevant Files
- `apps/tui/examples/agent_workspace.ml` — direct-call parity target.
- `apps/tui/examples/dune` — executable registration for examples.
- `apps/tui/examples/agent_workspace/README.md` — example-specific documentation that may need JSX mention later.
- `apps/tui/test/test_tui.re` — place for rendered parity assertions.
- `apps/tui/lib/patterns.re` — source behavior for app shell, message, timeline, composer, and navigation patterns.

### Dependent Files
- `apps/tui/lib/tui.re` — exposes the JSX namespace used by the example.
- `apps/tui/lib/components/*` — component wrappers used by the JSX example.
- `apps/tui/lib/patterns.re` — pattern wrappers used by the JSX example.
- `apps/tui/examples/README.md` — docs task will reference the parity example.

### Related ADRs
- [ADR-002: Adopt Public JSX Kit Scope](adrs/adr-002.md) — Requires public examples for external users.
- [ADR-003: Select Adoption-Ready Public JSX Kit Approach](adrs/adr-003.md) — Requires adoption-ready examples.
- [ADR-004: Implement JSX As Wrapper Modules Over Existing TUI Components](adrs/adr-004.md) — Selects `agent_workspace` as first parity target.

## Deliverables
- Runnable JSX-authored `agent_workspace` parity example.
- Direct-call example preserved.
- Rendered parity checks between direct-call and JSX output.
- Unit tests with 80%+ coverage for parity helper behavior **(REQUIRED)**.
- Integration tests for the JSX example executable and rendered output **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] JSX example root renders the same visible session labels as the direct-call example.
  - [ ] JSX example root renders the same conversation labels and composer placeholder as the direct-call example.
  - [ ] JSX example root renders the same run-state labels as the direct-call example.
- Integration tests:
  - [ ] Direct-call and JSX `agent_workspace` rendered strings match or intentionally documented differences are asserted.
  - [ ] The JSX example executable builds through the examples Dune stanza.
  - [ ] `pnpm --filter @symphony-orchestrator/tui test` passes after adding the parity example.
  - [ ] `pnpm --filter @symphony-orchestrator/tui build` passes after adding the parity example.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing.
- Test coverage >=80%.
- JSX `agent_workspace` is runnable as a standalone package example.
- Rendered parity is proven against the existing direct-call example.
- No product-specific Terminal Console runtime wiring is introduced.
