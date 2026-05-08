---
status: pending
title: "Support Compozy identifiers in queue and manual merge flows"
type: backend
complexity: high
dependencies:
  - task_03
  - task_07
---

# Task 10: Support Compozy identifiers in queue and manual merge flows

## Overview
Add `compozy:<task_name>` selector support to the operator flows needed for tracker replacement confidence. This task preserves existing numeric GitHub behavior while allowing Compozy PRD-run identifiers where V1 explicitly supports them.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST preserve existing Ordered Queue parsing for numeric GitHub selectors.
- R2 MUST accept canonical Compozy selectors in the form `compozy:<task_name>` where Compozy queue support is enabled.
- R3 MUST preserve existing Manual Task Merge behavior for numeric GitHub selectors.
- R4 MUST allow Manual Task Merge validation for completed Compozy PRD-run branches only when required by V1 behavior.
- R5 MUST reject malformed Compozy selectors with actionable diagnostics.
- R6 MUST not require GitHub Project membership for Compozy selector validation.
</requirements>

## Subtasks
- [ ] 10.1 Extend Ordered Queue selector parsing to represent canonical identifiers.
- [ ] 10.2 Validate Compozy queue identifiers against discovered PRD runs.
- [ ] 10.3 Extend Manual Task Merge selector handling for Compozy PRD-run identifiers.
- [ ] 10.4 Keep GitHub numeric selector behavior unchanged.
- [ ] 10.5 Add queue and merge tests for Compozy and GitHub selectors.

## Implementation Details
Follow TechSpec "Impact Analysis" for queue and merge. Because ADR-003 chose a narrow path, avoid a broad selected-tracker refactor unless strictly needed for these flows.

### Relevant Files
- `apps/backend/lib/ordered_queue.ml` — Current numeric-only queue parser and persistence sequence behavior.
- `apps/backend/lib/manual_merge.ml` — Current numeric-only Manual Task Merge selector and GitHub project lookup behavior.
- `apps/backend/bin/main.ml` — Queue validation and Manual Task Merge wiring.
- `apps/backend/lib/compozy_tasks_tracker.ml` — PRD-run lookup by canonical identifier.
- `apps/backend/test/test_backend.ml` — Existing queue and manual merge test sections.

### Dependent Files
- `apps/backend/lib/orchestrator.ml` — Uses queue entries and branch/workspace helpers.
- `apps/backend/lib/runtime_state.ml` — Ordered Queue state stores issue identifiers.

### Related ADRs
- [ADR-001: Scope Compozy tasks as a local tracker adapter](adrs/adr-001.md) — Requires stable identifiers before queue and merge behavior.
- [ADR-002: Treat a Compozy PRD run as the local issue](adrs/adr-002.md) — Defines PRD-run identifiers as user-facing work items.
- [ADR-003: Add a narrow Compozy tracker path](adrs/adr-003.md) — Constrains this task to the narrow path.

## Deliverables
- Compozy identifier support for selected queue and merge flows.
- Existing GitHub selector behavior preserved.
- Actionable diagnostics for malformed selectors.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for Compozy queue/manual merge behavior **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Existing queue parse `"19,#22,31"` still returns GitHub identifiers.
  - [ ] Queue parse accepts `compozy:example-feature`.
  - [ ] Duplicate Compozy selectors are rejected.
  - [ ] Malformed selectors such as `compozy:` and URLs return actionable errors.
  - [ ] Manual Task Merge still accepts `20` and `#20`.
  - [ ] Manual Task Merge accepts valid completed Compozy PRD-run identifiers when supported.
- Integration tests:
  - [ ] Compozy queue validation resolves an existing PRD-run fixture without GitHub Project membership.
  - [ ] GitHub queue and Manual Task Merge tests continue to pass.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Operators can reference Compozy PRD runs by canonical identifier where V1 supports it.
- Existing GitHub queue and merge flows are unchanged.
