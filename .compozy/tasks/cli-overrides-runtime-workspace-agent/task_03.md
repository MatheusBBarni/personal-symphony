---
status: pending
title: "Add Override CLI Flags, Strict Parsing, Help, And Unsupported-Mode Guard"
type: backend
complexity: medium
dependencies:
  - task_01
  - task_02
---

# Task 03: Add Override CLI Flags, Strict Parsing, Help, And Unsupported-Mode Guard

## Overview
This task adds the five issue-66 runtime-only CLI flags to the extracted command module. It also adds strict positive-integer parsing, help wording, duplicate-flag behavior coverage, and pre-scan rejection for unsupported command modes.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- MUST add `--polling.intervalMs`, `--workspace.root`, `--agent.maxConcurrentAgents`, `--agent.maxTurns`, and `--agent.maxRetryBackoffMs` to the default runtime command.
- MUST parse integer override values strictly and reject zero, negative, decimal, empty, and non-numeric values.
- MUST document every new flag in help output with current-invocation wording.
- MUST use argv pre-scan to reject runtime-only override flags for `init`, `update`, and legacy positional `WORKFLOW.md` mode with a clear message.
- MUST let Cmdliner's observed duplicate-option behavior stand and document it in tests.
</requirements>

## Subtasks
- [ ] 3.1 Add explicit runtime-only override args to the command module.
- [ ] 3.2 Add strict positive-integer parsing for numeric overrides.
- [ ] 3.3 Add help text for each override flag using current-invocation wording.
- [ ] 3.4 Add one shared list of runtime-only override flag names for parsing and unsupported-mode pre-scan.
- [ ] 3.5 Add tests for help output, invalid values, unsupported modes, and duplicate behavior.

## Implementation Details
Build on task_01's override model and task_02's extracted command module. Reference the TechSpec "Testing Approach" and "Technical Considerations" sections for duplicate behavior and pre-scan requirements. Do not wire the parsed values into runtime startup in this task; task_04 owns runtime pass-through.

### Relevant Files
- New backend CLI module from task_02 — owns Cmdliner terms, help text, and pre-scan logic.
- `apps/backend/bin/main.ml` — should continue delegating to the extracted module.
- `apps/backend/test/test_backend.ml` — add focused tests in or near the `cli` group.
- `apps/backend/test/dune` — must support any added Cmdliner test dependency from task_02.

### Dependent Files
- `apps/backend/lib/runtime_home.ml` — root-validation behavior must remain conceptually separate from `--workspace.root`.
- `apps/backend/lib/config.ml` — override parser should produce values compatible with the model from task_01.

### Related ADRs
- [ADR-001: Narrow Runtime Settings Invocation Overrides](adrs/adr-001.md) — Defines the five allowed flags.
- [ADR-002: Full Issue-66 Runtime Override Scope](adrs/adr-002.md) — Requires all five flags in the MVP.
- [ADR-004: CLI Command Extraction for Override Testing](adrs/adr-004.md) — Requires direct parser/help tests.

## Deliverables
- Five runtime-only CLI override flags on the default runtime command.
- Strict integer parsing and unsupported-mode guard behavior.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for CLI help and unsupported-mode failures **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] `symphony --help` includes `--polling.intervalMs` with current-invocation wording.
  - [ ] `symphony --help` includes `--workspace.root` and says it controls current-invocation Agent Worktree placement.
  - [ ] `symphony --help` includes all three `--agent.*` override flags.
  - [ ] Numeric override parsing rejects `0`, `-1`, `1.5`, empty input, and `abc`.
  - [ ] Duplicate `--polling.intervalMs` usage follows Cmdliner's observed repeated-option behavior.
- Integration tests:
  - [ ] `symphony init --polling.intervalMs 1000` fails with runtime-only default-command wording.
  - [ ] `symphony update --agent.maxConcurrentAgents 1` fails with runtime-only default-command wording.
  - [ ] `symphony WORKFLOW.md --workspace.root /tmp/workspaces` fails with runtime-only default-command wording.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- All five flags parse only for the default runtime command.
- Invalid numeric values fail before runtime dispatch.
