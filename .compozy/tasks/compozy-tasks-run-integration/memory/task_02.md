# Task Memory: task_02.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Implement the backend file foundation for Compozy PRD task-step parsing and frontmatter updates in `apps/backend/lib/compozy_tasks_tracker.ml`, with focused Alcotest coverage in `apps/backend/test/test_backend.ml`.

## Important Decisions
- Work in `/Users/matheusbbarni/projects/symphony-orchestrator`; the original shell cwd was `/Users/matheusbbarni/projects/pi-agent-native`, but the PRD task paths and backend sources belong to `symphony-orchestrator`.
- Keep this task limited to parsing, ordering, scoped path validation, and frontmatter updates. PRD-run issue mapping, prompt assembly, runtime state projection, and orchestration are later tasks.
- Implemented `Compozy_tasks_tracker` with string-result APIs instead of raising validation exceptions, matching existing backend preference for deterministic caller-facing errors.
- Frontmatter updates replace or append only top-level `status`, `symphony_retry_count`, and `symphony_last_error` keys; Markdown body content after the closing delimiter is preserved.

## Learnings
- Repo-local guidance exists in `AGENTS.md`, `CLAUDE.md`, and `apps/backend/CLAUDE.md`; backend changes require `pnpm test`.
- The checkout already has task 01 tracking edits and untracked workflow memory files before task 02 implementation; avoid reverting or staging unrelated tracking churn.
- `Compozy_tasks_tracker` does not exist yet, so the pre-change signal is absence of `apps/backend/lib/compozy_tasks_tracker.ml`.
- The parser supports the task-file dependency forms present in Compozy artifacts: inline lists such as `dependencies: []` and block lists under `dependencies:`.
- Verification evidence after implementation: `pnpm test` passed with 250 tests, including the new Compozy parser/updater cases; `pnpm backend:build` passed.

## Files / Surfaces
- Added `apps/backend/lib/compozy_tasks_tracker.ml`.
- Updated `apps/backend/test/test_backend.ml` with focused parser, updater, path-scope, and temp-directory integration coverage.

## Errors / Corrections
- Initial repo-root lookup in `pi-agent-native` failed to find `apps/backend`; corrected by switching to the PRD repository `symphony-orchestrator`.
- Self-review tightened frontmatter replacement to top-level keys only and rejected negative retry-count writes.

## Ready for Next Run
- Task 03 can build PRD-run discovery on `Compozy_tasks_tracker.list_task_files`, `parse_task_file`, and the frontmatter update helpers. The module intentionally does not yet map PRD runs to `Issue.t` or assemble prompts.
