---
status: completed
title: "Use reconciled lifecycle state in the Compozy tracker adapter"
type: backend
complexity: medium
dependencies:
  - task_01

---

# Task 02: Use reconciled lifecycle state in the Compozy tracker adapter

## Overview
Align the Compozy-backed Local Issue Tracker with the reconciled lifecycle contract so tracker issue state reflects the same run summary operators see elsewhere. This task keeps dispatch-state routing config-driven while ensuring tracker candidate fetches, lookups, and status persistence all flow through the reconciled lifecycle path.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST load Compozy tracker candidates and lookups through reconciled lifecycle metadata from task_01.
- R2 MUST keep the Compozy tracker issue boundary at one Compozy PRD Run per issue.
- R3 MUST expose `dispatch_state` as the tracker issue state without collapsing it into lifecycle or task-step labels.
- R4 MUST recover from corrupt or unreadable lifecycle JSON by rebuilding from task-step truth instead of failing the whole tracker poll.
- R5 MUST persist explicit tracker status updates back into lifecycle `dispatch_state` without changing task-step progress semantics.
- R6 MUST preserve Compozy tracker behavior without adding GitHub API dependencies.
</requirements>

## Subtasks
- [x] 2.1 Route Compozy candidate fetches and identifier lookups through the reconciled lifecycle loader.
- [x] 2.2 Preserve Compozy issue-state mapping from lifecycle `dispatch_state`.
- [x] 2.3 Keep corrupt-lifecycle fallback behavior narrow and task-step-derived.
- [x] 2.4 Ensure Compozy status updates persist dispatch-state changes back into lifecycle metadata only.
- [x] 2.5 Add focused tracker adapter tests for fetch, lookup, update, and lifecycle repair paths.

## Implementation Details
Reference TechSpec "System Architecture" component overview for `Issue_tracker.compozy` and TechSpec "Impact Analysis" for tracker adapter behavior. Keep this task scoped to `issue_tracker.ml` and the related backend tests; do not widen it into orchestrator transition work.

### Relevant Files
- `apps/backend/lib/issue_tracker.ml` — Implements the Compozy tracker adapter, candidate fetches, identifier normalization, and status persistence.
- `apps/backend/lib/compozy_lifecycle.ml` — Supplies reconciled lifecycle metadata and dispatch-state persistence helpers.
- `apps/backend/lib/compozy_tasks_tracker.ml` — Supplies PRD run discovery and runnable-run filtering for tracker candidates.
- `apps/backend/test/test_backend.ml` — Contains existing Compozy tracker fetch, lookup, and status-update tests to extend.

### Dependent Files
- `apps/backend/lib/orchestrator.ml` — Relies on tracker issues having the correct dispatch-facing state for routing.
- `apps/backend/lib/runtime_state.ml` — Later tasks will confirm surfaces tell the same story as the tracker adapter.
- `README.md` — Documentation should reflect the eventual tracker-state behavior.

### Related ADRs
- [ADR-001: Represent Compozy lifecycle at PRD Run level](adrs/adr-001.md) — Keeps the Compozy PRD Run as the issue-level unit.
- [ADR-003: Persist dispatch-aware Compozy lifecycle in Runtime Home](adrs/adr-003.md) — Defines dispatch-aware lifecycle persistence as the tracker state source.
- [ADR-006: Reconcile Compozy lifecycle from task-step progress while keeping readiness separate](adrs/adr-006.md) — Requires tracker reads to consume reconciled lifecycle metadata.

## Deliverables
- Compozy tracker adapter reads reconciled lifecycle metadata for fetches and lookups.
- Compozy tracker adapter persists `dispatch_state` updates without altering task-step progress semantics.
- Backend tests cover corrupt lifecycle repair, dispatch-state issue mapping, and status-update persistence.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for Compozy tracker lifecycle-backed state behavior **(REQUIRED)**

## Tests
- Unit tests:
  - [x] Candidate fetch maps each runnable Compozy PRD Run to a tracker issue using lifecycle `dispatch_state`.
  - [x] Identifier lookup returns the Compozy PRD Run issue and preserves the canonical `compozy:<slug>` identifier.
  - [x] Corrupt lifecycle JSON falls back to task-step-based backfill instead of failing the tracker adapter.
  - [x] `update_status` persists only lifecycle `dispatch_state` changes for a Compozy PRD Run.
- Integration tests:
  - [x] Compozy tracker active and terminal checks continue to use dispatch-facing status semantics after lifecycle reconciliation.
  - [x] Queue or lookup flows consume repaired lifecycle metadata when a Runtime Home lifecycle file is stale or corrupt.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- The Compozy tracker adapter uses the same reconciled lifecycle state that downstream Runtime State and UI surfaces consume.
- Tracker dispatch-state behavior remains config-driven without breaking the Compozy PRD Run issue boundary.
