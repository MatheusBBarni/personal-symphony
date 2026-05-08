---
status: pending
title: "Map Compozy PRD runs to Symphony issues"
type: backend
complexity: medium
dependencies:
  - task_02
---

# Task 03: Map Compozy PRD runs to Symphony issues

## Overview
Map one Compozy workflow directory under `.compozy/tasks/<task_name>/` into one Symphony work item. This task establishes the stable `compozy:<task_name>` identity used by Runtime State, branch naming, and later orchestration.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST discover PRD-run directories under the configured Compozy root.
- R2 MUST represent `.compozy/tasks/<task_name>/` as one PRD-run work item.
- R3 MUST generate canonical identifiers in the form `compozy:<task_name>`.
- R4 MUST map a PRD run to `Issue.t` without treating each `task_NN.md` as a separate issue.
- R5 MUST derive a safe branch/workspace key that does not depend on numeric-only issue identifiers.
- R6 MUST expose current step and aggregate counts for later Runtime State projection.
</requirements>

## Subtasks
- [ ] 3.1 Add PRD-run discovery from the configured Compozy root.
- [ ] 3.2 Build the `prd_run` model from parsed task files.
- [ ] 3.3 Map PRD runs into `Issue.t` values with stable identifiers and titles.
- [ ] 3.4 Add safe branch/workspace key derivation for Compozy identifiers.
- [ ] 3.5 Add tests for duplicate, missing, and multi-directory PRD-run cases.

## Implementation Details
Use TechSpec "PRD-Run Identifier" and "Core Interfaces" as the source of truth. Keep individual task-step details in the Compozy tracker module; expose only PRD-run identity and progress needed by shared runtime code.

### Relevant Files
- `apps/backend/lib/compozy_tasks_tracker.ml` — Owns PRD-run discovery and `Issue.t` mapping.
- `apps/backend/lib/issue.ml` — Existing tracker-neutral issue shape.
- `apps/backend/lib/orchestrator.ml` — Current branch key logic is numeric-oriented and will need a Compozy-safe path.
- `apps/backend/test/test_backend.ml` — Add PRD-run mapping and branch key tests.

### Dependent Files
- `apps/backend/lib/config.ml` — Supplies Compozy root.
- `apps/backend/lib/runtime_state.ml` — Later tasks will project PRD-run progress.
- `apps/backend/lib/ordered_queue.ml` and `apps/backend/lib/manual_merge.ml` — Later tasks may use canonical identifiers.

### Related ADRs
- [ADR-001: Scope Compozy tasks as a local tracker adapter](adrs/adr-001.md) — Requires stable identifiers before queue, branch, and status behavior.
- [ADR-002: Treat a Compozy PRD run as the local issue](adrs/adr-002.md) — Defines the PRD directory as the work item.

## Deliverables
- PRD-run discovery and `Issue.t` mapping.
- Safe Compozy identifier and branch/workspace key behavior.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for PRD-run fixture discovery **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] `.compozy/tasks/example-feature/` maps to `compozy:example-feature`.
  - [ ] `task_01.md` and `task_02.md` inside one directory do not create separate issues.
  - [ ] Branch/workspace key for `compozy:feature-123` is stable and non-empty.
  - [ ] Empty PRD-run directory is reported as not runnable.
  - [ ] Two workflow directories with `task_01.md` produce distinct PRD-run identifiers.
- Integration tests:
  - [ ] Temporary Compozy root with two PRD directories yields two `Issue.t` candidates.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- PRD-run identity is stable and collision-resistant for V1.
- Individual task files are not exposed as separate Symphony issues.
