# Task Memory: task_04.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Task 04 objective: wire orchestrator Compozy PRD Run lifecycle transitions for Stage Agent dispatch, retry/failure, step advancement, final completion, and attention paths while preserving Compozy Task Step progress/retry semantics.
- Source-of-truth docs read before implementation: task_04.md, _prd.md, _techspec.md, _tasks.md, ADR-001, ADR-002, ADR-003, root AGENTS.md/CLAUDE.md, and apps/backend/CLAUDE.md.

## Important Decisions
- Added lifecycle transition helpers in `Compozy_lifecycle` for retrying, failed, skipped, blocked, and completed outcomes so orchestrator writes stay centralized.
- Orchestrator records Compozy lifecycle on Stage Agent dispatch after preserving the existing Compozy Task Step `in_progress` update.
- Final successful Compozy PRD Run completion marks lifecycle `completed` only after commit/status/integration success paths, while attention and non-retryable failures mark `blocked` with concise reasons.

## Learnings
- Worktree already has unrelated pending tracking/memory changes and deleted `.compozy/agents/*` files before task_04 code edits; leave them untouched unless they directly block this task.
- Compozy auto-merge/protected-path lifecycle tests must commit the final task-step frontmatter change before auto-merge, otherwise the path stops at the existing uncommitted-worktree attention branch.
- No repository coverage command or Bisect/coverage tooling is currently defined; verification evidence for the task is the backend test/build gate plus focused lifecycle assertions.

## Files / Surfaces
- `apps/backend/lib/compozy_lifecycle.ml`: added transition helpers for retrying, failed, skipped, blocked, and completed lifecycle metadata.
- `apps/backend/lib/orchestrator.ml`: wired lifecycle updates into Compozy dispatch, retry/failure, blocked/attention, and final completion paths.
- `apps/backend/test/test_backend.ml`: added focused Compozy lifecycle dispatch, retry/failure, final completion, merge attention, protected-path attention, and non-retryable completion tests.

## Errors / Corrections
- Initial dispatch patch had an unmatched OCaml parenthesis; fixed and confirmed with `pnpm backend:build`.
- A protected-path lifecycle test first stopped at uncommitted worktree attention because final task-step frontmatter was not committed; fixed the fixture to commit `.compozy` before auto-merge.
- Running `pnpm test` concurrently with `pnpm backend:build` produced a Dune `_build/.lock` error; reran `pnpm test` by itself successfully and promoted the concurrency rule to shared memory.

## Ready for Next Run
- Verification after implementation: `pnpm backend:build` passed; `pnpm test` passed 298 tests. `git diff --check` passed for touched code/tracking files.
