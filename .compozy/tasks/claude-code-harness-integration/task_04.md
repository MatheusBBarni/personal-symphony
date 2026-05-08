---
status: completed
title: "Add Claude Harness V1 Readiness And Stream-JSON Parsing"
type: backend
complexity: high
dependencies:
  - task_02
  - task_03
---

# Task 04: Add Claude Harness V1 Readiness And Stream-JSON Parsing

## Overview
This task makes Claude a supported Agent Harness kind and adds V1 parsing for Claude CLI `stream-json` output. It gives operators a real Claude execution path while preserving raw stdout/stderr logs for diagnostics.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- MUST allow `claude` as a valid Harness kind.
- MUST validate selected Claude Harness executable/auth expectations without storing secret values.
- MUST support Claude Harness commands using CLI `stream-json`.
- MUST parse Claude stream events into normalized live activity fields.
- MUST ignore unknown or malformed stream events without crashing orchestration.
- MUST keep full raw output in stdout/stderr files.
</requirements>

## Subtasks
- [x] 4.1 Add `claude` to Harness kind validation.
- [x] 4.2 Add selected-only Claude readiness checks for executable/auth expectations.
- [x] 4.3 Add Claude command rendering coverage for model and reasoning placeholders.
- [x] 4.4 Add defensive Claude `stream-json` parsing for messages, tool events, and usage.
- [x] 4.5 Feed parsed Claude activity into existing running-row activity fields.
- [x] 4.6 Add representative stream fixture tests.

## Implementation Details
Modify `apps/backend/lib/config.ml` for Harness kind and readiness behavior. Modify `apps/backend/lib/orchestrator.ml` near current token and goal usage parsing so Claude stream handling remains close to existing output processing. Reference TechSpec "Integration Points" and "Testing Approach".

### Relevant Files
- `apps/backend/lib/config.ml` — owns Harness kind validation and selected-Harness readiness.
- `apps/backend/lib/orchestrator.ml` — owns command rendering, stdout/stderr parsing, and running activity updates.
- `apps/backend/test/test_backend.ml` — existing Harness command rendering and output parsing tests belong here.

### Dependent Files
- `apps/backend/lib/runtime_state.ml` — receives normalized activity fields and usage totals.
- `apps/frontend/src/Main.res` — later task consumes Runtime State activity and Harness identity.

### Related ADRs
- [ADR-001: First-Class Harness Runtime Settings](adrs/adr-001.md) — Selects Claude V1 through CLI `stream-json`.
- [ADR-004: Provider-Neutral Runtime State and Claude Stream Events](adrs/adr-004.md) — Requires live message and tool event normalization.

## Deliverables
- Claude Harness kind validation and readiness behavior.
- Claude `stream-json` parser for V1 live activity and usage.
- Tests for command rendering, readiness, and defensive parsing.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for Claude-selected dispatch output handling **(REQUIRED)**

## Tests
- Unit tests:
  - [x] `kind: "claude"` is accepted for a selected Harness.
  - [x] Missing Claude executable produces a selected-Harness readiness gap.
  - [x] Unselected Claude Harness does not produce executable readiness gaps.
  - [x] Claude command rendering substitutes `<model>` and `<reasoning>` when present.
  - [x] Representative Claude message event updates normalized last message.
  - [x] Representative Claude tool event updates normalized last event.
  - [x] Representative Claude usage event updates parsed usage totals.
  - [x] Malformed JSON and unknown event types are ignored safely.
- Integration tests:
  - [x] A fake Claude command emitting stream-json updates running task activity.
  - [x] Raw stdout/stderr files remain available after Claude stream parsing.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Claude can be selected as a Harness kind.
- Claude stream output produces useful Runtime State activity without coupling state to raw provider events.
