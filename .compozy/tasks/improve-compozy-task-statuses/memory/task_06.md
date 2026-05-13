# Task Memory: task_06.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Render Compozy PRD Run lifecycle/readiness fields in Terminal Console while preserving existing step progress lines, and verify HTTP/live Runtime State surfaces expose the same extended `compozy_progress` snapshot payload.

## Important Decisions
- Keep shared workflow memory unchanged for now; current findings are task-local and already derivable from task_06 context.
- Added a small `Terminal_console` backend helper for PRD Run Progress line construction so Terminal Console copy can be asserted directly in backend tests while `main.ml` remains responsible for colorized printing.

## Learnings
- Pre-change signal: `apps/backend/bin/main.ml` renders only run, slug, current step, and step counts under `PRD Run Progress`; no Terminal Console lifecycle/readiness labels are present.
- Task 02 already extended `Runtime_state.compozy_progress` JSON/parsing with optional lifecycle fields; task_06 should verify backend surfaces rather than add a new endpoint or event shape.
- HTTP and Live Dashboard Connection paths already serialize `Runtime_state.to_yojson`; task_06 coverage verifies the full snapshot shape and extended `compozy_progress` fields instead of changing server routing.

## Files / Surfaces
- `apps/backend/lib/terminal_console.ml`: new pure helper for compact Compozy PRD Run Progress rows.
- `apps/backend/bin/main.ml`: Terminal Console now prints the helper's rows under `PRD Run Progress`.
- `apps/backend/test/test_backend.ml`: added Terminal Console lifecycle omission/inclusion tests, expanded HTTP assertions, and added live snapshot `compozy_progress` shape coverage.

## Errors / Corrections
- None.

## Ready for Next Run
- Final verification evidence: `rtk pnpm backend:build` exited 0; `rtk pnpm test` exited 0; `rtk opam exec -- dune runtest --force` exited 0 with 306 backend tests run.
- Shared memory was not changed for this task because no durable cross-task constraint was discovered.
