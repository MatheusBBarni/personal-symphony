# Task Memory: task_04.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Implement task 04: minibeads candidate fetch, canonical `mb-<number>` lookup, blocker-aware dispatchability, and idempotent status updates through the Issue Tracker boundary.

## Important Decisions
- `Minibeads_tracker.command_runner.run` now executes the exact command string; readiness explicitly invokes `mb --version`, while fetch/lookup/status build their own `mb` command lines.
- Candidate fetch uses `mb --json list` via the configured command/root, then filters to supported active minibeads statuses and excludes issues blocked by non-terminal dependencies.
- Status writes normalize common Symphony statuses to minibeads statuses (`open`, `in_progress`, `blocked`, `closed`) and skip the command when the issue is already at the target state.

## Learnings
- minibeads 0.13.x exposes global `--json`, `list`, `show`, and `update --status`; JSON issues include `id`, `title`, `description`, `status`, `priority`, `labels`, `dependencies`, `created_at`, and `updated_at`.
- minibeads has no stable comments/events model in this version, so mapped local issues intentionally keep `Issue.comments = []`.

## Files / Surfaces
- Expected implementation surfaces: `apps/backend/lib/minibeads_tracker.ml`, `apps/backend/lib/issue_tracker.ml` as needed, and focused additions in `apps/backend/test/test_backend.ml`.
- Touched `apps/backend/lib/minibeads_tracker.ml`, `apps/backend/lib/issue_tracker.ml`, and `apps/backend/test/test_backend.ml`.

## Errors / Corrections
- Initial focused test invocation used an unsupported Alcotest `--filter` flag; correct scoped form is `test <suite-name> --quick-tests --compact`.
- Readiness tests were updated because readiness now records the explicit command `mb '--version'` instead of relying on the runner to append `--version`.
- Self-review found inline blocker states needed normalization before terminal-state checks; fixed before final verification.

## Ready for Next Run
- Implementation and verification are complete. Fresh verification: `pnpm test` passed 175 tests, and `pnpm backend:build` passed after the final code change.
- No numeric coverage command exists in the repository; coverage target is addressed through focused tests added near the existing backend suite.
