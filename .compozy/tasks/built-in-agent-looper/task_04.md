---
status: pending
title: "Persist canonical Goal Loop state under Runtime Home"
type: backend
complexity: medium
dependencies:
  - task_02
---

# Task 04: Persist canonical Goal Loop state under Runtime Home

## Overview
This task adds durable storage for canonical Goal Loop state under Runtime Home. Persisted state is needed because successful completion clears active rows, but maintainers still need to inspect `goal_met`, `needs_attention`, and `budget_exhausted` outcomes.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- REQ-01 MUST persist canonical Goal Loop state under `.symphony/state/goal-loops/*.json`.
- REQ-02 MUST load persisted Goal Loop state for Runtime State projection and process resume.
- REQ-03 MUST write state files with private Runtime Home permissions consistent with existing diagnostics patterns.
- REQ-04 MUST store bounded, secret-free summaries in canonical state.
- REQ-05 SHOULD include pruning or retention behavior for stale stopped loops if existing Runtime State patterns support it.
</requirements>

## Subtasks
- [ ] 4.1 Add Runtime Home path helpers for Goal Loop state.
- [ ] 4.2 Add load, write, update, and delete helpers for Goal Loop JSON files.
- [ ] 4.3 Add private directory creation and permission handling.
- [ ] 4.4 Add bounded serialization and parse error handling.
- [ ] 4.5 Add tests using temporary Runtime Home directories.

## Implementation Details
Use the TechSpec "Data Models" and "Development Sequencing" sections. Follow existing Runtime Home state patterns such as ordered queue, Context Diagnostics, and Compozy lifecycle state rather than creating a separate storage root.

### Relevant Files
- `apps/backend/lib/orchestrator.ml` — has `runtime_state_dir`, Context Diagnostics, and ordered queue state helpers.
- `apps/backend/lib/compozy_lifecycle.ml` — stores Runtime Home lifecycle metadata under `.symphony/state`.
- `apps/backend/lib/runtime_state.ml` — later projects persisted state into Runtime State JSON.
- `apps/backend/test/test_backend.ml` — existing temp Runtime Home and persistence tests.

### Dependent Files
- `apps/backend/lib/runtime_state.ml` — depends on persisted state for task_05.
- `apps/backend/lib/orchestrator.ml` — depends on persistence for task_07 and task_08.
- `apps/backend/bin/terminal_console_runtime.ml` — later reads projected Runtime State.

### Related ADRs
- [ADR-003: Stage-Scoped Goal Loop Runtime State](adrs/adr-003.md) — Requires `.symphony/state/goal-loops/*.json` persistence.

## Deliverables
- Runtime Home persistence helpers for Goal Loop files.
- JSON read/write tests for active and stopped loop state.
- Permission and parse-error handling consistent with existing state directories.
- Unit tests with 80%+ coverage **(REQUIRED)**.
- Integration tests for load/update behavior from a temp Runtime Home **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] Writing a `running` loop creates a JSON file in `goal-loops`.
  - [ ] Loading a valid loop file reconstructs the expected Goal Loop state.
  - [ ] Invalid JSON is ignored or reported without crashing Runtime State creation.
  - [ ] Secret-like values in summaries are redacted or excluded according to existing sanitization rules.
- Integration tests:
  - [ ] A temp Runtime Home can persist, reload, update, and remove a Goal Loop state file.
  - [ ] Directory permissions match private Runtime Home state expectations.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Canonical Goal Loop state persists outside active rows.
- Runtime Home state remains private and secret-safe.
