---
status: completed
title: "Extend Runtime State Compozy progress lifecycle fields"
type: backend
complexity: medium
dependencies:
  - task_01
---

# Task 02: Extend Runtime State Compozy progress lifecycle fields

## Overview
Extend the Runtime State `compozy_progress` payload so operator surfaces can read lifecycle and PR readiness from one structured place. The existing Compozy Task Step progress fields must remain stable and older snapshots without lifecycle fields must continue to parse.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST add optional lifecycle, dispatch, Stage Agent, PR readiness, reason, and handoff summary fields to `Runtime_state.compozy_progress`.
- R2 MUST preserve existing `run_id`, `slug`, `current_step`, `completed`, `failed`, `skipped`, and `total` semantics.
- R3 MUST serialize extended fields in `Runtime_state.to_yojson` only as compatible JSON values.
- R4 MUST parse older Runtime State snapshots that lack lifecycle fields without error.
- R5 MUST combine Compozy Task Step progress with lifecycle metadata from task_01 when lifecycle metadata exists.
- R6 SHOULD keep absence of lifecycle metadata representable as optional absence rather than synthesized frontend-only text.
</requirements>

## Subtasks
- [x] 2.1 Extend the backend Compozy progress record shape.
- [x] 2.2 Add lifecycle-aware progress construction from a Compozy PRD Run and lifecycle metadata.
- [x] 2.3 Preserve old snapshot parsing for absent lifecycle fields.
- [x] 2.4 Extend JSON output tests for the new optional fields.
- [x] 2.5 Extend compatibility tests for old snapshots and absent Compozy progress.

## Implementation Details
Follow TechSpec sections "Extended `Runtime_state.compozy_progress`" and "API Endpoints". No new HTTP endpoint is required; this task only changes the Runtime State payload shape and backend parsing helpers.

### Relevant Files
- `apps/backend/lib/runtime_state.ml` — Owns the `compozy_progress` record, JSON serialization, snapshot parsing, and initial progress selection.
- `apps/backend/lib/compozy_lifecycle.ml` — Provides lifecycle metadata to merge into Runtime State progress.
- `apps/backend/lib/compozy_tasks_tracker.ml` — Continues to provide step counts and current-step data.
- `apps/backend/test/test_backend.ml` — Contains existing Runtime State Compozy progress and old-snapshot compatibility tests.

### Dependent Files
- `apps/backend/lib/server.ml` — Serves the extended Runtime State payload through existing HTTP and live state paths.
- `apps/backend/bin/main.ml` — Terminal Console rendering will consume the extended fields in task_06.
- `apps/frontend/src/RuntimeStateSnapshot.res` — Frontend parsing will consume the extended fields in task_07.

### Related ADRs
- [ADR-001: Represent Compozy lifecycle at PRD Run level](adrs/adr-001.md) — Keeps task-step progress separate from lifecycle state.
- [ADR-003: Persist dispatch-aware Compozy lifecycle in Runtime Home](adrs/adr-003.md) — Requires extending `compozy_progress` instead of adding a separate top-level Runtime State object.

## Deliverables
- Extended `Runtime_state.compozy_progress` backend model and JSON contract.
- Lifecycle-aware progress construction that preserves Compozy Task Step counts.
- Backward-compatible snapshot parsing for older Runtime State payloads.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for Runtime State JSON compatibility **(REQUIRED)**

## Tests
- Unit tests:
  - [x] `Runtime_state.compozy_progress_of_prd_run` still reports current step and completed/failed/skipped/total counts unchanged.
  - [x] Lifecycle metadata adds `lifecycle_state`, `dispatch_state`, `stage_agent`, `pr_readiness`, `reason`, and `handoff_status` when present.
  - [x] Missing lifecycle metadata leaves optional fields absent or null without changing count fields.
  - [x] Older snapshots without lifecycle fields parse successfully.
  - [x] Snapshot parsing preserves lifecycle fields when the extended payload is present.
- Integration tests:
  - [x] A Runtime State JSON payload containing extended `compozy_progress` can round-trip through backend snapshot helpers.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Runtime State exposes lifecycle information without breaking existing Compozy progress consumers.
- Older Runtime State snapshots remain compatible.
