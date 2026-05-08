---
status: pending
title: "Implement minibeads issue fetch, lookup, blockers, and status updates"
type: backend
complexity: high
dependencies:
  - task_03
---

# Task 04: Implement minibeads issue fetch, lookup, blockers, and status updates

## Overview
Implement the minibeads adapter operations that map `mb` CLI output into Symphony `Issue.t` values and write status transitions through `mb`. This provides the local tracker behavior required before orchestration can dispatch minibeads issues.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST fetch active candidate Local Issue Files through `mb`.
- R2 MUST look up issues by canonical `mb-<number>` identifier.
- R3 MUST map title, description, state, priority, labels, blockers, and timestamps into `Issue.t` when available.
- R4 MUST leave `Issue.comments` empty for minibeads V1.
- R5 MUST prevent dispatch of issues blocked by non-terminal dependencies.
- R6 MUST update local status through `mb` and treat repeated transitions as idempotent success.
</requirements>

## Subtasks
- [ ] 4.1 Map valid minibeads issue output into `Issue.t`.
- [ ] 4.2 Implement issue lookup by canonical local identifier.
- [ ] 4.3 Implement blocker and non-dispatchable issue handling.
- [ ] 4.4 Implement status updates through `mb`.
- [ ] 4.5 Add malformed, duplicate, blocked, and idempotent update tests.

## Implementation Details
Follow TechSpec "Data Models" and "Integration Points: minibeads CLI". Prefer machine-readable `mb` output when available. Do not add local comments/notes behavior in V1.

### Relevant Files
- `apps/backend/lib/minibeads_tracker.ml` — Core minibeads fetch, lookup, mapping, blocker, and status behavior.
- `apps/backend/lib/issue.ml` — Target issue model for mapped local issues.
- `apps/backend/lib/issue_tracker.ml` — Adapter contract implemented by minibeads.
- `apps/backend/test/test_backend.ml` — Tests for mapping, blockers, malformed output, and status updates.

### Dependent Files
- `apps/backend/lib/orchestrator.ml` — Uses adapter fetch/status behavior in task_05.
- `apps/backend/lib/ordered_queue.ml` — Uses lookup behavior in task_06.
- `apps/backend/lib/manual_merge.ml` — Uses lookup/status behavior in task_07.

### Related ADRs
- [ADR-004: Use the mb CLI as the minibeads integration boundary](adrs/adr-004.md) — Defines CLI reads/writes and comments exclusion.
- [ADR-006: Constrain V1 local identifiers and dashboard impact](adrs/adr-006.md) — Defines accepted identifier shape.

## Deliverables
- minibeads candidate fetch and lookup operations.
- minibeads blocker mapping and non-dispatchable diagnostics.
- minibeads status update operation.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for local issue mapping and status transitions **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Valid active `mb-20` output maps to `Issue.t` with identifier, title, state, description, labels, priority, and timestamps.
  - [ ] minibeads comments are empty in V1 even when issue body exists.
  - [ ] Duplicate minibeads identifiers produce deterministic diagnostics.
  - [ ] Unsupported minibeads status makes the issue non-dispatchable.
  - [ ] Non-terminal blocker prevents candidate dispatch.
  - [ ] Repeating the same status update is treated as idempotent success.
- Integration tests:
  - [ ] Fake `mb` command runner supports fetch, lookup, and status update through the Issue Tracker boundary.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- A valid local issue can be fetched, looked up, blocked, and status-updated through the selected tracker.
