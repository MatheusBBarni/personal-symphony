---
status: pending
title: "Add `Tui.Jsx` Namespace And Core Wrapper Conventions"
type: backend
complexity: medium
dependencies: []
---

# Task 01: Add `Tui.Jsx` Namespace And Core Wrapper Conventions

## Overview
This task establishes the public JSX namespace and the first wrapper conventions for the TUI package. It gives later wrapper tasks a stable module shape, explicit text-node rule, and export path without changing existing component behavior.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- REQ-01 MUST add a public `Tui.Jsx` namespace under `apps/tui` using Reason source files.
- REQ-02 MUST expose JSX-friendly wrapper modules for the core authoring convention, including explicit text nodes and child-list wrappers.
- REQ-03 MUST return existing `Tui.Node.t` values from wrappers and MUST NOT introduce a second render tree.
- REQ-04 MUST export the namespace through `apps/tui/lib/tui.re` without removing or renaming existing public exports.
- REQ-05 MUST add focused tests proving the namespace compiles, core wrappers render, and direct component calls still work.
</requirements>

## Subtasks
- [ ] 1.1 Review `_prd.md`, `_techspec.md`, and ADR-004 before editing.
- [ ] 1.2 Add the `Tui.Jsx` namespace with the first wrapper modules and explicit text-node convention.
- [ ] 1.3 Export `Jsx` from the public `Tui` module while preserving all existing aliases.
- [ ] 1.4 Add focused tests for namespace availability, explicit text, and core wrapper output.
- [ ] 1.5 Run the TUI package test/build commands required for this compile-surface change.

## Implementation Details
Create the JSX namespace in `apps/tui/lib` and export it from `apps/tui/lib/tui.re`. Reference the TechSpec "Core Interfaces" section for wrapper shape and ADR-004 for the explicit text-node and `Tui.Node.t` constraints.

### Relevant Files
- `apps/tui/lib/tui.re` — public package module exports and existing top-level aliases.
- `apps/tui/lib/node.re` — source of the `Tui.Node.t` model and primitive constructors.
- `apps/tui/lib/components/components_core.re` — existing component entrypoint used by wrappers.
- `apps/tui/lib/dune` — public library stanza and subdirectory handling.
- `apps/tui/test/test_tui.re` — existing package test suite for rendering and component behavior.

### Dependent Files
- `apps/tui/lib/components/*` — later tasks wrap these functions through the new namespace.
- `apps/tui/lib/patterns.re` — later tasks wrap patterns through the same convention.
- `apps/tui/examples/dune` — later examples depend on the exported namespace.

### Related ADRs
- [ADR-002: Adopt Public JSX Kit Scope](adrs/adr-002.md) — Establishes public JSX kit scope.
- [ADR-004: Implement JSX As Wrapper Modules Over Existing TUI Components](adrs/adr-004.md) — Defines wrapper modules, explicit text nodes, and `Tui.Node.t` output.

## Deliverables
- Public `Tui.Jsx` namespace exported from the TUI package.
- Core wrapper convention implemented with explicit text-node behavior.
- Existing public `Tui` exports preserved.
- Unit tests with 80%+ coverage for the new namespace behavior **(REQUIRED)**.
- Integration tests for package compile/export behavior **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] `Tui.Jsx.Text` renders the same visible text as `Components.text` for a simple string.
  - [ ] `Tui.Jsx.Box` renders child nodes produced by explicit text wrappers.
  - [ ] Existing direct `Tui.text` and `Tui.box` calls still render after the namespace export.
- Integration tests:
  - [ ] `pnpm --filter @symphony-orchestrator/tui test` passes after adding the namespace.
  - [ ] `pnpm --filter @symphony-orchestrator/tui build` passes after adding the namespace.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing.
- Test coverage >=80%.
- `Tui.Jsx` is available from the public `Tui` module.
- Core wrappers return existing `Tui.Node.t` values with no alternate tree model.
- Existing direct component-call examples still compile.
