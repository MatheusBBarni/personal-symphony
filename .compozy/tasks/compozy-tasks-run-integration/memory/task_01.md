# Task Memory: task_01.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Add Runtime Settings support for `tracker.kind = "compozy_tasks"` in the backend config layer only, preserving GitHub as the default and avoiding `runtime_home.ml`.

## Important Decisions
- Keep this task scoped to parsed settings and readiness gating; Compozy file validation/orchestration remains for later PRD tasks.
- Store Compozy settings as `tracker.compozy.root` and `tracker.compozy.maxTaskStepRetries`, leaving existing minibeads `tracker.root` parsing unchanged.
- Use missing-path-preserving expansion for `tracker.compozy.root` so selecting the Compozy tracker does not require `.compozy/tasks` to exist during config parsing.

## Learnings
- Target code lives in `/Users/matheusbbarni/projects/symphony-orchestrator`, not the initial `pi-agent-native` cwd.
- Pre-change signal: backend config/test code has no `compozy_tasks`, `compozy`, or `maxTaskStepRetries` support, and `parse_tracker_kind` accepts only `github` and `minibeads`.
- There is no coverage command or Bisect setup in this repository; backend verification is the Alcotest suite via `pnpm test` plus build via `pnpm backend:build`.

## Files / Surfaces
- Touched surfaces: `apps/backend/lib/config.ml` and `apps/backend/test/test_backend.ml`.

## Errors / Corrections
- Initial inspection from `pi-agent-native` could not find the task files; corrected by switching to the Product Repository containing the PRD and backend.
- First Compozy root parser used the stricter existing `expand_path`, which failed when `.compozy/` did not exist; corrected with missing-path-preserving expansion.

## Ready for Next Run
- Fresh verification passed before tracking updates: `pnpm test` ran 243 tests, and `pnpm backend:build` completed with exit 0.
