---
status: completed
title: "Add Compozy lifecycle storage and backfill"
type: backend
complexity: high
dependencies: []
---

# Task 01: Add Compozy lifecycle storage and backfill

## Overview
Create the backend lifecycle layer that stores Compozy PRD Run status separately from Compozy Task Step frontmatter. This gives later Runtime State, Issue Tracker, and orchestration work a durable source for run-level lifecycle, dispatch state, PR readiness, and concise operator reasons.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST persist versioned Compozy PRD Run lifecycle metadata under Runtime Home `.symphony/state/compozy-lifecycle/`.
- R2 MUST represent the TechSpec lifecycle, dispatch, Stage Agent, PR readiness, reason, and update timestamp fields without storing secrets.
- R3 MUST lazy-backfill missing lifecycle metadata from Compozy Task Step progress using the TechSpec lazy backfill rules.
- R4 MUST reconcile stale lifecycle metadata when Compozy Task Step files show failed, skipped, empty, or not-runnable terminal progress.
- R5 MUST preserve Compozy Task Step frontmatter as the authoritative source for current-step selection and progress counts.
- R6 SHOULD keep transition helper errors in `(value, string) result` form consistent with existing backend modules.
</requirements>

## Subtasks
- [x] 1.1 Add the lifecycle metadata model and persistence boundary.
- [x] 1.2 Add Runtime Home path handling for Compozy lifecycle JSON files.
- [x] 1.3 Add lazy backfill for active, completed, failed, skipped, empty, and not-runnable Compozy PRD Runs.
- [x] 1.4 Add reconciliation for stale completed or ready metadata when task-step state disagrees.
- [x] 1.5 Add transition helper coverage for later dispatch and readiness tasks.
- [x] 1.6 Add focused backend tests for JSON persistence, backfill, and reconciliation.

## Implementation Details
Follow TechSpec sections "Core Interfaces", "Runtime Home lifecycle JSON", and "Lazy backfill rules". Keep lifecycle metadata in ignored Runtime Home state and do not add runtime churn to `.compozy/tasks/<slug>/` task files.

### Relevant Files
- `apps/backend/lib/compozy_lifecycle.ml` — New backend module owning lifecycle data, JSON persistence, backfill, reconciliation, and transition helpers.
- `apps/backend/lib/compozy_tasks_tracker.ml` — Provides `prd_run`, task-step counts, current step, terminal state, and not-runnable reason inputs.
- `apps/backend/lib/runtime_home.ml` — Defines Runtime Home behavior and idempotent runtime-file expectations.
- `apps/backend/lib/util.ml` — Existing file, time, path, and JSON-adjacent utility patterns used by backend modules.
- `apps/backend/test/test_backend.ml` — Existing Alcotest suite where focused Compozy lifecycle cases should be added.

### Dependent Files
- `apps/backend/lib/runtime_state.ml` — Will consume lifecycle metadata in task_02.
- `apps/backend/lib/issue_tracker.ml` — Will load/backfill lifecycle for Compozy tracker candidates in task_03.
- `apps/backend/lib/orchestrator.ml` — Will call lifecycle transition helpers in later tasks.

### Related ADRs
- [ADR-001: Represent Compozy lifecycle at PRD Run level](adrs/adr-001.md) — Requires lifecycle to belong to the Compozy PRD Run, not individual task steps.
- [ADR-003: Persist dispatch-aware Compozy lifecycle in Runtime Home](adrs/adr-003.md) — Defines Runtime Home persistence and dispatch-aware lifecycle metadata.

## Deliverables
- New lifecycle module with versioned JSON read/write behavior.
- Lazy backfill and reconciliation for all TechSpec task-step conditions.
- Transition helpers that later tasks can call without parsing task files directly.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for Runtime Home lifecycle persistence **(REQUIRED)**

## Tests
- Unit tests:
  - [x] Version 1 lifecycle JSON round-trips `run_id`, `slug`, `lifecycle_state`, `dispatch_state`, `stage_agent`, `pr_readiness`, `reason`, and `updated_at`.
  - [x] Metadata with absent optional `stage_agent` and `reason` parses successfully.
  - [x] A PRD Run with a pending or in-progress current step backfills `lifecycle_state = in_execution` and `pr_readiness = not_ready`.
  - [x] A PRD Run with all steps completed backfills completed lifecycle and policy-aware readiness.
  - [x] A PRD Run with failed, skipped, empty, or not-runnable step state backfills a non-ready lifecycle with a concise reason.
  - [x] Stale completed or ready metadata downgrades when Compozy Task Step progress shows failed or skipped terminal state.
- Integration tests:
  - [x] Lifecycle metadata saves to `.symphony/state/compozy-lifecycle/<slug>.json` in a temp Workspace Repository and reloads after process-style reconstruction.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Lifecycle metadata can be persisted and recovered without editing Compozy Task Step files.
- Backfilled lifecycle state matches the TechSpec table for every required task-step condition.
