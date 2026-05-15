---
status: pending
title: "Add Cursor Stream-JSON Activity Parsing And Runtime Visibility"
type: backend
complexity: high
dependencies:
  - task_01
  - task_02
---

# Task 04: Add Cursor Stream-JSON Activity Parsing And Runtime Visibility

## Overview
This task makes Cursor a first-class observable Harness at runtime instead of just another launched command. It treats
Cursor `stream-json` as the canonical live-output contract, maps useful activity into the existing running-task state,
and preserves raw logs so provider-specific parser gaps do not erase diagnostics.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
1. MUST treat Cursor `stream-json` as the canonical V1 structured-output contract for live activity updates.
2. MUST normalize Cursor activity into existing Runtime State fields such as Harness identity, last event, last message, and tokens where supported.
3. MUST preserve raw stdout and stderr files as the durable diagnostic fallback for Cursor runs.
4. MUST ignore malformed or unknown Cursor output safely without crashing orchestration.
5. MUST verify that Runtime State, Terminal Console, and frontend live-state surfaces continue to present Cursor-selected running tasks coherently.
</requirements>

## Subtasks
- [ ] 4.1 Add Cursor-specific `stream-json` parsing near the existing provider output-processing path.
- [ ] 4.2 Feed parsed Cursor activity into the existing running-row fields without inventing a second runtime model.
- [ ] 4.3 Preserve raw-log fallback behavior for incomplete or malformed Cursor output.
- [ ] 4.4 Verify runtime JSON, Terminal Console detail rows, and dashboard state remain compatible with Cursor runs.
- [ ] 4.5 Add targeted backend and live-state tests for structured Cursor activity.

## Implementation Details
Follow the same provider-local observability pattern used for Claude, but only as far as Cursor’s documented output
shape justifies. See TechSpec "Monitoring and Observability", "Impact Analysis", and "Known Risks" for the decision to
reuse existing runtime fields and keep raw-log fallback mandatory.

### Relevant Files
- `apps/backend/lib/orchestrator.ml` — owns output refresh logic, provider-specific live activity parsing, and running-row updates.
- `apps/backend/lib/runtime_state.ml` — defines the normalized running-row fields Cursor activity should reuse.
- `apps/backend/lib/terminal_console_model.ml` — renders running-task detail rows including Harness identity and last activity.
- `apps/frontend/src/RuntimeStateSnapshot.res` — consumes runtime snapshot shape for the dashboard.
- `apps/frontend/src/Pages/Dashboard.res` — renders live running-task details from runtime state.
- `apps/backend/test/test_backend.ml` — holds existing Harness activity, dispatch, and Runtime State coverage to extend.

### Dependent Files
- `apps/backend/lib/server.ml` — serves runtime state snapshots to the frontend and must remain compatible with any Cursor activity changes.
- `apps/backend/bin/terminal_console_preview.ml` — preview state examples may need alignment if runtime row assumptions change.
- `README.md` — later docs must describe Cursor observability in terms that match runtime behavior.

### Related ADRs
- [ADR-001: Cursor Harness As A Bounded Multi-Harness Extension](adrs/adr-001.md) — Requires Runtime State visibility consistent with other Harnesses.
- [ADR-003: Native Cursor Harness Technical Design](adrs/adr-003.md) — Keeps provider-specific activity logic inside existing runtime seams.
- [ADR-004: Cursor Output, Readiness, And Loop Contract](adrs/adr-004.md) — Sets `stream-json` as canonical with raw-log fallback.

## Deliverables
- Cursor `stream-json` parser and normalized runtime activity updates.
- Raw-log fallback preserved for malformed or incomplete Cursor output.
- Runtime State and operator-facing visibility validated for Cursor-selected runs.
- Backend and live-state regression tests for Cursor activity handling.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for Cursor-selected dispatch activity and runtime visibility **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Representative Cursor message output updates normalized `last_message`.
  - [ ] Representative Cursor tool or phase output updates normalized `last_event`.
  - [ ] Cursor token or usage output updates running-row token fields when present.
  - [ ] Malformed `stream-json` lines are ignored safely.
  - [ ] Raw-log fallback remains available even when parsing fails.
- Integration tests:
  - [ ] A fake Cursor command emitting `stream-json` updates a running task with `harness_name: "cursor"` and useful activity fields.
  - [ ] Frontend/runtime snapshot consumers continue to accept Cursor running rows without schema regressions.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Cursor-selected running tasks are observable through existing runtime surfaces.
- Structured output improves live activity without making raw diagnostics dependent on parser success.
