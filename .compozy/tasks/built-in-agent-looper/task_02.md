---
status: pending
title: "Add Goal Loop domain model and transition rules"
type: backend
complexity: medium
dependencies:
  - task_01
---

# Task 02: Add Goal Loop domain model and transition rules

## Overview
This task creates the pure backend domain model that all later Goal Loop work depends on. It defines loop state, stop outcomes, budgets, evidence summaries, and transition results without coupling the logic to Git, tracker, server, or UI modules.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- REQ-01 MUST add a pure backend Goal Loop module for state and transition decisions.
- REQ-02 MUST model states `running`, `retrying`, `goal_met`, `needs_attention`, and `budget_exhausted`.
- REQ-03 MUST model stop outcomes, stop reasons, latest evidence, next action, attempt count, and budget values.
- REQ-04 MUST keep the module independent from Git, tracker, server, Terminal Console, and Web Dashboard code.
- REQ-05 MUST include serialization-friendly fields matching the TechSpec "Core Interfaces" and "Data Models" sections.
</requirements>

## Subtasks
- [ ] 2.1 Add the Goal Loop domain type definitions.
- [ ] 2.2 Add transition helpers for dispatch start, retry, evidence success, evidence failure, budget exhaustion, and attention.
- [ ] 2.3 Add bounded summary helpers for stop reason, evidence, and next action fields.
- [ ] 2.4 Add unit tests for every supported transition.
- [ ] 2.5 Register the new backend module in the local build surface.

## Implementation Details
Create a small backend module for pure Goal Loop behavior. Follow the TechSpec "System Architecture" and "Data Models" sections; do not wire the module into config, persistence, Runtime State, or orchestrator behavior in this task.

### Relevant Files
- `apps/backend/lib/runtime_state.ml` — shows existing Runtime State type style and JSON-friendly field naming.
- `apps/backend/lib/config.ml` — later tasks will consume domain budget and config concepts.
- `apps/backend/lib/orchestrator.ml` — later tasks will call the pure transition helpers.
- `apps/backend/test/test_backend.ml` — existing test target for backend pure and integration tests.
- `apps/backend/dune` — build surface for backend library modules if module registration is explicit.

### Dependent Files
- `apps/backend/lib/runtime_state.ml` — depends on this task for Goal Loop projection types in task_05.
- `apps/backend/lib/orchestrator.ml` — depends on this task for lifecycle transitions in task_07 and task_08.
- `apps/backend/lib/config.ml` — depends on this task for stage-scoped config validation in task_03.

### Related ADRs
- [ADR-001: Goal Loop Runtime Scope](adrs/adr-001.md) — Requires Runtime-owned Goal Loop contracts.
- [ADR-003: Stage-Scoped Goal Loop Runtime State](adrs/adr-003.md) — Requires canonical state fields.
- [ADR-004: Evidence Command Completion Gate](adrs/adr-004.md) — Requires evidence and stop outcomes.

## Deliverables
- New pure Goal Loop backend module.
- Unit tests for state creation and transitions.
- Build registration if required by the backend build system.
- Unit tests with 80%+ coverage **(REQUIRED)**.
- Integration tests are not required for this pure domain slice **(REQUIRED: document as not applicable in task handoff)**.

## Tests
- Unit tests:
  - [ ] Creating a new loop state sets `running`, attempt count, goal, stage, harness, and budget fields.
  - [ ] Evidence success transitions to `goal_met` with latest evidence and no next action.
  - [ ] Evidence failure before retry exhaustion transitions to `retrying` with missing-evidence guidance.
  - [ ] Evidence failure after retry exhaustion transitions to `needs_attention`.
  - [ ] Budget exhaustion transitions to `budget_exhausted` with a bounded reason.
- Integration tests:
  - [ ] Not applicable for this task because no orchestrator or Runtime State integration is introduced.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Goal Loop transition behavior is covered without side effects.
- Later tasks can consume the module without importing UI, tracker, Git, or server dependencies.
