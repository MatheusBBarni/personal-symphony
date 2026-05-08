# Task Memory: task_01.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Implement Runtime Settings parsing for `tracker.kind = "github" | "minibeads"` while keeping GitHub as the default and leaving Runtime Contract defaults unchanged.
- Gate GitHub-only readiness gaps behind the selected GitHub tracker path; this task does not execute `mb` or validate the local store.

## Important Decisions
- Keep task scope in `Config` and backend tests only unless compilation reveals direct type fallout.
- Treat unsupported tracker kinds as configuration errors with an actionable message naming supported kinds.
- Keep legacy `WORKFLOW.md` parsing GitHub-only; minibeads support is only for Runtime Settings as required by this task.

## Learnings
- Baseline focused test `opam exec -- dune exec apps/backend/test/test_backend.exe -- test config 0` passes because current code rejects all non-GitHub tracker kinds.
- `Config.from_settings_file` currently defaults `tracker.kind` to `github`, then rejects any other value before parsing tracker fields.
- Repository has no configured coverage reporter or `bisect_ppx` instrumentation; verification used the existing backend Alcotest suite and backend build.

## Files / Surfaces
- Touched: `apps/backend/lib/config.ml`
- Touched: `apps/backend/test/test_backend.ml`

## Errors / Corrections
- New settings tests initially failed because fixtures lacked the `.symphony` parent needed by existing path expansion; fixed fixtures to create runtime parent directories.

## Ready for Next Run
- Implementation and self-review completed for task 01.
- Verification evidence before tracking: `pnpm test` passed 158 tests; `pnpm backend:build` passed; `git diff --check` passed.
- Local implementation commit created: `b4b1342 feat: add minibeads tracker config parsing`.
