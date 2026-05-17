---
status: completed
title: "Implement Cursor Loop Readiness And Goal Handoff Support"
type: backend
complexity: medium
dependencies:
  - task_01
  - task_02

---

# Task 03: Implement Cursor Loop Readiness And Goal Handoff Support

## Overview
This task extends Symphony’s existing `loop.enabled` / `loop.command` product model to Cursor without pretending
Cursor is Codex. It allows operators to opt into plugin-backed Cursor loop entry while protecting dispatch with
explicit readiness checks when loop support is enabled.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
1. MUST support Cursor `loop.enabled` and `loop.command` through the existing Harness loop configuration model.
2. MUST perform explicit loop readiness validation for loop-enabled Cursor Harnesses before dispatch.
3. MUST prepend the configured Cursor loop command only when stage goal handoff is enabled and Cursor loop readiness succeeds.
4. MUST skip loop behavior entirely when Cursor loop is disabled or the configured command is blank.
5. MUST preserve existing Codex and non-loop Harness behavior, including Codex-specific goal readiness checks.
</requirements>

## Subtasks
- [x] 3.1 Extend Cursor Harness semantics so loop-enabled configuration participates in stage goal handoff.
- [x] 3.2 Add Cursor-specific readiness validation for plugin-backed loop support.
- [x] 3.3 Ensure prompt composition prepends the configured Cursor loop command only in valid goal-handoff cases.
- [x] 3.4 Keep disabled or blank Cursor loop configuration on the normal prompt path.
- [x] 3.5 Add targeted tests for disabled, blank, failing, and successful Cursor loop scenarios.

## Implementation Details
Build on the current Harness loop model instead of introducing a new provider-specific goal-handoff abstraction. See
TechSpec "Data Flow", "Technical Dependencies", and "Known Risks" for the requirement that Cursor loop support be
operator-configured, plugin-backed, and guarded by explicit readiness rather than inherited Codex assumptions.

### Relevant Files
- `apps/backend/lib/config.ml` — owns loop-enabled readiness decisions and current Codex goal checks that Cursor must not bypass.
- `apps/backend/lib/orchestrator.ml` — owns prompt composition and loop-command prepending during stage goal handoff.
- `apps/backend/test/test_backend.ml` — contains prompt-composition and Harness loop tests to extend for Cursor.

### Dependent Files
- `apps/backend/lib/runtime_home.ml` — Bootstrap examples later depend on the supported Cursor loop contract from this task.
- `README.md` — later operator docs must match the exact loop-enabled Cursor behavior defined here.
- `CONTEXT.md` — glossary and invariants for Harness loop behavior must reflect Cursor support once implemented.

### Related ADRs
- [ADR-001: Cursor Harness As A Bounded Multi-Harness Extension](adrs/adr-001.md) — Rejects hidden orchestration outside the Harness boundary.
- [ADR-003: Native Cursor Harness Technical Design](adrs/adr-003.md) — Requires loop support to live inside the existing Harness model.
- [ADR-004: Cursor Output, Readiness, And Loop Contract](adrs/adr-004.md) — Approves plugin-backed Cursor loop support through `loop.enabled` and `loop.command`.

## Deliverables
- Cursor-specific loop-readiness validation for loop-enabled Harnesses.
- Prompt-composition support for configured Cursor loop handoff.
- Regression coverage preserving Codex and non-loop Harness semantics.
- Tests for loop-disabled, blank-command, failing-plugin, and successful-plugin scenarios.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for Cursor goal-handoff prompt behavior **(REQUIRED)**

## Tests
- Unit tests:
  - [x] A loop-enabled Cursor Harness with missing plugin readiness produces a blocking loop requirement.
  - [x] A loop-disabled Cursor Harness with stage goal enabled does not prepend a loop command.
  - [x] A Cursor Harness with blank `loop.command` behaves like normal prompt execution.
  - [x] Existing Codex loop readiness and loop prompt composition remain unchanged.
  - [x] Non-loop Claude and PI behavior remains unchanged.
- Integration tests:
  - [x] A selected Cursor stage with successful loop readiness prepends the configured loop command and stage goal context.
  - [x] A selected Cursor stage with loop disabled emits the normal prompt without loop handoff.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Loop-enabled Cursor Harnesses participate in stage goal handoff only when explicitly configured and ready.
- Cursor loop support does not weaken existing Codex goal protection or non-loop provider behavior.
