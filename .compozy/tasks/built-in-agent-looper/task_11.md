---
status: completed
title: "Update operator docs examples and final validation coverage"
type: docs
complexity: medium
dependencies:
  - task_03
  - task_08
  - task_09
  - task_10

---

# Task 11: Update operator docs examples and final validation coverage

## Overview
This task completes the feature documentation and verification story after backend and UI behavior are implemented. It documents Goal Loop configuration, evidence command behavior, Runtime State visibility, operator outcomes, and the boundaries that preserve existing delivery semantics.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- REQ-01 MUST document Goal Loop settings, evidence command contract, stop outcomes, and Runtime State fields.
- REQ-02 MUST update Bootstrap or example settings only if implementation explicitly accepted those defaults.
- REQ-03 MUST document that Goal Loop does not own Stage Commit, Stage Push, merge, PR, auto-merge, or status authority.
- REQ-04 MUST update repo docs/tests for Terminal Console and Web Dashboard visibility.
- REQ-05 MUST run the final verification set appropriate for backend, frontend, docs, and task validation.
</requirements>

## Subtasks
- [x] 11.1 Update README and relevant docs for Goal Loop operator behavior.
- [x] 11.2 Update Runtime Settings examples and secret-free evidence command examples.
- [x] 11.3 Update `CONTEXT.md` if implementation changed final terms after task_01.
- [x] 11.4 Add final docs/test assertions for operator-facing semantics.
- [x] 11.5 Run full validation and record any remaining gaps.

## Implementation Details
Use the TechSpec "Monitoring and Observability" and "Development Sequencing" sections. This task should not introduce new runtime behavior except documentation-driven tests or fixture updates required to keep docs accurate.

### Relevant Files
- `README.md` — primary operator docs for Symphony runtime behavior.
- `CONTEXT.md` — domain source of truth.
- `docs/adr/` — contains repo-level decisions for runtime semantics.
- `apps/backend/test/test_backend.ml` — documentation and runtime behavior assertions.
- `apps/frontend/test/liveState.test.mjs` — final dashboard snapshot coverage.
- `.compozy/tasks/built-in-agent-looper/_tasks.md` — task bundle master list for validation.

### Dependent Files
- `apps/backend/lib/runtime_home.ml` — examples must remain idempotent and secret-free.
- `apps/backend/lib/config.ml` — docs must match actual settings.
- `apps/backend/lib/runtime_state.ml` — docs must match actual Runtime State fields.
- `apps/backend/bin/terminal_console_tui.ml` and `apps/frontend/src/Pages/Dashboard.res` — docs must match actual operator surfaces.

### Related ADRs
- [ADR-001: Goal Loop Runtime Scope](adrs/adr-001.md) — Defines scope and lifecycle boundaries.
- [ADR-002: Evidence-First Goal Loop Approach](adrs/adr-002.md) — Defines evidence-first product behavior.
- [ADR-003: Stage-Scoped Goal Loop Runtime State](adrs/adr-003.md) — Defines state and config scope.
- [ADR-004: Evidence Command Completion Gate](adrs/adr-004.md) — Defines evidence gate and retry/attention behavior.

## Deliverables
- Updated operator documentation for Goal Loop.
- Updated docs tests or assertions.
- Secret-free examples for evidence command configuration.
- Final verification notes for backend, frontend, docs, and task validation.
- Unit tests with 80%+ coverage **(REQUIRED)**.
- Integration tests across backend/frontend/docs validation **(REQUIRED)**.

## Tests
- Unit tests:
  - [x] Docs assertions confirm Goal Loop terms and lifecycle boundaries.
  - [x] Runtime Settings examples are secret-free and parse correctly.
  - [x] Documentation mentions deterministic evidence for `Goal met`.
- Integration tests:
  - [x] `pnpm test` coverage verified through the equivalent Dune backend/docs test command.
  - [x] `pnpm frontend:test` coverage verified through the frontend live-state test command.
  - [x] `pnpm frontend:build` coverage verified through the ReScript and Vite build commands.
  - [x] `pnpm backend:build` coverage verified through the equivalent Dune backend build command.
  - [x] `compozy tasks validate --name built-in-agent-looper` passes for this bundle.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Operator docs match implemented behavior.
- Goal Loop examples are secret-free and idempotent.
- Task validation passes for the generated bundle.

## Validation Notes
- `node scripts/validate-docs-examples.js` passed and confirmed the Goal Loop examples parse and remain secret-free.
- `opam exec -- dune runtest --root=. --build-dir=/private/tmp/symphony-goal-loop-dune-build` passed the backend, TUI, and docs assertion suites.
- `opam exec -- dune build @all --root=. --build-dir=/private/tmp/symphony-goal-loop-dune-build` passed backend build validation.
- Frontend validation passed from `/private/tmp/symphony-frontend-verify` with the repository frontend sources and copied local dependencies: `rescript build`, `node test/liveState.test.mjs`, `node test/audioNotifications.test.mjs`, and `vite build`.
- Direct `pnpm test`, `pnpm frontend:test`, `pnpm frontend:build`, and `pnpm backend:build` wrappers were blocked in this sandbox because pnpm attempted registry fetches while network access is restricted; the underlying script commands above passed.
- `compozy tasks validate --name built-in-agent-looper` passed.
- `git diff --check` passed.
