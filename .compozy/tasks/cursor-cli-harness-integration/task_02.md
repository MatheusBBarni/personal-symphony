---
status: completed
title: "Add Cursor CLI Install And Auth Readiness Checks"
type: backend
complexity: high
dependencies:
  - task_01

---

# Task 02: Add Cursor CLI Install And Auth Readiness Checks

## Overview
This task gives Cursor the same class of pre-dispatch confidence checks that Symphony already provides for selected
Claude and PI Harnesses. It ensures Cursor-selected roles fail fast on missing install or missing auth state, using
the Cursor CLI itself as the primary readiness signal rather than a generic command-only approximation.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
1. MUST validate Cursor executable availability only for selected Cursor Harnesses.
2. MUST use the Cursor CLI itself as the primary authentication or status readiness signal for selected Cursor Harnesses.
3. MUST surface deterministic readiness gaps with Cursor-specific remediation when install or auth is missing.
4. MUST avoid blocking dispatch when a Cursor Harness is configured but not selected by any active stage.
5. MUST keep provider secrets out of Runtime Settings and examples while still allowing operator setup guidance through readiness remediation.
</requirements>

## Subtasks
- [x] 2.1 Add selected-only Cursor install readiness checks beside existing provider readiness logic.
- [x] 2.2 Add Cursor-CLI-driven auth or status probing for selected Cursor Harnesses.
- [x] 2.3 Normalize Cursor readiness requirements and remediation text for runtime display.
- [x] 2.4 Ensure unselected Cursor Harness definitions do not create install or auth blockers.
- [x] 2.5 Add targeted readiness tests for success, failure, and ignored-unselected cases.

## Implementation Details
Extend selected-Harness readiness in the same shared module used for Claude and PI. See TechSpec "Integration Points",
"Testing Approach", and "Known Risks" for the approved boundary: Cursor readiness belongs in `Config`, should trust the
Cursor CLI as the source of truth, and must remain selected-Harness-only.

### Relevant Files
- `apps/backend/lib/config.ml` — owns executable discovery, provider auth checks, and readiness-gap construction.
- `apps/backend/test/test_backend.ml` — already contains selected-only Claude and PI readiness tests to mirror for Cursor.
- `apps/backend/lib/issue_tracker.ml` — projects config readiness gaps into runtime-facing readiness state and should remain compatible with new Cursor requirements.

### Dependent Files
- `apps/backend/lib/orchestrator.ml` — dispatch behavior depends on readiness blocking invalid Cursor runs before launch.
- `apps/backend/lib/runtime_state.ml` — runtime readiness display depends on stable requirement names and remediation text.
- `apps/backend/lib/terminal_console_model.ml` — readiness surfaces should show new Cursor requirements cleanly once emitted.

### Related ADRs
- [ADR-001: Cursor Harness As A Bounded Multi-Harness Extension](adrs/adr-001.md) — Requires selected-Harness readiness and install checks.
- [ADR-003: Native Cursor Harness Technical Design](adrs/adr-003.md) — Chooses native provider logic inside existing readiness seams.
- [ADR-004: Cursor Output, Readiness, And Loop Contract](adrs/adr-004.md) — Requires Cursor-CLI-driven auth readiness rather than env/file-only heuristics.

## Deliverables
- Selected-only Cursor install readiness behavior.
- Cursor-CLI-driven auth/status readiness behavior with clear remediation.
- Stable runtime requirement naming for Cursor install and auth failures.
- Backend readiness tests covering selected and unselected Cursor Harness scenarios.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for runtime readiness projection with Cursor-selected stages **(REQUIRED)**

## Tests
- Unit tests:
  - [x] A selected Cursor Harness with a missing executable produces a Cursor install readiness gap.
  - [x] A selected Cursor Harness with install present but missing CLI auth/state produces a Cursor auth readiness gap.
  - [x] A selected Cursor Harness with successful CLI auth/status check produces no Cursor auth gap.
  - [x] An unselected Cursor Harness does not produce install or auth gaps.
  - [x] Existing Claude and PI readiness behavior remains unchanged.
- Integration tests:
  - [x] Runtime readiness state includes the expected Cursor install requirement when a selected Cursor command is unavailable.
  - [x] Runtime readiness state includes the expected Cursor auth requirement when a selected Cursor CLI status probe fails.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Cursor-selected roles fail fast on missing install or auth before dispatch.
- Unselected Cursor Harness definitions do not block unrelated workflows.
