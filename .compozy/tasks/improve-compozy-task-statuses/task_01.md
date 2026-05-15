---
status: completed
title: "Reconcile Compozy lifecycle metadata from task-step truth"
type: backend
complexity: medium
dependencies: []


---

# Task 01: Reconcile Compozy lifecycle metadata from task-step truth

## Overview
Tighten the Runtime Home lifecycle layer so it remains a reconciled run-level summary rather than an independent source of truth. This task keeps Compozy Task Step progress authoritative for current-step selection and terminal counts while ensuring persisted lifecycle metadata is backfilled and downgraded correctly when task-step truth changes.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST preserve `Compozy_tasks_tracker` as the authoritative source for `current_step`, `completed`, `failed`, `skipped`, and `total`.
- R2 MUST make `Compozy_lifecycle.load_or_backfill_reconciled` the canonical lifecycle read path for Runtime Home lifecycle consumption.
- R3 MUST backfill missing lifecycle metadata from current Compozy Task Step truth without rewriting task-step statuses.
- R4 MUST downgrade stale lifecycle metadata when task-step truth shows failed, skipped, blocked, or other non-ready terminal outcomes.
- R5 MUST preserve lifecycle schema compatibility for version `1` metadata already stored under Runtime Home.
- R6 MUST keep Batch Pull Request handoff modeled as lifecycle phase `pr_handoff` with readiness and handoff outcome represented separately.
</requirements>

## Subtasks
- [x] 1.1 Audit lifecycle derive, backfill, and reconciliation helpers against the approved task-step-truth contract.
- [x] 1.2 Tighten lifecycle downgrade behavior for stale `completed`, `ready`, and other non-matching terminal metadata.
- [x] 1.3 Preserve existing lifecycle JSON schema and compatibility handling for optional fields.
- [x] 1.4 Keep handoff and readiness semantics separate from lifecycle phase semantics.
- [x] 1.5 Add focused backend tests for backfill, reconciliation, and terminal downgrade cases.

## Implementation Details
Reference TechSpec "Data Models" sections 1 through 4 and ADR-006. Keep this task centered on `Compozy_lifecycle` and any narrowly scoped helper usage needed to reconcile Runtime Home metadata from Compozy Task Step truth.

### Relevant Files
- `apps/backend/lib/compozy_lifecycle.ml` — Owns derive, backfill, reconciliation, lifecycle transition helpers, and Runtime Home persistence.
- `apps/backend/lib/compozy_tasks_tracker.ml` — Defines current-step selection and terminal counts that lifecycle must respect.
- `apps/backend/test/test_backend.ml` — Already contains lifecycle backfill, reconciliation, and JSON compatibility tests to extend.

### Dependent Files
- `apps/backend/lib/issue_tracker.ml` — Later tasks rely on reconciled lifecycle reads for tracker issue state.
- `apps/backend/lib/runtime_state.ml` — Merges task-step truth with reconciled lifecycle metadata for operator surfaces.
- `apps/backend/lib/orchestrator.ml` — Transition helpers used during dispatch, retry, completion, blocked attention, and handoff depend on this contract.

### Related ADRs
- [ADR-003: Persist dispatch-aware Compozy lifecycle in Runtime Home](adrs/adr-003.md) — Defines Runtime Home as the lifecycle persistence boundary.
- [ADR-004: Treat Compozy statuses as an explicit transition contract](adrs/adr-004.md) — Requires explicit mapping and transition correctness across status layers.
- [ADR-006: Reconcile Compozy lifecycle from task-step progress while keeping readiness separate](adrs/adr-006.md) — Requires task-step truth to win over stale lifecycle metadata.

## Deliverables
- Reconciled lifecycle read path that backfills missing metadata and repairs stale terminal metadata.
- Preserved lifecycle JSON compatibility for existing Runtime Home state files.
- Backend regression tests for active, completed, failed, skipped, blocked, and handoff-related lifecycle reconciliation.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for Runtime Home lifecycle reconciliation behavior **(REQUIRED)**

## Tests
- Unit tests:
  - [x] Lifecycle JSON round-trip preserves version `1` schema and optional fields.
  - [x] Missing lifecycle metadata backfills from active task-step progress as `in_execution` and `not_ready`.
  - [x] Missing lifecycle metadata backfills from completed task-step progress as `completed` with the expected readiness policy.
  - [x] Stale `completed` or `ready` metadata is downgraded when task-step truth becomes `failed`, `skipped`, `blocked`, or `not_pr_ready`.
  - [x] Handoff-related metadata keeps `pr_handoff` as the lifecycle phase while readiness remains `handoff_attempting`, `handoff_completed`, or `handoff_failed`.
- Integration tests:
  - [x] Runtime lifecycle load for a discovered Compozy PRD Run returns reconciled metadata after a task-step truth change.
  - [x] Corrupt or stale lifecycle metadata is repaired from task-step truth without changing Compozy Task Step files.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Runtime Home lifecycle metadata never overrides Compozy Task Step truth for current-step or terminal-count semantics.
- Non-ready terminal task-step truth visibly downgrades stale lifecycle metadata before downstream surfaces consume it.
