---
status: pending
title: "Extract Cmdliner Command Construction Into Backend Library"
type: refactor
complexity: medium
dependencies: []
---

# Task 02: Extract Cmdliner Command Construction Into Backend Library

## Overview
This task moves Cmdliner command construction out of the executable entrypoint and into a backend library module. The extraction makes CLI help and parser behavior directly testable while keeping the binary entrypoint thin.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- MUST move command construction for the existing `symphony` command into a backend library module.
- MUST preserve existing behavior for `--port`, `--once`, `--web`, `--queue`, `--merge`, `init`, `update`, help, and version handling.
- MUST keep executable-specific process wiring in `apps/backend/bin/main.ml`.
- MUST make Cmdliner command behavior available to backend tests without shelling out to the built executable.
- MUST avoid introducing package, frontend, or Runtime Contract changes.
</requirements>

## Subtasks
- [ ] 2.1 Create or select a backend library module for command construction.
- [ ] 2.2 Move existing Cmdliner args, terms, command grouping, and help normalization into the library boundary.
- [ ] 2.3 Keep `apps/backend/bin/main.ml` as thin evaluation wiring.
- [ ] 2.4 Update Dune dependencies so library and tests can compile with Cmdliner.
- [ ] 2.5 Add regression tests for existing CLI mode selection and command availability.

## Implementation Details
Use the TechSpec "System Architecture" and "CLI Command Extraction for Override Testing" ADR as the boundary. This task should not add the new override flags yet; it should move the existing command surface with behavior preserved so task_03 can add flags on top of a testable module.

### Relevant Files
- `apps/backend/bin/main.ml` — currently owns `open Cmdliner`, arg definitions, command construction, help argv normalization, and `Cmd.eval'`.
- `apps/backend/bin/dune` — currently links `cmdliner` only in the executable.
- `apps/backend/lib/dune` — backend library may need `cmdliner`.
- `apps/backend/test/dune` — tests may need direct or transitive access to Cmdliner types.
- `apps/backend/test/test_backend.ml` — existing `cli` group and `test_cli_mode_selection` are the nearest test area.

### Dependent Files
- `apps/backend/lib/update_cli.ml` — update behavior must remain available from the extracted command.
- `apps/backend/lib/cli_mode.ml` — existing mode selection tests must continue to pass.

### Related ADRs
- [ADR-004: CLI Command Extraction for Override Testing](adrs/adr-004.md) — Requires command construction to move into the backend library for direct tests.

## Deliverables
- Backend library command module or equivalent extracted command boundary.
- Thin executable entrypoint that delegates to the library command.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for existing CLI behavior preservation **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Existing terminal mode selection still maps no `--web` flag to Terminal Console.
  - [ ] Existing web mode selection still maps `--web` to Web Dashboard.
  - [ ] Existing command construction exposes `init` and `update` subcommands.
  - [ ] Help argv normalization still maps `-h` to `--help` and `-v` to `--version`.
- Integration tests:
  - [ ] The factored command can be evaluated from backend tests without shelling out to the built executable.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Existing CLI behavior is preserved before new override flags are added.
- `main.ml` no longer duplicates command construction logic that tests need.
