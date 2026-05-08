---
status: completed
title: "Implement Harness Loop Handoff Semantics"
type: backend
complexity: medium
dependencies:
  - task_02
---

# Task 03: Implement Harness Loop Handoff Semantics

## Overview
This task replaces Codex-specific `/goal` prompt prepending with Harness loop configuration while keeping `stageAgents.stages[].goal.enabled` as the per-stage switch. It lets loop-enabled Codex keep current behavior and lets non-loop Harnesses run the normal prompt without blocking.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- MUST keep stage-level `goal.enabled` parsing and behavior as the operator switch.
- MUST use selected Harness `loop.command` instead of hard-coded `/goal`.
- MUST prepend Stage Goal Context only when stage goal is enabled and selected Harness loop is enabled.
- MUST silently run the normal prompt when stage goal is enabled but Harness loop is disabled or command is empty.
- MUST keep Codex goal support readiness scoped to loop-enabled Codex Harnesses.
</requirements>

## Subtasks
- [x] 3.1 Update prompt composition to read selected Harness loop settings.
- [x] 3.2 Replace hard-coded `/goal` with configured `loop.command`.
- [x] 3.3 Skip loop handoff for disabled or empty Harness loop settings.
- [x] 3.4 Update Codex goal readiness to apply only to selected loop-enabled Codex Harnesses.
- [x] 3.5 Add focused prompt composition tests for Codex, Claude, and empty loop commands.

## Implementation Details
Modify `apps/backend/lib/orchestrator.ml` around Stage Goal Context composition and `apps/backend/lib/config.ml` around Codex goal readiness. Reference TechSpec "Technical Considerations" and ADR-003 for the loop rule.

### Relevant Files
- `apps/backend/lib/orchestrator.ml` — currently prepends `/goal` in prompt composition.
- `apps/backend/lib/config.ml` — currently checks Codex goal support for stage goal handoff.
- `apps/backend/test/test_backend.ml` — contains Stage Goal Handoff and prompt composition tests.

### Dependent Files
- `apps/backend/lib/runtime_state.ml` — later tasks may surface loop status through runtime diagnostics.
- `README.md` and `CONTEXT.md` — later docs must describe Harness loop behavior.

### Related ADRs
- [ADR-001: First-Class Harness Runtime Settings](adrs/adr-001.md) — Introduces Harness loop configuration.
- [ADR-003: Runtime Settings Resolution and Loop Semantics](adrs/adr-003.md) — Keeps stage goal as the switch and defines silent skip behavior.

## Deliverables
- Harness loop prompt composition.
- Codex goal readiness scoped to selected loop-enabled Codex Harnesses.
- Tests proving loop command, disabled loop, and empty command behavior.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for prompt composition **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Codex Harness with `loop.enabled: true` and `loop.command: "/goal"` prepends `/goal` with Stage Goal Context.
  - [ ] Codex Harness with a custom loop command prepends that configured command.
  - [ ] Claude Harness with `loop.enabled: false` and stage `goal.enabled: true` runs the normal prompt.
  - [ ] Harness with `loop.enabled: true` and blank command runs the normal prompt.
  - [ ] Codex goal feature readiness is not required when no selected loop-enabled Codex Harness exists.
- Integration tests:
  - [ ] Dispatching a loop-enabled Codex stage writes a prompt containing Stage Goal Context.
  - [ ] Dispatching a Claude-selected stage with goal enabled writes a prompt without loop handoff.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- `/goal` is no longer hard-coded as global Stage Goal Handoff behavior.
- Non-loop Harnesses can run without readiness blockage from stage goal settings.
