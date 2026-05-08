# Task Memory: task_07.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Implement Task 07: Manual Task Merge must accept selected-tracker identifiers (`20`, `#20`, `mb-<number>`), resolve through `Issue_tracker`, preserve Task Branch Integration preflights, and update selected tracker status after successful merge.

## Important Decisions
- Pre-change signal: `apps/backend/lib/manual_merge.ml` uses `type selector = { raw; number; identifier }` and rejects anything except numeric/`#` selectors, so `mb-20` is not supported before this task.
- Manual Task Merge now receives a selected `Issue_tracker.t` instead of GitHub-specific fetch/status callbacks; detailed lookup diagnostics preserve GitHub Project membership errors while minibeads missing issues use the existing missing-tracker message shape.

## Learnings
- The implementation target is `/Users/matheusbbarni/projects/worktree/5d27fcd5-74c3-4b8f/symphony-orchestrator`, not the initial shell cwd `/Users/matheusbbarni/projects/pi-agent-native`.
- Existing task files for tasks 01-06 and master tracking already have uncommitted changes from earlier runs; keep them intact and only update Task 07/current tracking when complete.
- No repository coverage command/Bisect setup was found; Task 07 coverage was added through focused Alcotest cases in the existing backend suite.
- Verification evidence before tracking updates: `opam exec -- dune exec apps/backend/test/test_backend.exe -- test manual-merge` passed 11 tests, and `pnpm test` passed 186 backend tests.

## Files / Surfaces
- Touched: `apps/backend/lib/manual_merge.ml`, `apps/backend/bin/main.ml`, `apps/backend/test/test_backend.ml`, `.compozy/tasks/minibeads-local-issue-tracker/task_07.md`, `.compozy/tasks/minibeads-local-issue-tracker/_tasks.md`, and this task memory file.

## Errors / Corrections

## Ready for Next Run
- Task 07 implementation and tests are complete; final verification and local commit remain the closeout gate after tracking updates.
