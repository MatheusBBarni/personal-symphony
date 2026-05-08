---
status: completed
title: "Support selected-tracker identifiers in Ordered Queue"
type: backend
complexity: medium
dependencies:
  - task_02
  - task_04
---

# Task 06: Support selected-tracker identifiers in Ordered Queue

## Overview
Update Ordered Queue parsing and persistence to support both GitHub numeric selectors and minibeads `mb-<number>` selectors. Queue validation must rely on the selected Issue Tracker for existence and dispatchability instead of assuming GitHub issue numbers.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST accept GitHub selectors `20` and `#20`.
- R2 MUST accept minibeads selectors matching `mb-<number>`.
- R3 MUST reject URLs, cross-repository references, empty values, and malformed local identifiers.
- R4 MUST persist and compare queue entries by canonical issue identifier, not only numeric issue number.
- R5 MUST validate queue entries through the selected Issue Tracker.
</requirements>

## Subtasks
- [x] 6.1 Replace numeric-only queue entry storage with canonical identifier storage.
- [x] 6.2 Preserve GitHub selector normalization for `20` and `#20`.
- [x] 6.3 Add `mb-<number>` selector normalization.
- [x] 6.4 Update queue validation to use selected tracker lookup.
- [x] 6.5 Add persistence and resume tests for local identifiers.

## Implementation Details
Follow TechSpec "Data Models: Selector rules". Avoid accepting arbitrary local identifiers in V1.

### Relevant Files
- `apps/backend/lib/ordered_queue.ml` — Parser and queue model currently store numeric issue numbers.
- `apps/backend/lib/orchestrator.ml` — Queue filtering, queue state updates, and queue persistence use identifiers.
- `apps/backend/lib/runtime_state.ml` — Ordered Queue Runtime State JSON uses `issue_identifier`.
- `apps/backend/test/test_backend.ml` — Existing Ordered Queue parsing, persistence, and dispatch tests.

### Dependent Files
- `apps/backend/bin/main.ml` — CLI queue validation should use selected tracker behavior.
- `apps/backend/lib/issue_tracker.ml` — Provides identifier normalization and lookup.
- `apps/backend/lib/manual_merge.ml` — Manual merge selector support builds on the same identifier model in task_07.

### Related ADRs
- [ADR-003: Introduce a shared Issue Tracker boundary](adrs/adr-003.md) — Queue validation uses selected tracker.
- [ADR-006: Constrain V1 local identifiers and dashboard impact](adrs/adr-006.md) — Defines `mb-<number>` selector scope.

## Deliverables
- Ordered Queue parser accepts GitHub and minibeads selectors.
- Queue persistence compares canonical identifiers.
- Queue validation uses selected tracker lookup.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for queued local dispatch behavior **(REQUIRED)**

## Tests
- Unit tests:
  - [x] `20` normalizes to `#20`.
  - [x] `#20` remains `#20`.
  - [x] `mb-20` remains `mb-20`.
  - [x] `owner/repo#20`, URLs, empty entries, and malformed local IDs are rejected.
  - [x] Duplicate canonical identifiers are rejected.
  - [x] Persisted queue resume uses canonical identifier sequence.
- Integration tests:
  - [x] Ordered Queue dispatches a minibeads issue only when selected tracker lookup resolves it as dispatchable.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Ordered Queue works with `mb-<number>` without breaking existing GitHub queue selectors.
