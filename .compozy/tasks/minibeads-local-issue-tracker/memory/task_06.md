# Task Memory: task_06.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Implement Ordered Queue support for canonical tracker identifiers: GitHub `20`/`#20` normalize to `#20`, minibeads `mb-<number>` stays canonical, malformed selectors are rejected, persisted queue state resumes by canonical identifier sequence, and startup validation uses the selected `Issue_tracker`.

## Important Decisions
- Remove Ordered Queue's numeric issue-number dependency from matching and ordering; queue entries are compared by canonical `issue_identifier`.
- CLI readiness validation should call `Issue_tracker.fetch_by_identifiers_detailed` so GitHub can retain project-membership diagnostics while minibeads uses selected-tracker lookup.

## Learnings
- The implementation repo is `/Users/matheusbbarni/projects/worktree/5d27fcd5-74c3-4b8f/symphony-orchestrator`; the initial shell context pointed at a different project that does not contain the backend paths.
- Existing dirty tracking files from prior tasks are present in `.compozy/tasks/minibeads-local-issue-tracker`; leave unrelated task tracking changes untouched.
- The repository has no configured coverage runner or bisect dependency; validation evidence for this task is focused Alcotest coverage plus full `pnpm test`.

## Files / Surfaces
- Touched: `apps/backend/lib/ordered_queue.ml`, `apps/backend/lib/orchestrator.ml`, `apps/backend/bin/main.ml`, and `apps/backend/test/test_backend.ml`.
- Tracking/memory updated: task-local memory, shared memory, `task_06.md`, and `_tasks.md`.

## Errors / Corrections
- Corrected `Ordered_queue.validation_gaps` to treat a tracker lookup row with `issue = None` and no diagnostic as missing, avoiding a false valid queue entry.

## Ready for Next Run
- Ordered Queue entries are canonical `issue_identifier` values. Parser accepts GitHub numeric/hash selectors and minibeads `mb-<number>`, rejects URLs/cross-repo/malformed selectors, and detects duplicate canonical identifiers.
- Queue validation is now `Ordered_queue.validation_gaps tracker queue`, using `Issue_tracker.fetch_by_identifiers_detailed` and selected tracker active/terminal semantics.
- Local implementation commit: `e4b5caf feat: support local identifiers in ordered queue`.
