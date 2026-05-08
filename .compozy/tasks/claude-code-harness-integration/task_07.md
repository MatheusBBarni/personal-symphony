---
status: pending
title: "Update Bootstrap Runtime Contract Defaults"
type: backend
complexity: medium
dependencies:
  - task_01
  - task_02
  - task_03
  - task_04
  - task_05
---

# Task 07: Update Bootstrap Runtime Contract Defaults

## Overview
This task updates the default Runtime Contract created by Bootstrap so new Workspace Repositories start with the new `harnesses` and logical `agents` shape. It must preserve idempotent Bootstrap behavior and avoid writing secrets or overwriting existing user-edited files.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- MUST update bootstrapped `.symphony/settings.json` with `harnesses.codex`, `harnesses.claude`, and `harnesses.pi`.
- MUST update bootstrapped `.symphony/settings.json` with logical `agents.planner`, `agents.engineer`, and `agents.reviewer`.
- MUST keep `stageAgents` focused on status-to-agent routing and remove any steady-state stage-level Harness selection from defaults.
- MUST keep provider secrets out of examples.
- MUST preserve Bootstrap idempotency and skip existing user-edited Runtime Contract files.
- MUST ensure newly bootstrapped settings load successfully with the new parser.
</requirements>

## Subtasks
- [ ] 7.1 Update default settings JSON in Runtime Home Bootstrap.
- [ ] 7.2 Include default Harness loop configuration.
- [ ] 7.3 Include default logical agent execution selections.
- [ ] 7.4 Keep existing prompt and `.symphony/agents/*.md` file Bootstrap behavior unchanged.
- [ ] 7.5 Add tests proving new defaults load and existing settings are not overwritten.

## Implementation Details
Modify `apps/backend/lib/runtime_home.ml` only for Bootstrap defaults unless tests reveal an adjacent parser fixture needs updating. Reference TechSpec "High-Level Technical Constraints" and "Development Sequencing" for the Bootstrap boundary.

### Relevant Files
- `apps/backend/lib/runtime_home.ml` — owns `settings_json` and idempotent Bootstrap file creation.
- `apps/backend/test/test_backend.ml` — contains Runtime Home and Bootstrap behavior tests.
- `.compozy/tasks/claude-code-harness-integration/_prd.md` — defines the example target settings shape.

### Dependent Files
- `apps/backend/lib/config.ml` — parser from tasks 01 and 02 must load the new defaults.
- `README.md` and `CONTEXT.md` — task_08 must align docs with Bootstrap defaults.

### Related ADRs
- [ADR-001: First-Class Harness Runtime Settings](adrs/adr-001.md) — Requires first-class Harness defaults.
- [ADR-002: Clarity-First PRD Scope](adrs/adr-002.md) — Requires examples that teach the new model directly.
- [ADR-003: Runtime Settings Resolution and Loop Semantics](adrs/adr-003.md) — Removes steady-state stage-level Harness selection.

## Deliverables
- Bootstrapped settings use `harnesses` and logical `agents`.
- Existing Bootstrap idempotency behavior preserved.
- Bootstrap and settings-load tests updated.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for Bootstrap-created settings **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Bootstrap creates settings containing `harnesses.codex.loop.command: "/goal"`.
  - [ ] Bootstrap creates settings containing `harnesses.claude.kind: "claude"`.
  - [ ] Bootstrap creates settings containing `agents.engineer.harness`.
  - [ ] Bootstrap defaults contain no secret values.
  - [ ] Bootstrap skips an existing `.symphony/settings.json`.
- Integration tests:
  - [ ] A newly bootstrapped settings file loads through `Config.from_settings_file`.
  - [ ] Existing `.symphony/agents/planner.md`, `engineer.md`, and `reviewer.md` idempotency remains unchanged.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- New Workspace Repositories receive the new Runtime Contract shape.
- Existing Workspace Repository Runtime Contract files remain untouched by Bootstrap.
