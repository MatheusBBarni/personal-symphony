---
status: pending
title: Convert Terminal Console Shell Module To Reason With Stable Public Contract
type: refactor
complexity: high
dependencies:
  - task_01
---

# Task 2: Convert Terminal Console Shell Module To Reason With Stable Public Contract

## Overview
Convert the backend Terminal Console shell module from OCaml syntax to Reason syntax while keeping its module identity and public contract stable. This creates the source form required for literal JSX tags without changing Terminal Console behavior.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details - do not duplicate here
- FOCUS ON "WHAT" - describe what needs to be accomplished, not how
- MINIMIZE CODE - show code only to illustrate current structure or problem areas
- TESTS REQUIRED - every task MUST include tests in deliverables
</critical>

<requirements>
1. MUST preserve the exposed module name `Terminal_console_tui` in `symphony_terminal_console_shell`.
2. MUST preserve public types, constructors, record fields, helper functions, and caller-visible values used by backend callers and tests.
3. MUST keep this task focused on syntax conversion and compile compatibility; it must not intentionally redesign rendered UI structure.
4. MUST update Dune or source filenames only as needed to keep the same module slot available to existing callers.
5. MUST update preview diagnostic path strings that reference the renamed source file if the implementation moves from `.ml` to `.re`.
6. MUST not change Runtime State, Runtime Settings, lifecycle, safe-aid dispatch, Web Dashboard handoff semantics, or persisted files.
</requirements>

## Subtasks
- [ ] 2.1 Convert `apps/backend/bin/terminal_console_tui.ml` into a Reason-authored source for the same `terminal_console_tui` module.
- [ ] 2.2 Preserve all public names consumed by backend runtime wiring, CLI wiring, preview code, and tests.
- [ ] 2.3 Update `apps/backend/bin/dune` only if the source rename requires explicit compile-surface adjustment.
- [ ] 2.4 Update backend caller/test syntax only where Reason record or variant access requires source-compatible adjustments.
- [ ] 2.5 Keep the baseline preview output behavior unchanged after the conversion.
- [ ] 2.6 Remove the old OCaml source file when the Reason source fully replaces the module.

## Implementation Details
Use the TechSpec "Core Interfaces" and "Integration Points" sections as the compatibility contract. The task should produce a compiling Reason module first, even if direct `Tui.Components` calls still remain for later JSX conversion tasks.

### Relevant Files
- `apps/backend/bin/terminal_console_tui.ml` - source to replace with a Reason implementation for the same module.
- `apps/backend/bin/terminal_console_tui.re` - expected Reason source path after conversion.
- `apps/backend/bin/dune` - module list for `symphony_terminal_console_shell` and preview executable.
- `apps/backend/bin/main.ml` - caller for settings records, settings save results, handoff helpers, local surfaces, and compile anchor.
- `apps/backend/bin/terminal_console_runtime.ml` - caller for `runtime`, `default_settings`, `default_save_settings`, `default_web_handoff`, and `run`.
- `apps/backend/bin/terminal_console_preview.ml` - preview caller and source-path diagnostics.
- `apps/backend/test/test_backend.ml` - public contract and behavior coverage for Terminal Console helpers.

### Dependent Files
- `apps/backend/lib/terminal_console_model.re` - projection model consumed by the shell module and expected to remain unchanged.
- `apps/backend/lib/runtime_state.re` - Runtime State input shape consumed by the shell module and expected to remain unchanged.
- `.compozy/tasks/backend-tui-jsx-rewrite/evidence/terminal-console-baseline.md` - baseline output used to compare behavior after conversion.

### Related ADRs
- [ADR-002: Select Complete Backend Terminal Console JSX Rewrite](adrs/adr-002.md) - Requires complete backend Terminal Console JSX conversion as V1.
- [ADR-003: Select Complete Coverage With Strict Parity PRD Approach](adrs/adr-003.md) - Requires strict operator parity.
- [ADR-004: Implement Terminal Console View Rewrite As Reason JSX With Preserved Module Contract](adrs/adr-004.md) - Requires Reason JSX while preserving the existing module contract.

## Deliverables
- `Terminal_console_tui` implemented as Reason source for the same backend shell library module.
- Existing backend callers continue to compile without semantic contract changes.
- Preview diagnostics updated if source paths change from `.ml` to `.re`.
- Unit tests with 80%+ coverage for touched behavior **(REQUIRED)**.
- Integration tests for backend shell compile and preview compatibility **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] Run focused backend Terminal Console tests in `apps/backend/test/test_backend.ml` for status labels, projection, settings, modal state, safe aids, and rendered panel helpers.
  - [ ] Run `pnpm test` after the syntax conversion because the backend compile surface and Terminal Console behavior contract are touched.
  - [ ] Confirm no tests require Runtime State, Runtime Settings, lifecycle, or safe-aid expectation changes.
- Integration tests:
  - [ ] Run `pnpm backend:build` to confirm Dune builds the Reason source under the existing module name.
  - [ ] Run `terminal_console_preview` and compare output against the baseline evidence from task 1.
  - [ ] Confirm `main.ml` and `terminal_console_runtime.ml` still compile against the same public names.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- `Symphony_terminal_console_shell.Terminal_console_tui` remains the caller-facing module.
- The old `.ml` implementation is fully replaced by a Reason implementation.
- Preview output remains behavior-equivalent to the task 1 baseline.
- No Runtime Contract default, Task Branch cleanup, auto-merge, Runtime State, or settings semantics are changed.
