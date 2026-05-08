---
status: pending
title: "Build Compozy task-step prompt context"
type: backend
complexity: medium
dependencies:
  - task_03
---

# Task 04: Build Compozy task-step prompt context

## Overview
Add prompt assembly for the current task step in a Compozy PRD run. Each prompt must include the current `task_NN.md` file and include `_prd.md` and `_techspec.md` when those files exist.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST assemble current task-step prompt content from the selected task file.
- R2 MUST include `_prd.md` content when present.
- R3 MUST include `_techspec.md` content when present.
- R4 MUST preserve existing `Prompt.render` and stage prompt behavior for GitHub runs.
- R5 MUST return deterministic errors when no runnable task step exists.
- R6 MUST avoid adding unrelated Compozy artifacts unless explicitly required by the TechSpec.
</requirements>

## Subtasks
- [ ] 4.1 Add current task-step prompt assembly to the Compozy tracker module.
- [ ] 4.2 Include PRD and TechSpec sections when files are present.
- [ ] 4.3 Produce deterministic diagnostics for missing runnable task files.
- [ ] 4.4 Integrate the assembled prompt with existing orchestrator prompt composition hooks.
- [ ] 4.5 Add prompt content tests.

## Implementation Details
Reference TechSpec "Task-step prompt assembly" and "Compozy Artifacts". Do not duplicate prompt wrappers from `Orchestrator.compose_prompt`; this task should provide Compozy-specific base content for existing composition.

### Relevant Files
- `apps/backend/lib/compozy_tasks_tracker.ml` — Builds Compozy task-step prompt content.
- `apps/backend/lib/orchestrator.ml` — Existing `Prompt.render` and `compose_prompt_result` path wraps base prompt content.
- `apps/backend/lib/prompt.ml` — Template field behavior should remain unchanged.
- `apps/backend/test/test_backend.ml` — Existing prompt composition tests are nearby precedent.

### Dependent Files
- `.compozy/tasks/<task_name>/_prd.md` — Prompt context input when present.
- `.compozy/tasks/<task_name>/_techspec.md` — Prompt context input when present.
- `apps/backend/lib/runtime_state.ml` — Later tasks may expose prompt/context diagnostics.

### Related ADRs
- [ADR-002: Treat a Compozy PRD run as the local issue](adrs/adr-002.md) — Requires PRD and TechSpec context for every task-step prompt.
- [ADR-005: Relaunch task steps sequentially in one worktree](adrs/adr-005.md) — Requires per-step prompt scope.

## Deliverables
- Compozy current-step prompt assembly.
- Deterministic missing-runnable-step diagnostics.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for prompt assembly from a PRD-run fixture **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Prompt includes current task file title and body.
  - [ ] Prompt includes `_prd.md` content when the file exists.
  - [ ] Prompt includes `_techspec.md` content when the file exists.
  - [ ] Prompt still succeeds when `_prd.md` or `_techspec.md` is absent.
  - [ ] No runnable task files returns a deterministic error.
- Integration tests:
  - [ ] Orchestrator composition can wrap a Compozy task-step base prompt without changing GitHub prompt behavior.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Every Compozy task-step prompt includes task content and available PRD/TechSpec context.
- Existing GitHub prompt rendering remains unchanged.
