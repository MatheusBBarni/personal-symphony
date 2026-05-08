# Task Memory: task_05.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Refactor `apps/backend/lib/orchestrator.ml` so shared polling, dispatch filtering, and status writes use the selected `Issue_tracker.t` rather than `Github_tracker.t`.

## Important Decisions
- `Orchestrator.fetch` now returns `(Issue.t list, Issue_tracker.poll_error) result`; default polling delegates to `Issue_tracker.fetch_candidates`.
- Dispatchability now requires selected-tracker `is_active` and not selected-tracker `is_terminal`, so terminal semantics are honored even when a status also appears active after tracker normalization.

## Learnings
- Existing orchestrator tests injected list-returning fetch stubs; those stubs need `Ok [...]` after moving the poll boundary to generic tracker poll errors.
- Full backend verification is `pnpm test`. No coverage script or OCaml coverage instrumentation is configured in this repository; `ocamlfind query bisect_ppx` reports the package is not installed.

## Files / Surfaces
- `apps/backend/lib/orchestrator.ml`
- `apps/backend/test/test_backend.ml`

## Errors / Corrections
- Initial compile exposed remaining list-returning test fetch stubs; updated them to the new result contract.
- Verification note: `pnpm test` passed 179 backend tests. Coverage percentage could not be measured with existing repo tooling.

## Ready for Next Run
