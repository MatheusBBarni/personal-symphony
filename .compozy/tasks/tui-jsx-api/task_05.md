---
status: pending
title: "Document JSX Quickstart, Supported Surface, And Migration Path"
type: docs
complexity: medium
dependencies:
  - task_02
  - task_03
  - task_04
---

# Task 05: Document JSX Quickstart, Supported Surface, And Migration Path

## Overview
This task turns the implemented JSX surface into the adoption-ready public path required by the PRD. It updates the TUI documentation so external Reason/OCaml users can build a small standalone terminal UI without first reading internal Symphony source code.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- REQ-01 MUST present JSX as the recommended authoring path for new TUI screens.
- REQ-02 MUST document direct `Tui.Components` and `Tui.Patterns` calls as stable lower-level APIs, not deprecated paths.
- REQ-03 MUST include a standalone quickstart that supports the PRD's under-30-minute success goal.
- REQ-04 MUST document the supported V1 JSX component and pattern surface.
- REQ-05 MUST include migration guidance from direct component calls to JSX, including explicit text-node expectations.
- REQ-06 MUST keep examples and wording focused on standalone Reason/OCaml terminal-tool users.
</requirements>

## Subtasks
- [ ] 5.1 Update the TUI README with the JSX recommended-path quickstart.
- [ ] 5.2 Add a supported-surface section for JSX wrappers.
- [ ] 5.3 Add migration guidance for direct component calls to JSX wrappers.
- [ ] 5.4 Update the examples index to include JSX examples and when to use them.
- [ ] 5.5 Update example-specific documentation for the JSX `agent_workspace` parity example.
- [ ] 5.6 Verify documented commands and code snippets against the package.

## Implementation Details
Documentation should reference the implemented wrapper surface from tasks 02-04 and the PRD user experience. Keep implementation mechanics in the TechSpec and docs focused on usage, migration, and compatibility. Avoid implying React runtime compatibility.

### Relevant Files
- `apps/tui/README.md` — primary public package entrypoint.
- `apps/tui/examples/README.md` — examples index and "Choosing An Example" guidance.
- `apps/tui/examples/agent_workspace/README.md` — example-specific explanation for the parity target.
- `apps/tui/examples/demo/README.md` — baseline quickstart/example reference.
- `apps/tui/package.json` — package scripts documented for build/test.

### Dependent Files
- `apps/tui/lib/tui.re` — docs reference the public `Tui.Jsx` namespace.
- `apps/tui/examples/*` — docs must match actual example names and commands.
- `apps/tui/test/test_tui.re` — tests may include doc-snippet or example render coverage from prior tasks.

### Related ADRs
- [ADR-003: Select Adoption-Ready Public JSX Kit Approach](adrs/adr-003.md) — Requires docs, examples, migration guidance, and JSX as recommended path.
- [ADR-004: Implement JSX As Wrapper Modules Over Existing TUI Components](adrs/adr-004.md) — Defines explicit text nodes and direct components as lower-level API.

## Deliverables
- Updated `apps/tui/README.md` with JSX quickstart and compatibility guidance.
- Updated examples index and relevant example README files.
- Supported JSX surface and migration guidance documented.
- Unit tests with 80%+ coverage for any doc-backed snippet helpers or examples touched **(REQUIRED)**.
- Integration tests for documented example commands and package docs consistency **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] Any reusable documentation snippet or example helper introduced by this task is covered by focused TUI tests.
  - [ ] Existing wrapper tests still cover the components and patterns named in the supported-surface guide.
- Integration tests:
  - [ ] Documented JSX example command builds or runs through the TUI package workflow.
  - [ ] `pnpm --filter @symphony-orchestrator/tui test` passes after docs updates.
  - [ ] `pnpm --filter @symphony-orchestrator/tui build` passes after docs updates.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing.
- Test coverage >=80%.
- README names JSX as the recommended path for new TUI screens.
- Docs clearly state direct components remain supported lower-level APIs.
- A new standalone Reason/OCaml user can follow the quickstart without Symphony-specific runtime knowledge.
