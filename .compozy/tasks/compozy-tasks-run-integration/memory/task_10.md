# Task Memory: task_10.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Implement Task 10: support canonical `compozy:<task_name>` identifiers in Ordered Queue and Manual Task Merge where V1 requires them, while preserving numeric GitHub selector behavior.
- Scope is backend only: `ordered_queue.ml`, `manual_merge.ml`, `main.ml`, `compozy_tasks_tracker.ml`, and targeted Alcotest coverage.

## Important Decisions
- Follow ADR-003 narrow path; do not introduce a broad selected-tracker abstraction unless the existing code forces it.
- Ordered Queue and Manual Task Merge now normalize `compozy:<task_name>` locally before URL/cross-repository rejection; selected-tracker validation remains the boundary for existence/readiness.
- Manual Task Merge keeps terminal-state rejection for GitHub/minibeads, but permits unintegrated terminal Compozy PRD runs only when the discovered run state is `completed`.

## Learnings
- The selected `Issue_tracker.compozy` adapter already resolves PRD-run identifiers without GitHub Project membership; Task 10 only needed parser/preflight support plus regression coverage.
- Verification evidence: focused `runtime-state` and `manual-merge` Alcotest suites passed, full `pnpm test` passed with 277 tests, and `pnpm backend:build` passed.

## Files / Surfaces
- `apps/backend/lib/ordered_queue.ml`
- `apps/backend/lib/manual_merge.ml`
- `apps/backend/test/test_backend.ml`

## Errors / Corrections

## Ready for Next Run
- Task 10 implementation and verification are complete. Tracking files were updated after clean verification and self-review.
