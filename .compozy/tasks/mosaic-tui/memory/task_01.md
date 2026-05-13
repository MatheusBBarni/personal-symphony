# Task Memory: task_01.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Build the pure backend `Terminal_console_model` projection for Mosaic Terminal Console MVP without changing Runtime State schema or orchestration behavior.
- Target implementation repo is `/Users/matheusbbarni/projects/symphony-orchestrator`; the starting cwd `/Users/matheusbbarni/projects/pi-agent-native` does not contain the `apps/backend` surfaces from the task spec.

## Important Decisions
- Keep task 01 limited to the pure backend projection and tests. Mosaic dependency/runtime wiring belongs to later tasks.
- Mode precedence follows the renderer-facing safety priority: `attention`, `retrying`, `running`, `readiness_blocked`, `ready`, then `idle`.
- `ready` is used for a pending Ordered Queue with no active work or Readiness Gaps, matching the TechSpec even though task 01 mainly names idle/running/retrying/attention/readiness-blocked scenarios.

## Learnings
- Baseline signal: `apps/backend/lib/terminal_console_model.ml` is absent and `rg` finds no existing `Terminal_console_model` tests or implementation.
- Existing Runtime State serialization, Ordered Queue, Compozy progress, Goal Usage, context status, and live-state tests are grouped in `apps/backend/test/test_backend.ml` around the Runtime State section.
- `apps/backend/lib/dune` uses automatic module discovery; adding `terminal_console_model.ml` required no Dune file change.
- No coverage-specific tool is configured in this repo, so coverage evidence is focused Alcotest cases covering all public projection entry points and mode/data branches plus full backend tests.

## Files / Surfaces
- Added: `apps/backend/lib/terminal_console_model.ml`.
- Updated: `apps/backend/test/test_backend.ml` Runtime State test section.
- Verified unchanged: `apps/backend/lib/runtime_state.ml`, orchestration/tracker modules, and Dune metadata.

## Errors / Corrections
- Root `AGENTS.md` and `CLAUDE.md` were not present in the initial `pi-agent-native` cwd; the task's PRD and code surfaces are in `symphony-orchestrator`, where repo guidance files were loaded.
- Initial build caught an unused `rec` and an ambiguous `summary` record label in the new module; both were corrected before tests were added.

## Ready for Next Run
- Focused projection test command passed: `opam exec -- dune exec apps/backend/test/test_backend.exe -- test runtime-state 11-18 --compact`.
- Full verification passed after code changes: `pnpm test` ran 287 tests successfully, then `pnpm backend:build` completed `dune build @all`.
