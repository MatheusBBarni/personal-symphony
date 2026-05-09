# Task Memory: task_04.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Build Compozy task-step base prompt assembly for the currently runnable `task_NN.md`, including `_prd.md` and `_techspec.md` when present, while preserving existing `Prompt.render`/GitHub composition behavior.

## Important Decisions
- Scope is limited to Compozy prompt base content and deterministic missing-runnable-step diagnostics; sequential relaunch, runtime state projection, retry/skip behavior, and readiness wiring remain later tasks.

## Learnings
- Task 04 depends on the current narrow Compozy tracker module added by task 03; GitHub prompt wrapping remains owned by `Orchestrator.compose_prompt_result`.
- `Compozy_tasks_tracker.current_prompt` now selects `run.current_step`, reads the full current `task_NN.md`, and appends `_prd.md` / `_techspec.md` sections only when those files exist.
- `Orchestrator.compose_compozy_task_step_prompt_result` wraps the Compozy base prompt through the existing `compose_prompt_result`; the normal GitHub `compose_prompt` path remains unchanged.
- No repository coverage command or Bisect instrumentation was found in `package.json`, `dune-project`, or app files; task coverage evidence is focused Alcotest cases plus full `pnpm test`.

## Files / Surfaces
- Touched implementation surfaces: `apps/backend/lib/compozy_tasks_tracker.ml`, `apps/backend/lib/orchestrator.ml`, and focused cases in `apps/backend/test/test_backend.ml`.
- Tracking/memory surfaces touched: `.compozy/tasks/compozy-tasks-run-integration/task_04.md`, `_tasks.md`, and `memory/task_04.md`.

## Errors / Corrections
- Initial prompt diagnostic test exposed completed PRD runs without a reason suffix; fixed `current_prompt` to report `PRD run is completed`.
- A sequential optional-context read refactor briefly introduced an unmatched parenthesis; `pnpm test` caught the syntax error and the full suite passed after correction.

## Ready for Next Run
- Task 04 implementation and test evidence are ready for tracking update and commit after final verification.
