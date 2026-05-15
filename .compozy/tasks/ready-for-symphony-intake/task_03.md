---
status: pending
title: "Parse Compozy _tasks.md ready status and gate PRD-run admission"
type: backend
complexity: high
dependencies:
  - task_01
---

# Task 03: Parse Compozy _tasks.md ready status and gate PRD-run admission

## Overview
Add the Compozy-ready parser for `_tasks.md` and combine it with existing runnable-run rules so a Compozy PRD Run becomes newly admissible only when its run-level intake status is ready. This task must preserve the split between Compozy Task Step execution truth, Compozy PRD Run Lifecycle state, and the new repository-owned intake signal.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details - do not duplicate here
- FOCUS ON "WHAT" - describe what needs to be accomplished, not how
- MINIMIZE CODE - show code only to illustrate current structure or problem areas
- TESTS REQUIRED - every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST read the Compozy-ready status from `.compozy/tasks/<slug>/_tasks.md` as a run-level intake source.
- R2 MUST require both the configured ready-status match and existing runnable-run conditions before a Compozy PRD Run is newly admissible.
- R3 MUST keep `task_NN.md` frontmatter as the authoritative source for Compozy Task Step execution progress.
- R4 MUST keep Compozy PRD Run Lifecycle metadata as the authoritative post-admission orchestration state.
- R5 MUST return deterministic parse or non-ready reasons for `_tasks.md` states that do not satisfy the Symphony-ready rule.
- R6 MUST include backend test coverage for ready parsing, non-ready parsing, missing file handling, and preserved lifecycle separation.
</requirements>

## Subtasks
- [ ] 3.1 Add a narrow parser for the Compozy-ready status in `_tasks.md`.
- [ ] 3.2 Combine the parsed run-level ready status with existing runnable-run checks for first-admission decisions.
- [ ] 3.3 Preserve task-step and lifecycle ownership boundaries while exposing Compozy admission reasons.
- [ ] 3.4 Extend backend tests for `_tasks.md` parsing, ready gating, and lifecycle compatibility.

## Implementation Details
Reference the TechSpec "Data Models", "Integration Points", and "Technical Considerations" sections, especially the Compozy Ready Summary and the intake-versus-lifecycle separation. Keep this task limited to Compozy adapter semantics and `_tasks.md` parsing; idle startup, queue interaction, and Runtime State visibility belong to later tasks.

### Relevant Files
- `apps/backend/lib/compozy_tasks_tracker.ml` - Compozy PRD Run discovery, task-step parsing, and runnable-run logic that must incorporate `_tasks.md` readiness.
- `apps/backend/lib/issue_tracker.ml` - Shared tracker contract that will expose the Compozy first-admission decision.
- `apps/backend/lib/compozy_lifecycle.ml` - Existing run-level lifecycle state that must remain distinct from the new intake source.
- `apps/backend/test/test_backend.ml` - Existing Compozy fixtures and integration-heavy tests to extend near current runnable-run coverage.

### Dependent Files
- `apps/backend/lib/runtime_readiness.ml` - Later task will stop treating "no ready run" as a structural readiness gap.
- `apps/backend/lib/orchestrator.ml` - Later task will dispatch Compozy runs only when the tracker reports ready first-admission eligibility.
- `README.md` - Later docs task will explain `_tasks.md` as the Compozy-ready intake source.

### Related ADRs
- [ADR-002: Use a standard Symphony-ready status convention across trackers](adrs/adr-002.md) - Requires one shared product-ready concept across trackers.
- [ADR-004: Read Compozy Symphony-ready status from _tasks.md while keeping task-step state separate](adrs/adr-004.md) - Defines `_tasks.md` as the repository-owned intake source.

## Deliverables
- Compozy `_tasks.md` parsing for the Symphony-ready Status.
- Compozy PRD Run admission logic that combines ready-status parsing with existing runnable-run checks.
- Backend tests covering `_tasks.md` readiness parsing and preserved task-step or lifecycle separation.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for Compozy-ready admission behavior **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] `_tasks.md` containing the configured ready status returns an eligible-ready summary for the Compozy PRD Run.
  - [ ] `_tasks.md` containing a non-ready status returns a deterministic non-eligible admission reason.
  - [ ] Missing or malformed `_tasks.md` returns a deterministic parse or readiness failure without corrupting task-step parsing.
  - [ ] Runnable-run checks still reject non-runnable Compozy PRD Runs even when `_tasks.md` is ready.
- Integration tests:
  - [ ] A Compozy PRD Run becomes newly admissible only when `_tasks.md` is ready and the existing runnable-run conditions are satisfied.
  - [ ] Existing Compozy Task Step progression and Compozy PRD Run Lifecycle tests continue to pass without moving execution truth into `_tasks.md`.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Compozy first admission requires both `_tasks.md` ready status and existing runnable-run eligibility.
- `_tasks.md` remains intake-only and does not replace task-step or lifecycle truth.
