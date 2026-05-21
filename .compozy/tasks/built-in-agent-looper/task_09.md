---
status: completed
title: "Render Goal Loop state in Terminal Console"
type: backend
complexity: medium
dependencies:
  - task_05
  - task_08

---

# Task 09: Render Goal Loop state in Terminal Console

## Overview
This task makes Goal Loop state visible in the default read-first Terminal Console. Maintainers should be able to inspect goal, state, stop outcome, evidence, budget status, and next action without using a separate command channel.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- REQ-01 MUST render sanitized Goal Loop details from Runtime State in Terminal Console task views.
- REQ-02 MUST show active and terminal outcomes including `goal_met`, `needs_attention`, and `budget_exhausted`.
- REQ-03 MUST keep Terminal Console local aids read-only and non-mutating.
- REQ-04 MUST avoid conflicting with existing Goal Usage and Context Status presentation.
- REQ-05 SHOULD include preview fixture updates when useful.
</requirements>

## Subtasks
- [x] 9.1 Add Goal Loop projection fields to Terminal Console model rows or details.
- [x] 9.2 Sanitize evidence, stop reason, next action, and diagnostics paths.
- [x] 9.3 Render Goal Loop details near Goal Usage and Context Status.
- [x] 9.4 Update preview fixtures if the display needs representative data.
- [x] 9.5 Add projection and rendering tests.

## Implementation Details
Use the TechSpec "Surface Integration" and "Monitoring and Observability" sections. The Terminal Console should read from Runtime State only and must not add commands that mutate Goal Loop state.

### Relevant Files
- `apps/backend/lib/terminal_console_model.ml` — projects Runtime State into console rows and details.
- `apps/backend/bin/terminal_console_tui.ml` — renders Terminal Console panels.
- `apps/backend/bin/terminal_console_preview.ml` — preview data for visual/manual inspection.
- `apps/backend/test/test_backend.ml` — Terminal Console projection and rendering tests.
- `.agents/rules/tui.md` — package rules for terminal UI changes.

### Dependent Files
- `apps/backend/lib/runtime_state.ml` — source of Goal Loop projection from task_05.
- `apps/backend/lib/orchestrator.ml` — source of terminal Goal Loop states from task_08.
- `CONTEXT.md` — defines Terminal Console and Goal Loop semantics.

### Related ADRs
- [ADR-001: Goal Loop Runtime Scope](adrs/adr-001.md) — Requires operator-visible loop state.
- [ADR-003: Stage-Scoped Goal Loop Runtime State](adrs/adr-003.md) — Requires top-level Runtime State projection.

## Deliverables
- Terminal Console projection for Goal Loop state.
- Terminal Console rendering for active and stopped loop states.
- Tests for sanitized display and read-only behavior.
- Unit tests with 80%+ coverage **(REQUIRED)**.
- Integration/rendering tests for Terminal Console output **(REQUIRED)**.

## Tests
- Unit tests:
  - [x] Running loop state appears in the relevant task detail.
  - [x] `goal_met` state shows latest evidence and stop outcome.
  - [x] `needs_attention` state shows stop reason and next action.
  - [x] `budget_exhausted` state shows budget stop reason.
  - [x] Evidence and diagnostics values are sanitized for terminal output.
- Integration tests:
  - [x] Terminal Console fixture snapshot includes Goal Loop detail without layout regressions.
  - [x] Terminal Console local aids remain read-only and do not mutate loop state.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Maintainers can inspect Goal Loop state from the Terminal Console.
- Terminal Console continues to use Runtime State as its source of truth.
