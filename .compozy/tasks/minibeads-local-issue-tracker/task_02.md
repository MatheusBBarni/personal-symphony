---
status: pending
title: "Introduce shared Issue Tracker boundary and GitHub adapter"
type: backend
complexity: high
dependencies:
  - task_01
---

# Task 02: Introduce shared Issue Tracker boundary and GitHub adapter

## Overview
Introduce the shared `Issue_tracker` contract that later tasks will use for GitHub and minibeads behavior. Wrap existing GitHub tracker behavior behind this boundary without rewriting the GraphQL parsing or status update logic.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST add an `Issue_tracker` boundary matching the TechSpec "Core Interfaces" section.
- R2 MUST keep `Github_tracker` behavior thinly wrapped rather than reimplemented.
- R3 MUST preserve GitHub active-state and terminal-state semantics.
- R4 MUST preserve GitHub rate-limit behavior through a generic tracker poll error.
- R5 MUST preserve issue lookup diagnostics needed by Ordered Queue and Manual Task Merge.
</requirements>

## Subtasks
- [ ] 2.1 Add the shared tracker boundary type and selected-adapter constructor.
- [ ] 2.2 Add a GitHub adapter over existing `Github_tracker` functions.
- [ ] 2.3 Translate GitHub tracker errors into generic tracker errors.
- [ ] 2.4 Preserve status and identifier normalization behavior for GitHub.
- [ ] 2.5 Add focused tests for adapter selection and GitHub behavior preservation.

## Implementation Details
Follow TechSpec "Core Interfaces" and "Component Overview". This task should not yet refactor every caller; it creates the boundary and proves GitHub behavior remains available through it.

### Relevant Files
- `apps/backend/lib/github_tracker.ml` — Existing concrete GitHub behavior to wrap.
- `apps/backend/lib/issue.ml` — Common issue shape used by the shared boundary.
- `apps/backend/lib/config.ml` — Provides selected tracker configuration from task_01.
- `apps/backend/lib/dune` — Wrapped false library; adding `issue_tracker.ml` should be sufficient.
- `apps/backend/test/test_backend.ml` — Contains GitHub tracker and rate-limit tests to preserve.

### Dependent Files
- `apps/backend/lib/orchestrator.ml` — Later task will replace direct `Github_tracker.t` usage.
- `apps/backend/lib/ordered_queue.ml` — Later task will validate identifiers through the boundary.
- `apps/backend/lib/manual_merge.ml` — Later task will resolve issues through the boundary.
- `apps/backend/bin/main.ml` — Later task will construct and pass the selected tracker.

### Related ADRs
- [ADR-003: Introduce a shared Issue Tracker boundary](adrs/adr-003.md) — Primary architecture decision.
- [ADR-006: Constrain V1 local identifiers and dashboard impact](adrs/adr-006.md) — Influences identifier normalization.

## Deliverables
- New shared Issue Tracker module.
- GitHub adapter preserving existing GitHub tracker behavior.
- Generic tracker error classification for rate limits and failures.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for GitHub adapter behavior preservation **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Selected tracker constructor returns a GitHub adapter for `tracker.kind = "github"`.
  - [ ] GitHub adapter active-state checks match existing GitHub behavior.
  - [ ] GitHub adapter terminal-state checks match existing GitHub behavior.
  - [ ] GitHub rate-limit exception maps to the generic rate-limit poll error with the same retry delay.
  - [ ] GitHub lookup preserves missing issue versus project membership diagnostics.
- Integration tests:
  - [ ] Existing GitHub tracker parsing and status metadata tests continue to pass.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- GitHub behavior is accessible through the shared Issue Tracker boundary.
- No orchestration behavior changes are introduced before task_05.
