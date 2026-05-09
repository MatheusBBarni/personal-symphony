# Task Memory: task_08.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Implement Compozy task-step retry handling for failed task launches: increment frontmatter retry metadata, retry the same step until `tracker.compozy.maxTaskStepRetries`, mark over-limit steps failed/skipped, advance to the next runnable task step, and surface failed/skipped counts in Runtime State without changing GitHub retry behavior.

## Important Decisions
- Use `failed` as the over-limit task-step state. The existing Runtime State projection already carries failed/skipped counts, and a failed terminal PRD run state keeps over-limit work visible when no runnable steps remain.

## Learnings
- Repository guidance requires backend runtime behavior changes to be verified with `pnpm test`.
- Existing workspace already has uncommitted Compozy task tracking changes from earlier tasks; backend implementation should avoid reverting them and keep tracking updates scoped to task 08.
- There is still no configured backend coverage command or Bisect instrumentation; task 08 verification used focused Alcotest coverage plus the full `pnpm test` suite, consistent with shared workflow memory.

## Files / Surfaces
- Touched surfaces: `apps/backend/lib/compozy_tasks_tracker.ml`, `apps/backend/lib/orchestrator.ml`, `apps/backend/test/test_backend.ml`, `.compozy/tasks/compozy-tasks-run-integration/task_08.md`, and `.compozy/tasks/compozy-tasks-run-integration/_tasks.md`.
- `Runtime_state` already exposed failed/skipped counts through `compozy_progress`; task 08 updates the Compozy progress after failed-step transitions and adds regression coverage rather than changing the JSON shape.

## Errors / Corrections

## Ready for Next Run
- Focused checks passed: `opam exec -- dune exec apps/backend/test/test_backend.exe -- test orchestrator --show-errors --color=never` and `opam exec -- dune exec apps/backend/test/test_backend.exe -- test config --show-errors --color=never`.
- Full backend verification passed: `pnpm test` ran 275 tests successfully. It emitted only the existing Node warning that `NO_COLOR` is ignored because `FORCE_COLOR` is set.
