---
status: completed
title: "Add ready-status Runtime Settings and tracker admission contract"
type: backend
complexity: medium
dependencies: []

---

# Task 01: Add ready-status Runtime Settings and tracker admission contract

## Overview
Add the shared Runtime Settings field for the Symphony-ready Status and extend the selected Issue Tracker boundary with a first-admission contract. This task establishes the configuration and adapter seam that the GitHub and Compozy intake tasks depend on, so it must keep ready-status semantics owned by tracker adapters instead of leaking them into Orchestrator policy.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details - do not duplicate here
- FOCUS ON "WHAT" - describe what needs to be accomplished, not how
- MINIMIZE CODE - show code only to illustrate current structure or problem areas
- TESTS REQUIRED - every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST add a dedicated Runtime Settings field for the Symphony-ready Status without overloading existing active, terminal, or stage-transition settings.
- R2 MUST keep the first-admission rule at the selected Issue Tracker boundary by extending the tracker contract with an explicit admission decision.
- R3 MUST preserve existing tracker fetch, normalization, active-state, and terminal-state behavior for callers that do not depend on first-admission filtering yet.
- R4 MUST keep the ready-status configuration available to both the GitHub Tracker and the Compozy-backed Local Issue Tracker through one shared settings model.
- R5 MUST include backend test coverage for config parsing, default handling, and tracker admission-decision plumbing.
</requirements>

## Subtasks
- [x] 1.1 Add the shared Runtime Settings field for the Symphony-ready Status in backend config parsing and effective runtime configuration.
- [x] 1.2 Extend the Issue Tracker contract with a first-admission decision type and adapter-facing function.
- [x] 1.3 Thread the ready-status setting through tracker construction without changing unrelated Runtime Contract semantics.
- [x] 1.4 Add focused backend tests for config parsing and tracker admission contract behavior.

## Implementation Details
Reference the TechSpec "System Architecture", "Implementation Design", and "Data Models" sections, especially the Runtime Settings and Tracker Admission Decision guidance. Keep this task limited to the shared config and tracker-boundary seam; GitHub exact-match filtering and Compozy `_tasks.md` parsing belong to later tasks.

### Relevant Files
- `apps/backend/lib/config.ml` - Runtime Settings parsing and effective config model for the new ready-status field.
- `apps/backend/lib/runtime_home.ml` - Bootstrap Runtime Contract defaults that may need the ready-status field reflected in user-facing settings templates.
- `apps/backend/lib/issue_tracker.ml` - Shared selected Issue Tracker boundary that should own first-admission semantics.
- `apps/backend/test/test_backend.ml` - Existing config and tracker integration tests to extend near related cases.

### Dependent Files
- `apps/backend/lib/github_tracker.ml` - Will implement the GitHub-specific admission rule on top of the new tracker contract.
- `apps/backend/lib/compozy_tasks_tracker.ml` - Will implement Compozy-ready evaluation using the shared admission seam.
- `apps/backend/lib/orchestrator.ml` - Later task will consume the tracker admission result during dispatch and queue validation.
- `.github/project-tracking.md` - Later docs work should keep GitHub project-status guidance aligned with the new ready-status setting.

### Related ADRs
- [ADR-002: Use a standard Symphony-ready status convention across trackers](adrs/adr-002.md) - Defines one shared product concept for first admission.
- [ADR-003: Put Symphony-ready status at the tracker boundary with exact-match first-admission semantics](adrs/adr-003.md) - Requires the tracker-owned contract added here.

## Deliverables
- Runtime Settings support for a dedicated Symphony-ready Status field.
- A tracker admission-decision contract available at the selected Issue Tracker boundary.
- Backend tests covering config parsing and tracker admission contract wiring.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for tracker construction and admission plumbing **(REQUIRED)**

## Tests
- Unit tests:
  - [x] Config parsing accepts the ready-status field and preserves existing defaults for unrelated Runtime Settings.
  - [x] Missing ready-status configuration resolves to the documented default without mutating user-edited Runtime Contract files.
  - [x] Issue Tracker admission decisions can be constructed without changing existing active-state or terminal-state helpers.
- Integration tests:
  - [x] Effective runtime config exposes one ready-status value to both the GitHub Tracker and Compozy-backed Local Issue Tracker constructors.
  - [x] Bootstrap settings defaults remain idempotent and include the documented ready-status behavior without overwriting user-edited Runtime Contract files.
  - [x] Existing tracker fetch and normalization tests continue to pass after the contract extension.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Runtime Settings include a dedicated Symphony-ready Status field available to tracker adapters.
- The selected Issue Tracker boundary exposes first-admission decisions without moving tracker semantics into Orchestrator.
