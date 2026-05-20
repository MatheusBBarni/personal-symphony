---
status: completed
title: "Add stage-scoped Goal Loop configuration and readiness validation"
type: backend
complexity: high
dependencies:
  - task_02

---

# Task 03: Add stage-scoped Goal Loop configuration and readiness validation

## Overview
This task adds the Runtime Settings surface that lets a Stage Agent opt into Goal Loop behavior. It validates evidence command configuration, budgets, timeout, and output limits before dispatch so invalid loop settings become Readiness Gaps instead of runtime surprises.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- REQ-01 MUST add Goal Loop configuration under Stage Agent settings, not under Harness or Logical Agent settings.
- REQ-02 MUST validate evidence command argv, cwd, timeout, max output bytes, and budget values.
- REQ-03 MUST report invalid or incomplete Goal Loop configuration as Readiness Gaps before dispatch.
- REQ-04 MUST preserve existing Stage Goal Handoff, Harness Loop, and Context Command config semantics.
- REQ-05 MUST keep missing Goal Loop settings disabled by default for existing Workspace Repositories.
</requirements>

## Subtasks
- [x] 3.1 Add stage-scoped Goal Loop configuration types and defaults.
- [x] 3.2 Parse Goal Loop settings from Runtime Settings.
- [x] 3.3 Add validation for evidence command settings and budgets.
- [x] 3.4 Add readiness gaps for invalid enabled Goal Loop settings.
- [x] 3.5 Add config parsing and readiness tests.

## Implementation Details
Follow the TechSpec "Integration Points" and ADR-003. This task should add configuration and readiness behavior only; it should not execute evidence commands or wire orchestration transitions.

### Relevant Files
- `apps/backend/lib/config.ml` — owns Runtime Settings parsing, Stage Agent types, and readiness validation.
- `apps/backend/lib/runtime_home.ml` — owns Bootstrap example settings and must remain idempotent.
- `apps/backend/test/test_backend.ml` — existing config and readiness coverage.
- `CONTEXT.md` — confirms Stage Agent, Logical Agent, Agent Harness, Harness Loop, and Stage Goal Handoff language.

### Dependent Files
- `apps/backend/lib/orchestrator.ml` — later tasks consume validated Goal Loop settings.
- `apps/backend/lib/runtime_state.ml` — later tasks expose config-derived loop state.
- `README.md` — final docs task will document the settings.

### Related ADRs
- [ADR-003: Stage-Scoped Goal Loop Runtime State](adrs/adr-003.md) — Requires Stage Agent-scoped config.
- [ADR-004: Evidence Command Completion Gate](adrs/adr-004.md) — Requires an evidence command contract.

## Deliverables
- Stage-scoped Goal Loop config parser and type definitions.
- Readiness validation for enabled Goal Loop settings.
- Backwards-compatible defaults for missing settings.
- Unit tests with 80%+ coverage **(REQUIRED)**.
- Integration tests for readiness gap behavior **(REQUIRED)**.

## Tests
- Unit tests:
  - [x] Missing Goal Loop settings parse as disabled.
  - [x] Enabled Goal Loop with valid evidence command and budgets parses successfully.
  - [x] Enabled Goal Loop with empty evidence command reports a readiness gap.
  - [x] Invalid cwd, timeout, max output bytes, or budget values report targeted readiness gaps.
  - [x] Existing Stage Goal Handoff loop settings still parse unchanged.
- Integration tests:
  - [x] Runtime readiness includes Goal Loop gaps while still allowing Terminal Console inspection.
  - [x] Unused or disabled Goal Loop settings do not block dispatch.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Stage Agent config is the only V1 Goal Loop configuration scope.
- Invalid enabled Goal Loop config blocks dispatch with actionable readiness text.
