---
status: pending
title: Add Default Local Harness Probe Adapter
type: backend
complexity: medium
dependencies:
  - task_01
---

# Task 2: Add Default Local Harness Probe Adapter

## Overview
Add the production probe adapter that maps the local developer environment into the detection boundary from Task 1. The adapter should check only allowlisted Harness signals, sanitize all command output, and stay testable without depending on the machine running the tests.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST implement a default local probe for supported Harnesses using the injectable boundary from Task 1.
- R2 MUST check Codex with executable availability only and must not claim Codex authentication or dispatch readiness.
- R3 MUST check Claude, Cursor, and PI install/auth signals consistently with existing selected-Harness readiness semantics where dependency direction allows reuse.
- R4 MUST run any status command, including `cursor-agent status`, through a bounded and sanitized probe path that never records stdout, stderr, tokens, credential files, or webhook URLs.
- R5 MUST convert missing executable, failed status, and missing auth cases into user-safe status/remediation values.
- R6 MUST keep tests independent of the developer machine by using injected fake probe functions, temporary homes, and fake command outcomes.
</requirements>

## Subtasks
- [ ] 2.1 Implement the default probe adapter for Codex, Claude, Cursor, and PI signals.
- [ ] 2.2 Map probe failures into sanitized Harness statuses and remediation categories.
- [ ] 2.3 Reuse or mirror existing readiness helper semantics without creating module cycles.
- [ ] 2.4 Add tests for fake executables, fake auth files, fake environment names, and fake status command outcomes.
- [ ] 2.5 Add regression checks that command output and secret-like values are not propagated.

## Implementation Details
Extend `apps/backend/lib/bootstrap_harness_detection.re` with a production adapter, or create small private helpers in the same module if that keeps the boundary cohesive. Existing readiness helpers in `apps/backend/lib/config.ml` define important semantics for `claude`, `cursor`, and `pi`; reuse them only if it does not force `Config` to depend on Bootstrap helpers. See the TechSpec "Data Models" and "Testing Approach" sections for the intended confidence levels and test strategy.

### Relevant Files
- `apps/backend/lib/bootstrap_harness_detection.re` — Production probe adapter and sanitization live with the detection boundary.
- `apps/backend/lib/config.ml` — Existing executable and auth readiness semantics for selected Claude, Cursor, and PI Harnesses.
- `apps/backend/test/test_backend.ml` — Fake-probe and sanitized-output tests belong near detection or Harness readiness tests.
- `.compozy/tasks/init-harness-detection/_prd.md` — Defines the no-secret and runtime-readiness authority constraints.

### Dependent Files
- `apps/backend/lib/bootstrap_settings.re` — Consumes detected selected Harness names from this adapter.
- `apps/backend/lib/runtime_home.ml` — Calls the default adapter during missing-settings Bootstrap in a later task.
- `apps/backend/bin/main.ml` — Renders sanitized guidance in a later task.

### Related ADRs
- [ADR-001: Seed Missing Runtime Settings From Local Harness Detection](adrs/adr-001.md) — Requires local allowlisted detection without treating it as runtime authority.
- [ADR-003: Isolate Bootstrap Detection and Settings Generation in Reason Helpers](adrs/adr-003.md) — Requires injectable probes and secret-free results.

## Deliverables
- Default local probe adapter for all supported selectable Harnesses.
- Sanitized remediation values for install, auth, and status-check failure states.
- Tests proving fake local state drives detection without invoking real Harness tools.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for default probe behavior with fake command and auth fixtures **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Codex executable-present fixture marks `codex` usable with executable-only confidence.
  - [ ] Claude executable plus fake auth signal marks `claude` usable; missing auth produces Claude remediation.
  - [ ] Cursor executable plus successful fake status marks `cursor` usable; failed status produces Cursor remediation without stdout or stderr.
  - [ ] PI executable plus fake provider auth marks `pi` usable; missing provider auth produces PI remediation.
  - [ ] Probe command exceptions and nonzero exits become not-usable statuses instead of test failures.
  - [ ] Secret markers from env values, auth files, and command output do not appear in statuses or guidance.
- Integration tests:
  - [ ] Temporary PATH/home fixtures exercise the default adapter without requiring real local installations.
  - [ ] Backend build sees no module cycle between Bootstrap helpers and `Config`.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Local detection is allowlisted, deterministic, and safe to run during Bootstrap.
- Codex guidance remains explicitly weaker than runtime readiness.
- No probe result or remediation contains secret values or raw command output.
