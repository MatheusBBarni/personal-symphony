---
status: completed
title: Capture Terminal Console Baseline Preview And Contract Inventory
type: backend
complexity: medium
dependencies: []

---

# Task 1: Capture Terminal Console Baseline Preview And Contract Inventory

## Overview
Capture the current backend Terminal Console rendering contract before any source conversion starts. This gives the rewrite a concrete before/after baseline for preview output, public API compatibility, and caller expectations.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details - do not duplicate here
- FOCUS ON "WHAT" - describe what needs to be accomplished, not how
- MINIMIZE CODE - show code only to illustrate current structure or problem areas
- TESTS REQUIRED - every task MUST include tests in deliverables
</critical>

<requirements>
1. MUST capture current `terminal_console_preview` output before changing backend Terminal Console source code.
2. MUST inventory the public `Terminal_console_tui` names consumed by backend runtime wiring, preview code, CLI wiring, and tests.
3. MUST identify which recommended preview states are already represented by `terminal_console_preview` and which states need supplemental evidence.
4. MUST preserve current product code behavior; this task may create evidence notes but must not change Runtime State, Runtime Settings, lifecycle, safe-aid, or UI semantics.
5. SHOULD record exact commands used so later tasks can reproduce the same baseline.
</requirements>

## Subtasks
- [x] 1.1 Capture the current backend build state for the Terminal Console shell library.
- [x] 1.2 Run the Terminal Console preview executable and save representative output as baseline evidence.
- [x] 1.3 Inventory public `Terminal_console_tui` types, values, helpers, and record fields used outside the module.
- [x] 1.4 Map existing backend tests to the parity areas listed in the TechSpec testing approach.
- [x] 1.5 Document preview coverage gaps for help modal, settings modal, minimum terminal size, or other states not emitted by the current preview executable.

## Implementation Details
Create a small evidence note under `.compozy/tasks/backend-tui-jsx-rewrite/evidence/` for the baseline command output and contract inventory. Use the TechSpec "Integration Points" and "Testing Approach" sections as the source of truth for what must stay compatible.

### Relevant Files
- `apps/backend/bin/terminal_console_tui.ml` - current public module contract and view construction surface.
- `apps/backend/bin/terminal_console_preview.ml` - current preview harness used for before/after parity evidence.
- `apps/backend/bin/dune` - shell library and preview executable module wiring.
- `apps/backend/bin/main.ml` - CLI caller for `Terminal_console_tui` settings, handoff, and local surfaces.
- `apps/backend/bin/terminal_console_runtime.ml` - runtime handoff caller for `Terminal_console_tui.runtime` and `run`.
- `apps/backend/test/test_backend.ml` - focused Terminal Console behavior and rendering contract tests.
- `.compozy/tasks/backend-tui-jsx-rewrite/_prd.md` - product parity and scope requirements.
- `.compozy/tasks/backend-tui-jsx-rewrite/_techspec.md` - implementation sequencing and verification guidance.

### Dependent Files
- `apps/backend/bin/terminal_console_tui.ml` - later tasks must compare changes against this baseline.
- `apps/backend/test/test_backend.ml` - later test updates should align with the coverage map produced here.
- `.compozy/tasks/backend-tui-jsx-rewrite/evidence/terminal-console-baseline.md` - evidence artifact consumed by final parity verification.

### Related ADRs
- [ADR-002: Select Complete Backend Terminal Console JSX Rewrite](adrs/adr-002.md) - Confirms complete V1 scope.
- [ADR-003: Select Complete Coverage With Strict Parity PRD Approach](adrs/adr-003.md) - Defines strict parity as the product gate.
- [ADR-004: Implement Terminal Console View Rewrite As Reason JSX With Preserved Module Contract](adrs/adr-004.md) - Defines preserved module contract and preview evidence expectations.

## Deliverables
- Baseline preview evidence saved under `.compozy/tasks/backend-tui-jsx-rewrite/evidence/`.
- Public contract inventory for `Terminal_console_tui` callers and tests.
- Preview state coverage map against the TechSpec representative-state list.
- Unit tests with 80%+ coverage for touched behavior **(REQUIRED)**.
- Integration tests for backend Terminal Console baseline capture **(REQUIRED)**.

## Tests
- Unit tests:
  - [x] Run `pnpm backend:build` before evidence capture to confirm the preview executable and shell library compile.
  - [x] Run `pnpm test` if any backend test helper or source file is changed while collecting evidence.
  - [x] Confirm no generated frontend `.res.js` files are created or modified.
- Integration tests:
  - [x] Run the built `terminal_console_preview` executable and save the non-interactive output.
  - [x] Confirm the preview output includes queue, readiness, attention, task detail, log, and Runtime State projection signals from the mock state.
  - [x] Confirm the evidence note explicitly marks missing preview states instead of treating them as covered.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Baseline preview evidence exists and names the exact command used to generate it.
- Public contract inventory covers `main.ml`, `terminal_console_runtime.ml`, `terminal_console_preview.ml`, and `test_backend.ml`.
- No operator-facing behavior, Runtime State shape, Runtime Settings, lifecycle, or safe-aid behavior is changed.
