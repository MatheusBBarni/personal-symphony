# Task Memory: task_06.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Wire `tracker.kind = "compozy_tasks"` into backend startup readiness so Compozy runs use local PRD-run checks and avoid GitHub remote readiness dependencies.

## Important Decisions
- Keep task 06 scoped to startup/readiness and initial Runtime State projection; sequential task-step orchestration remains task 07.
- Extracted CLI readiness state construction into `Runtime_readiness` so startup readiness can be tested directly without shelling through the binary.
- The Compozy `Issue_tracker` adapter currently discovers/fetches runnable PRD-run candidates and reports readiness; status updates intentionally remain no-op until task 07 implements task-step transitions.

## Learnings
- Baseline: `Issue_tracker.make` still rejects `compozy_tasks` with an unsupported-adapter `invalid_arg`, so CLI readiness can currently surface a generic `tracker.adapter` gap instead of Compozy readiness gaps.
- Compozy readiness gaps use `tracker.compozy.root`, `tracker.compozy.prdRuns`, and `tracker.compozy.runnablePrdRun`; valid Compozy readiness omits GitHub owner/repo/project/token gaps.
- `Runtime_state.initial_compozy_progress` seeds the first runnable PRD run, falling back to the first discovered run for non-runnable progress visibility.

## Files / Surfaces
- Planned surfaces: `apps/backend/lib/issue_tracker.ml`, `apps/backend/lib/compozy_tasks_tracker.ml`, `apps/backend/bin/main.ml`, and `apps/backend/test/test_backend.ml`.
- Touched surfaces: `apps/backend/lib/runtime_readiness.ml`, `apps/backend/lib/runtime_state.ml`, `apps/backend/lib/orchestrator.ml`, and `apps/backend/lib/runtime_startup.ml` in addition to the planned files.

## Errors / Corrections
- No blocking corrections after implementation. Focused readiness/adapter tests and full `pnpm test` passed.

## Ready for Next Run
- Task 07 can build on the Compozy adapter and should replace the no-op `update_status` behavior with task-step frontmatter transitions and sequential relaunch.
