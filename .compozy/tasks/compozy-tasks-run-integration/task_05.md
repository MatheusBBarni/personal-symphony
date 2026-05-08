---
status: pending
title: "Add Compozy progress to Runtime State"
type: backend
complexity: medium
dependencies:
  - task_03
---

# Task 05: Add Compozy progress to Runtime State

## Overview
Extend Runtime State with optional tracker kind and Compozy PRD-run progress fields. This makes backend snapshots capable of showing the current task step and aggregate progress without breaking existing clients.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST add optional `tracker_kind` to Runtime State JSON.
- R2 MUST add optional `compozy_progress` with run id, slug, current step, completed, failed, skipped, and total counts.
- R3 MUST keep existing Runtime State consumers compatible when the new fields are absent.
- R4 MUST derive progress from Compozy PRD-run data, not ad hoc dashboard-only logic.
- R5 MUST include serialization and parsing coverage for the new fields.
</requirements>

## Subtasks
- [ ] 5.1 Add backend Runtime State types for tracker kind and Compozy progress.
- [ ] 5.2 Serialize optional fields in Runtime State snapshots.
- [ ] 5.3 Parse optional fields where backend state is read from JSON.
- [ ] 5.4 Add tests for absent fields and populated Compozy progress.
- [ ] 5.5 Keep older Runtime State snapshots compatible.

## Implementation Details
Use TechSpec "Runtime State Projection". This task only adds backend state shape and tests; frontend rendering belongs to task_09.

### Relevant Files
- `apps/backend/lib/runtime_state.ml` — Runtime State data model, JSON serialization, and parsing.
- `apps/backend/test/test_backend.ml` — Existing Runtime State JSON tests.

### Dependent Files
- `apps/backend/lib/compozy_tasks_tracker.ml` — Supplies PRD-run progress data.
- `apps/backend/lib/orchestrator.ml` — Later tasks populate progress during Compozy runs.
- `apps/frontend/src/RuntimeStateSnapshot.res` — Later frontend task parses new fields.

### Related ADRs
- [ADR-002: Treat a Compozy PRD run as the local issue](adrs/adr-002.md) — Requires PRD-run progress visibility.
- [ADR-005: Relaunch task steps sequentially in one worktree](adrs/adr-005.md) — Requires current-step progress.
- [ADR-006: Configure task-step retries in Compozy tracker settings](adrs/adr-006.md) — Requires failed/skipped visibility.

## Deliverables
- Backend Runtime State fields for tracker kind and Compozy progress.
- JSON tests for new and absent fields.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for Runtime State snapshot shape **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Empty Runtime State omits or nulls Compozy progress without parse failure.
  - [ ] Runtime State serializes `tracker_kind = "compozy_tasks"`.
  - [ ] Runtime State serializes current step and aggregate counts.
  - [ ] Runtime State parses older snapshots without the new fields.
- Integration tests:
  - [ ] `/api/v1/state` payload shape can include Compozy progress without breaking existing required fields.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Backend Runtime State can represent Compozy PRD-run progress.
- Existing Runtime State behavior remains backward-compatible.
