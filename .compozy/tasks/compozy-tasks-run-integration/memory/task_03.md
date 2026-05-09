# Task Memory: task_03.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Implement task 03: map one `.compozy/tasks/<task_name>/` directory to one Symphony `Issue.t` with canonical `compozy:<task_name>` identity, progress aggregates, and Compozy-safe branch/workspace key behavior.

## Important Decisions
- `Compozy_tasks_tracker.prd_run` carries task steps, current step, counts, and `not_runnable_reason`; `Issue.t` mapping exposes only PRD-run identity/title/state.
- Compozy branch keys use `Workspace.sanitize` on the full `compozy:<slug>` identifier, avoiding the legacy numeric extraction path.
- Missing Compozy roots discover zero candidates; empty or duplicate-index PRD directories are represented as `not_runnable` PRD runs.

## Learnings
- Pre-change backend has Compozy task-file parsing/updating, but no PRD-run model, discovery API, issue mapping, or aggregate progress surface.
- No repository coverage command or Bisect instrumentation was found; verification relied on focused Alcotest cases plus the required `pnpm test` backend suite.

## Files / Surfaces
- Touched surfaces: `apps/backend/lib/compozy_tasks_tracker.ml`, `apps/backend/lib/orchestrator.ml`, `apps/backend/test/test_backend.ml`.

## Errors / Corrections
- Initial compile failed on OCaml record-label inference around `state_of_steps`; fixed with explicit `task_counts` and `task_step option` annotations.
- Initial tests used `Option.exists`, unavailable in this OCaml environment; replaced with a local test helper.

## Ready for Next Run
- Verification: `pnpm backend:build` passed; focused `test_backend.exe test config --quick-tests --show-errors` passed 63 tests; `pnpm test` exited 0; fresh direct backend test run `test_backend.exe test --quick-tests --show-errors` passed 258 tests after tracking updates; `git diff --check` passed.
