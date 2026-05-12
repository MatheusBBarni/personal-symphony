---
status: pending
title: "Mirror Batch Pull Request readiness into lifecycle"
type: backend
complexity: medium
dependencies:
  - task_04
---

# Task 05: Mirror Batch Pull Request readiness into lifecycle

## Overview
Connect Compozy PRD Run lifecycle metadata to Pull Request Policy and Batch Pull Request handoff outcomes. This ensures completed runs are not confused with PR-ready runs and keeps aggregate Batch Pull Request behavior visible without changing existing PR defaults.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST mark completed Compozy PRD Runs as PR-ready only after successful run completion and safe final integration.
- R2 MUST mark failed, skipped, blocked, attention, and stopped Compozy PRD Runs as not PR-ready with a concise reason.
- R3 MUST represent disabled Pull Request Policy as disabled readiness without enabling automatic PR creation.
- R4 MUST mirror Batch Pull Request handoff attempting, completed, and failed outcomes into lifecycle readiness fields.
- R5 MUST preserve batch-mode semantics: no per-step pull requests and at most one aggregate Batch Pull Request per eligible Compozy PRD Run.
- R6 MUST preserve Protected Trunk Branch, Task Branch Integration, Stage Push, and non-force push safeguards.
</requirements>

## Subtasks
- [ ] 5.1 Add PR readiness outcomes for completed, failed, skipped, blocked, and policy-disabled Compozy PRD Runs.
- [ ] 5.2 Record readiness after safe final Task Branch Integration.
- [ ] 5.3 Mirror Batch Pull Request handoff attempting, completed, and retryable failure states.
- [ ] 5.4 Preserve aggregate-only Batch Pull Request behavior in Compozy batch mode.
- [ ] 5.5 Add focused tests for policy-disabled, ready, not-ready, handoff success, handoff failure, and no per-step PR behavior.

## Implementation Details
Follow TechSpec sections "Aggregate Batch Pull Request readiness", "Data Models", and "Technical Considerations". Use existing `pull_request` and `pull_requests` Runtime State records for detailed handoff data, and store only the run-level readiness summary in lifecycle metadata.

### Relevant Files
- `apps/backend/lib/orchestrator.ml` — Owns Batch Pull Request attempt, handoff recording, idle detection, and Task Branch Integration outcomes.
- `apps/backend/lib/compozy_lifecycle.ml` — Provides readiness and handoff transition helpers.
- `apps/backend/lib/runtime_state.ml` — Exposes readiness and handoff summary in `compozy_progress`.
- `apps/backend/lib/config.ml` — Defines Pull Request Policy defaults and mode fields that must remain unchanged.
- `apps/backend/test/test_backend.ml` — Existing Batch Pull Request, task-mode PR, handoff retry, and attention-blocking tests.

### Dependent Files
- `apps/backend/bin/main.ml` — Will render readiness and handoff states in task_06.
- `apps/frontend/src/Pages/Dashboard.res` — Will render readiness and handoff states in task_07.
- `README.md` — Will document aggregate readiness behavior in task_08.

### Related ADRs
- [ADR-001: Represent Compozy lifecycle at PRD Run level](adrs/adr-001.md) — Requires aggregate Batch Pull Request eligibility only after successful run completion.
- [ADR-002: Use full V1 operator trust as the PRD product approach](adrs/adr-002.md) — Requires a distinct not-PR-ready reason and all-surface readiness visibility.
- [ADR-003: Persist dispatch-aware Compozy lifecycle in Runtime Home](adrs/adr-003.md) — Requires mirroring PR readiness into lifecycle metadata.

## Deliverables
- Lifecycle PR readiness mapping for ready, disabled, not-ready, handoff attempting, handoff completed, and handoff failed states.
- Operator-facing not-PR-ready reasons for failed, skipped, blocked, attention, policy-disabled, and handoff-failure outcomes.
- Tests proving Compozy batch mode remains aggregate-only and non-force.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for Batch Pull Request readiness and handoff mirroring **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Completed Compozy PRD Run with automatic batch PR disabled records `pr_readiness = disabled` and no handoff attempt.
  - [ ] Completed Compozy PRD Run with automatic batch PR enabled records `pr_readiness = ready` before handoff and handoff status during PR creation.
  - [ ] Failed, skipped, blocked, and attention Compozy PRD Runs record `pr_readiness = not_ready` with a concise reason.
  - [ ] Batch Pull Request handoff success records completed handoff readiness without duplicating detailed PR record fields.
  - [ ] Batch Pull Request handoff failure records failed handoff readiness with the handoff error reason.
- Integration tests:
  - [ ] Batch mode opens no per-step pull requests while Compozy Task Steps advance within one Compozy PRD Run.
  - [ ] Eligible Compozy PRD Run opens no more than one aggregate Batch Pull Request.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Terminal or stopped Compozy PRD Runs never silently appear PR-ready without readiness metadata.
- Existing Pull Request Policy defaults and Protected Trunk Branch safeguards remain unchanged.
