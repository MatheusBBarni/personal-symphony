---
status: completed
title: "Align Runtime State and Terminal Console with the shared Compozy status contract"
type: backend
complexity: medium
dependencies:
  - task_01

---

# Task 04: Align Runtime State and Terminal Console with the shared Compozy status contract

## Overview
Make Runtime State and the Terminal Console tell the same Compozy PRD Run story from one shared payload. This task keeps task-step truth intact while ensuring lifecycle, dispatch, readiness, handoff, and reason fields are merged and rendered consistently for backend-facing operator surfaces.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST keep `Runtime_state.compozy_progress` as the single shared payload for Compozy PRD Run status.
- R2 MUST preserve Compozy Task Step truth for `current_step`, `completed`, `failed`, `skipped`, and `total` when lifecycle metadata is merged.
- R3 MUST expose `lifecycle_state`, `dispatch_state`, `stage_agent`, `pr_readiness`, `reason`, and `handoff_status` from reconciled lifecycle metadata when present.
- R4 MUST preserve backward compatibility when older Runtime State snapshots omit lifecycle fields.
- R5 MUST keep Terminal Console rendering aligned with the shared payload and omit empty optional lifecycle fields cleanly.
- R6 MUST expose the same reconciled payload through HTTP and live Runtime State snapshots.
</requirements>

## Subtasks
- [ ] 4.1 Audit `Runtime_state.compozy_progress` assembly against the approved merged-state contract.
- [ ] 4.2 Preserve task-step truth for counts and current-step selection while attaching reconciled lifecycle metadata.
- [ ] 4.3 Keep JSON serialization and parsing backward-compatible for older snapshots.
- [ ] 4.4 Align Terminal Console Compozy progress lines with the shared payload fields and omission rules.
- [ ] 4.5 Add backend tests for payload merge behavior, snapshot compatibility, terminal rendering, and Runtime State exposure.

## Implementation Details
Reference TechSpec "Core Interfaces", "Shared Runtime State payload", and "API Endpoints". Keep this task limited to backend payload assembly and Terminal Console rendering; frontend parsing and markup belong to task_05.

### Relevant Files
- `apps/backend/lib/runtime_state.ml` — Defines `compozy_progress`, JSON serialization/parsing, and payload assembly from task-step and lifecycle data.
- `apps/backend/lib/terminal_console.ml` — Renders lifecycle, dispatch state, readiness, handoff, reason, and step-count lines.
- `apps/backend/test/test_backend.ml` — Contains existing Runtime State merge, HTTP payload, live snapshot, and terminal line tests to extend.

### Dependent Files
- `apps/frontend/src/RuntimeStateSnapshot.res` — Consumes the payload this task finalizes.
- `apps/frontend/src/Pages/Dashboard.res` — Renders the lifecycle and readiness fields exposed here.
- `README.md` — Documentation should describe the final payload semantics operators will see.

### Related ADRs
- [ADR-003: Persist dispatch-aware Compozy lifecycle in Runtime Home](adrs/adr-003.md) — Defines Runtime Home lifecycle as the metadata source for the shared payload.
- [ADR-005: Use a cross-surface transition contract as the PRD approach](adrs/adr-005.md) — Requires the same story across Runtime State and the Terminal Console.
- [ADR-006: Reconcile Compozy lifecycle from task-step progress while keeping readiness separate](adrs/adr-006.md) — Requires merged payload semantics that preserve task-step truth.

## Deliverables
- Shared backend `compozy_progress` payload assembled from task-step truth plus reconciled lifecycle metadata.
- Backward-compatible Runtime State snapshot serialization and parsing for lifecycle-rich and legacy snapshots.
- Terminal Console rendering aligned with the same payload semantics.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for Runtime State and Terminal Console consistency **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] `compozy_progress_of_prd_run` preserves task-step counts and current-step selection when lifecycle metadata is present.
  - [ ] `handoff_status` is derived correctly from lifecycle readiness values.
  - [ ] Legacy Runtime State snapshots without lifecycle fields continue to parse successfully.
  - [ ] Terminal Console lifecycle lines omit absent optional values and include present ones in the expected order.
- Integration tests:
  - [ ] HTTP state payload includes reconciled `compozy_progress` lifecycle, readiness, reason, and handoff fields when present.
  - [ ] Live Runtime State snapshots carry the same Compozy payload semantics as HTTP and terminal rendering.
  - [ ] Backend-facing operator surfaces do not contradict task-step counts when lifecycle metadata is stale or repaired.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Runtime State and Terminal Console expose the same Compozy PRD Run contract from one payload.
- Task-step counts and current-step selection remain unchanged in meaning while lifecycle and readiness fields become trustworthy.
