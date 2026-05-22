---
status: pending
title: Update Docs And Final Parity Verification Evidence
type: docs
complexity: medium
dependencies:
  - task_05
---

# Task 6: Update Docs And Final Parity Verification Evidence

## Overview
Refresh documentation after the backend Terminal Console fully dogfoods `Tui.Jsx`, then collect final verification evidence. The docs must frame the rewrite as a maintainer-facing authoring change, not a new operator-facing Terminal Console feature.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details - do not duplicate here
- FOCUS ON "WHAT" - describe what needs to be accomplished, not how
- MINIMIZE CODE - show code only to illustrate current structure or problem areas
- TESTS REQUIRED - every task MUST include tests in deliverables
</critical>

<requirements>
1. MUST update docs or examples that describe `Tui.Jsx` so they identify the backend Terminal Console as a production dogfooding surface after the rewrite is complete.
2. MUST avoid describing the rewrite as an operator-visible feature, redesign, runtime capability, new setting, or new safe aid.
3. MUST preserve package boundary language: `apps/tui` is reusable toolkit code and `apps/backend` owns product-specific Terminal Console behavior.
4. MUST collect final before/after preview parity evidence using the baseline from task 1.
5. MUST run backend verification and TUI package verification if `apps/tui` was changed by the rewrite.
6. SHOULD run docs/example validation if documentation examples are changed.
</requirements>

## Subtasks
- [ ] 6.1 Update relevant `Tui.Jsx` documentation to mention backend Terminal Console dogfooding after full coverage is achieved.
- [ ] 6.2 Update example guidance only if it currently implies examples are the only JSX validation surface.
- [ ] 6.3 Refresh final parity evidence with after-rewrite preview output and comparison notes.
- [ ] 6.4 Record final JSX coverage status and any allowed non-view lower-level direct API usage.
- [ ] 6.5 Run backend verification and any required TUI/docs verification commands.
- [ ] 6.6 Confirm generated or ignored artifacts are not accidentally staged.

## Implementation Details
Reference the PRD "Docs And Example Alignment" feature and the TechSpec "Development Sequencing" final steps. Keep documentation concise and implementation-facing; do not add operator instructions for a behavior-preserving rewrite.

### Relevant Files
- `apps/tui/README.md` - main TUI Toolkit Package documentation for JSX authoring.
- `apps/tui/examples/agent_workspace/README.md` - existing JSX example guidance if example positioning needs adjustment.
- `.compozy/tasks/backend-tui-jsx-rewrite/evidence/terminal-console-baseline.md` - baseline preview and contract evidence.
- `.compozy/tasks/backend-tui-jsx-rewrite/evidence/terminal-console-final-parity.md` - expected final parity evidence note.
- `apps/backend/bin/terminal_console_preview.ml` - final preview harness.

### Dependent Files
- `apps/backend/bin/terminal_console_tui.re` - completed JSX rewrite whose coverage must be summarized accurately.
- `apps/tui/lib/jsx.re` - reusable JSX wrapper surface if changed by task 5.
- `apps/tui/test/test_tui.re` - wrapper parity tests if task 5 changed wrappers.
- `scripts/validate-docs-examples.js` - docs/examples validation command target.

### Related ADRs
- [ADR-002: Select Complete Backend Terminal Console JSX Rewrite](adrs/adr-002.md) - Requires complete backend Terminal Console JSX rewrite.
- [ADR-003: Select Complete Coverage With Strict Parity PRD Approach](adrs/adr-003.md) - Requires strict parity and complete coverage before claiming success.
- [ADR-004: Implement Terminal Console View Rewrite As Reason JSX With Preserved Module Contract](adrs/adr-004.md) - Defines backend dogfooding, preserved contract, and wrapper verification rules.

## Deliverables
- Documentation updated to reflect backend Terminal Console `Tui.Jsx` dogfooding.
- Final parity evidence note with preview comparison, coverage status, and verification commands.
- Backend verification results recorded.
- TUI package and docs verification results recorded when applicable.
- Unit tests with 80%+ coverage for touched behavior **(REQUIRED)**.
- Integration tests for final backend Terminal Console parity **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] Run `pnpm test` for backend behavior coverage after final docs and evidence updates.
  - [ ] Run `pnpm --filter @symphony-orchestrator/tui test` if any `apps/tui` source or wrapper tests changed in the rewrite.
  - [ ] Run docs/example validation if `apps/tui` docs or examples changed.
- Integration tests:
  - [ ] Run `pnpm backend:build` for final backend compile verification.
  - [ ] Run `pnpm --filter @symphony-orchestrator/tui build` if any TUI package compile surface changed.
  - [ ] Run `terminal_console_preview` and compare final output against the task 1 baseline.
  - [ ] Confirm `git status --short` does not include generated `apps/frontend/src/*.res.js` files.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Docs accurately state that backend Terminal Console dogfoods `Tui.Jsx` after the rewrite.
- Final parity evidence records baseline comparison, backend verification, and any conditional TUI/docs verification.
- The completed work claims 100% JSX coverage only for existing backend Terminal Console UI construction.
- No docs claim new operator behavior, Runtime State semantics, Runtime Settings, lifecycle behavior, or safe-aid capabilities.
