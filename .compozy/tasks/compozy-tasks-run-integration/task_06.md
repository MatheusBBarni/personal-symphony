---
status: pending
title: "Wire Compozy readiness and run selection in CLI startup"
type: backend
complexity: high
dependencies:
  - task_01
  - task_03
  - task_05
---

# Task 06: Wire Compozy readiness and run selection in CLI startup

## Overview
Connect the selected Compozy tracker kind to runtime startup and readiness behavior. This task makes Compozy tracker runs start through the normal CLI without GitHub remote readiness checks.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST route `tracker.kind = "compozy_tasks"` to the Compozy-specific runtime path.
- R2 MUST avoid GitHub remote readiness checks for Compozy tracker runs.
- R3 MUST surface Compozy readiness gaps through normal Runtime State readiness gaps.
- R4 MUST keep GitHub startup, readiness, queue validation, and server startup behavior unchanged.
- R5 MUST initialize Runtime State with the selected tracker kind for Compozy runs.
- R6 MUST not change Workspace Repository root validation semantics.
</requirements>

## Subtasks
- [ ] 6.1 Add Compozy tracker readiness checks for root and runnable PRD-run candidates.
- [ ] 6.2 Route CLI startup by selected tracker kind.
- [ ] 6.3 Skip GitHub remote readiness for Compozy tracker runs.
- [ ] 6.4 Populate tracker kind and initial Compozy progress in Runtime State.
- [ ] 6.5 Add startup/readiness tests for GitHub and Compozy paths.

## Implementation Details
Follow TechSpec "Data Flow" and "Impact Analysis" for `main.ml`. Keep the narrow Compozy path isolated and preserve existing GitHub code paths.

### Relevant Files
- `apps/backend/bin/main.ml` — Startup wiring, readiness state, queue validation, and runtime launch.
- `apps/backend/lib/config.ml` — Selected tracker kind and Compozy settings.
- `apps/backend/lib/compozy_tasks_tracker.ml` — Readiness checks and PRD-run discovery.
- `apps/backend/lib/runtime_state.ml` — Readiness gaps and tracker progress projection.
- `apps/backend/test/test_backend.ml` — Readiness and runtime policy tests.

### Dependent Files
- `apps/backend/lib/orchestrator.ml` — Later task consumes Compozy run path.
- `apps/backend/lib/github_tracker.ml` — Must remain untouched behaviorally for GitHub runs.

### Related ADRs
- [ADR-003: Add a narrow Compozy tracker path](adrs/adr-003.md) — Requires contained Compozy startup path.
- [ADR-004: Persist task-step progress in Compozy task files](adrs/adr-004.md) — Readiness must validate task files before execution.

## Deliverables
- Compozy tracker startup path in CLI runtime.
- Compozy readiness gaps in Runtime State.
- Existing GitHub readiness behavior preserved.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for Compozy startup readiness **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Compozy tracker with missing root emits a Compozy readiness gap.
  - [ ] Compozy tracker with no runnable task files emits a Compozy readiness gap.
  - [ ] Compozy tracker readiness does not include GitHub owner, repo, project number, or token gaps.
  - [ ] GitHub tracker readiness still includes GitHub gaps when configured incorrectly.
- Integration tests:
  - [ ] CLI readiness state for a valid Compozy fixture has no GitHub remote readiness dependency.
  - [ ] CLI readiness state for GitHub tracker is unchanged.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- `tracker.kind = "compozy_tasks"` starts through the Compozy runtime path.
- GitHub startup behavior remains unchanged.
