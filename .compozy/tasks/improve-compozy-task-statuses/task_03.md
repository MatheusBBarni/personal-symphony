---
status: pending
title: "Wire Compozy tracker dispatch-aware lifecycle state"
type: backend
complexity: high
dependencies:
  - task_01
  - task_02
---

# Task 03: Wire Compozy tracker dispatch-aware lifecycle state

## Overview
Update the Compozy-backed Local Issue Tracker so Compozy PRD Run candidates use lifecycle metadata for run-level dispatch state. This replaces the current no-op status update boundary while keeping Compozy Task Step files as ordered progress inside one work item.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST load or lazy-backfill lifecycle metadata when the Compozy tracker discovers PRD Runs.
- R2 MUST map Compozy PRD Run issue state from lifecycle dispatch state when metadata is available.
- R3 MUST persist status updates for Compozy PRD Runs through lifecycle metadata instead of treating `update_status` as a no-op.
- R4 MUST preserve one Compozy PRD Run as one Issue Tracker work item and must not expose Compozy Task Steps as separate issues.
- R5 MUST keep the Compozy-backed Local Issue Tracker free from GitHub API requirements.
- R6 SHOULD keep active and terminal checks compatible with existing configured tracker statuses and lifecycle dispatch state.
</requirements>

## Subtasks
- [ ] 3.1 Load or backfill lifecycle metadata during Compozy candidate discovery.
- [ ] 3.2 Return Compozy PRD Run issues with dispatch-aware state.
- [ ] 3.3 Persist Compozy tracker `update_status` calls into lifecycle metadata.
- [ ] 3.4 Keep lookup diagnostics and identifier normalization unchanged.
- [ ] 3.5 Add focused tracker tests for discovery, lookup, active/terminal behavior, and status updates.

## Implementation Details
Follow TechSpec "Data Flow" steps for discovery and tracker updates. Keep `Compozy_tasks_tracker` responsible for task-step parsing and prompt context, while `Issue_tracker.compozy` applies lifecycle metadata at the PRD Run boundary.

### Relevant Files
- `apps/backend/lib/issue_tracker.ml` — Compozy adapter fetch, lookup, status update, active, and terminal behavior.
- `apps/backend/lib/compozy_lifecycle.ml` — Lifecycle load, backfill, save, and transition helpers used by the adapter.
- `apps/backend/lib/compozy_tasks_tracker.ml` — Source of discovered PRD Runs and canonical Compozy identifiers.
- `apps/backend/test/test_backend.ml` — Existing Compozy adapter and tracker-selection tests.

### Dependent Files
- `apps/backend/lib/orchestrator.ml` — Calls tracker status updates and dispatch filters through `Issue_tracker.t`.
- `apps/backend/lib/ordered_queue.ml` — Uses tracker lookup and active/terminal state for Compozy queue validation.
- `apps/backend/lib/manual_merge.ml` — Uses selected tracker lookup and terminal semantics for manual merge flows.
- `apps/backend/lib/runtime_state.ml` — Displays the selected lifecycle-enriched PRD Run progress.

### Related ADRs
- [ADR-001: Represent Compozy lifecycle at PRD Run level](adrs/adr-001.md) — Prevents treating task steps as separate issues.
- [ADR-003: Persist dispatch-aware Compozy lifecycle in Runtime Home](adrs/adr-003.md) — Requires status updates to persist at the Runtime Home lifecycle boundary.

## Deliverables
- Compozy tracker discovery that backfills lifecycle metadata for PRD Runs.
- Compozy tracker issue states derived from lifecycle dispatch state when present.
- Non-no-op Compozy tracker status persistence through lifecycle metadata.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for Compozy tracker lifecycle discovery and updates **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Fetching a runnable Compozy PRD Run with no lifecycle file backfills metadata and returns one issue candidate.
  - [ ] Fetching a Compozy PRD Run with lifecycle dispatch state returns an issue whose state matches that dispatch state.
  - [ ] `update_status` on `compozy:example-feature` persists the requested dispatch state into lifecycle metadata.
  - [ ] Lookup for `compozy:example-feature` still returns one Compozy PRD Run issue and never task-step issues.
  - [ ] Active and terminal checks honor lifecycle dispatch state alongside configured Compozy tracker states.
- Integration tests:
  - [ ] Ordered Queue validation resolves a Compozy PRD Run through the lifecycle-aware tracker without GitHub Project membership.
  - [ ] Manual merge lookup still accepts completed Compozy PRD Runs after lifecycle metadata exists.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Compozy tracker status updates are durable and visible at the Compozy PRD Run level.
- Compozy Task Step progress remains internal ordered progress, not separate Issue Tracker work.
