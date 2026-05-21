---
status: completed
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
- REQ-04 MUST document the supported V1 JSX component and pattern surface using the actual public wrappers shipped by tasks 02-04.
- REQ-05 MUST include migration guidance from direct component calls to JSX, including explicit text-node expectations.
- REQ-06 MUST keep examples and wording focused on standalone Reason/OCaml terminal-tool users.
- REQ-07 MUST define the canonical V1 example path for adoption docs as `demo`, `operations_dashboard`, and the JSX `agent_workspace` parity example produced by task 04.
- REQ-08 MUST explicitly state V1 non-goals and escape hatches relevant to migration: no React runtime compatibility, no implicit string children, `Tui.Presets.Open_code.*` stays direct-call only, and `Components.repeat` / `Components.fit` stay direct-call helpers.
- REQ-09 MUST avoid Symphony Runtime Contract terminology in public TUI package docs unless a comparison is strictly necessary.
</requirements>

## Subtasks
- [ ] 5.1 Confirm the actual task 02-04 outputs in `apps/tui/lib/jsx.re`, `apps/tui/examples/dune`, and the example files before editing docs; do not trust task status metadata alone if implementation drift is visible.
- [ ] 5.2 Update the TUI README with a JSX-first quickstart for standalone Reason/OCaml users, while still naming direct components and patterns as stable lower-level APIs.
- [ ] 5.3 Add a supported-surface section that lists the V1 `Tui.Jsx` wrappers actually shipped by the package and clearly calls out the remaining direct-call-only helpers and presets.
- [ ] 5.4 Add migration guidance for direct component and pattern calls to JSX wrappers, including explicit text-node usage, `children` conventions, and when to stay on the lower-level APIs.
- [ ] 5.5 Update the examples index to highlight the canonical V1 adoption path (`demo`, `operations_dashboard`, JSX `agent_workspace`) and separate advanced/reference examples from that path.
- [ ] 5.6 Update example-specific documentation for the JSX `agent_workspace` parity target using the exact executable/file shape chosen in task 04.
- [ ] 5.7 Verify every documented command and code snippet against the package scripts, example registrations, and the actual public API names.

## Implementation Details
Documentation should reference the implemented wrapper surface from tasks 02-04 and the PRD user experience. Keep implementation mechanics in the TechSpec and docs focused on usage, migration, and compatibility.

The README quickstart should be the first path a new standalone package evaluator follows:

- install `symphony-orchestrator-tui`
- add the library to a small Dune executable
- open `Tui`
- compose a small screen with `Tui.Jsx`
- render it with `Renderer.create` and `Renderer.render_to_string`
- run one bundled example from `apps/tui`

The supported-surface section should be explicit rather than descriptive. It should group the public JSX wrappers by the approved V1 inventories from tasks 02 and 03 and confirm that the final list matches the actual `apps/tui/lib/jsx.re` exports. The expected V1 groups are:

- Components: `Text`, `Box`, `RichText`, `VerticalRule`, `Spacer`, `Input`, `Option`, `Select`, `ScrollBox`, `ProgressBar`, `Sparkline`, `Row`, `Column`, `Panel`, `Badge`, `TabBar`, `KeyValue`, `Table`, `Split`, `Divider`, `Callout`, `EmptyState`, `Toolbar`, and `Meter`.
- Patterns: `RulePanel`, `Modal`, `Header`, `MetricCard`, `LogFeed`, `SectionTitle`, `NavItem`, `Message`, `Timeline`, `Composer`, `CommandBar`, `Footer`, and `AppShell`.

Migration guidance should show how to move from direct calls to JSX without implying a renderer or runtime change. It should cover:

- explicit text nodes instead of implicit string children
- mapping direct `Components.*` and `Patterns.*` calls to `Tui.Jsx.*` modules
- preserving direct-call usage for lower-level control, table helpers, and preset helpers
- the fact that JSX still produces `Tui.Node.t`

Avoid Product Repository, Workspace Repository, Runtime Home, Runtime Contract, or other Symphony orchestration terminology in the public package docs unless a contrast is strictly necessary and phrased with `CONTEXT.md` terms exactly. Avoid implying React runtime compatibility.

### Relevant Files
- `apps/tui/README.md` — primary public package entrypoint.
- `apps/tui/examples/README.md` — examples index and "Choosing An Example" guidance.
- `apps/tui/examples/agent_workspace/README.md` — example-specific explanation for the parity target.
- `apps/tui/examples/demo/README.md` — baseline quickstart/example reference.
- `apps/tui/examples/dune` — source of truth for runnable example executables mentioned in docs.
- `apps/tui/lib/jsx.re` — source of truth for the supported JSX wrapper inventory.
- `apps/tui/package.json` — package scripts documented for build/test.

### Dependent Files
- `apps/tui/lib/tui.re` — docs reference the public `Tui.Jsx` namespace.
- `apps/tui/lib/components/components_core.re` — supported component-wrapper docs must match the lower-level API names and intentional direct-call-only helpers.
- `apps/tui/lib/patterns.re` — supported pattern-wrapper docs and migration notes must match the canonical lower-level APIs.
- `apps/tui/examples/*` — docs must match actual example names, commands, and parity target structure.
- `apps/tui/test/test_tui.re` — tests may include doc-backed helper or example render coverage from prior tasks.

### Related ADRs
- [ADR-003: Select Adoption-Ready Public JSX Kit Approach](adrs/adr-003.md) — Requires docs, examples, migration guidance, and JSX as recommended path.
- [ADR-004: Implement JSX As Wrapper Modules Over Existing TUI Components](adrs/adr-004.md) — Defines explicit text nodes and direct components as lower-level API.

## Risks And Notes
- Dependency drift risk: tasks 02-04 define the expected docs surface, but this task must document the actual shipped `Tui.Jsx` exports and example executables rather than planned names.
- Messaging risk: docs must not accidentally frame direct `Tui.Components` or `Tui.Patterns` usage as deprecated.
- Adoption risk: the quickstart and example index can fail the PRD if they drift into Symphony-specific runtime or repository language instead of standalone terminal-tool usage.

## Deliverables
- Updated `apps/tui/README.md` with a JSX-first quickstart, compatibility messaging, supported-surface guide, and migration notes.
- Updated examples index and relevant example README files, with a clear canonical V1 adoption path and separate advanced/reference examples.
- Supported JSX surface and V1 non-goals documented against the actual public package exports.
- Any reusable doc-backed helper or example code introduced by this task is covered by focused TUI tests **(REQUIRED)**.
- Integration checks prove the documented commands, example names, and package scripts remain correct **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] Any reusable documentation snippet or example helper introduced by this task is covered by focused TUI tests.
  - [ ] Existing JSX wrapper and parity tests still cover every component, pattern, and example path named in the supported-surface and migration guides.
  - [ ] If the quickstart is backed by a new reusable example/helper, it has a focused render or API smoke assertion in the TUI test suite.
- Integration tests:
  - [ ] The documented standalone quickstart either builds through the package workflow or is intentionally mirrored by an existing checked-in example with the same public API shape.
  - [ ] The documented JSX `agent_workspace` example command from the example README builds or runs through the examples Dune stanza.
  - [ ] `pnpm --filter @symphony-orchestrator/tui test` passes after docs updates.
  - [ ] `pnpm --filter @symphony-orchestrator/tui build` passes after docs updates.
- Test coverage target: preserve package coverage for any executable helper code introduced by this task; do not add synthetic coverage scaffolding for docs-only copy changes.
- All tests must pass

## Success Criteria
- All tests passing.
- README names JSX as the recommended path for new TUI screens.
- README and examples docs clearly identify the canonical V1 adoption path as `demo`, `operations_dashboard`, and the JSX `agent_workspace` parity example.
- Docs clearly list the supported V1 `Tui.Jsx` surface and the intentional non-scope items that remain direct-call only.
- Docs clearly state direct components remain supported lower-level APIs.
- Docs do not require Symphony-specific runtime knowledge or terminology for the standalone quickstart path.
- Every documented command and public API name is verified against the actual package files.
- A new standalone Reason/OCaml user can follow the quickstart without Symphony-specific runtime knowledge.
