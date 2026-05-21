---
status: completed
title: "Finalize TUI Package Verification And Bundle Readiness"
type: chore
complexity: low
dependencies:
  - task_01
  - task_02
  - task_03
  - task_04
  - task_05


---

# Task 06: Finalize TUI Package Verification And Bundle Readiness

## Overview
This task closes the feature by checking the full TUI package surface after wrappers, examples, and docs are in place. It is a readiness task that fixes any remaining package-local drift discovered by verification rather than introducing a separate testing-only workstream.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- REQ-01 MUST run the TechSpec-required TUI package verification commands after all implementation and docs tasks are complete.
- REQ-02 MUST fix package-local compile, test, example-registration, or documentation drift found by verification.
- REQ-03 MUST confirm task metadata validation passes for `tui-jsx-api`.
- REQ-04 MUST keep verification scoped to the TUI package unless a package-local change reveals a required adjacent fix.
- REQ-05 MUST leave no generated frontend `.res.js` files or unrelated artifacts staged or required.
- REQ-06 MUST hand any broader behavior gap, public API scope gap, or non-package-local failure back to the owning task or a follow-up issue instead of expanding task 06 into a catch-all implementation task.
</requirements>

## Subtasks
- [x] 6.1 Review all completed task outputs against `_prd.md`, `_techspec.md`, and ADR-004.
- [x] 6.2 Run the TUI package test command and address any package-local failures.
- [x] 6.3 Run the TUI package build command and address any package-local failures.
- [x] 6.4 Run task validation for `tui-jsx-api` and fix metadata or template issues.
- [x] 6.5 Check for unrelated generated or accidental files in the task and package scope.
- [x] 6.6 If verification reveals a non-local or ownership-crossing gap, record it against the owning task or create a follow-up issue rather than absorbing it here.

## Implementation Details
Use the TechSpec "Testing Approach" and "Development Sequencing" sections as the verification contract. This task should only make small package-local fixes discovered by final verification; larger behavior gaps should be resolved in the implementation task that owns them.

### Relevant Files
- `apps/tui/package.json` — defines the package `test` and `build` scripts.
- `apps/tui/dune-project` — opam/package metadata for the public TUI package.
- `apps/tui/lib/dune` — library stanza for public package builds.
- `apps/tui/examples/dune` — example executable registration.
- `.compozy/tasks/tui-jsx-api/_tasks.md` — master task list for validation.
- `.compozy/tasks/tui-jsx-api/task_*.md` — task files validated by Compozy.

### Dependent Files
- `apps/tui/lib/tui.re` — final build proves public exports compile.
- `apps/tui/test/test_tui.re` — final tests prove wrapper parity and example behavior.
- `apps/tui/README.md` — final readback confirms public docs match implemented commands.

### Related ADRs
- [ADR-004: Implement JSX As Wrapper Modules Over Existing TUI Components](adrs/adr-004.md) — Defines TUI-only verification scope.

## Deliverables
- Passing TUI package test run.
- Passing TUI package build run.
- Passing Compozy task validation for `tui-jsx-api`.
- Unit tests with 80%+ coverage for any final package-local fixes **(REQUIRED)**.
- Integration tests for the final TUI package verification path **(REQUIRED)**.

## Tests
- Unit tests:
  - [x] Any package-local fix made during final verification includes a focused test in `apps/tui/test/test_tui.re`.
  - [x] Existing JSX wrapper and parity tests continue to pass without weakening assertions.
- Integration tests:
- [x] TUI package test script exits 0.
- [x] TUI package build script exits 0.
  - [x] `compozy tasks validate --name tui-jsx-api` exits 0.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing.
- Test coverage >=80%.
- TUI package build and test commands pass from the product repository.
- `compozy tasks validate --name tui-jsx-api` passes.
- Any broader failure found during verification is explicitly handed back to the owning task or follow-up issue instead of being silently absorbed into task 06.
- Final changed files are limited to the task bundle and intended TUI package/docs files.
