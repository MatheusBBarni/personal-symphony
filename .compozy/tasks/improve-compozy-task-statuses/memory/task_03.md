# Task Memory: task_03.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Wire `Issue_tracker.compozy` so discovered Compozy PRD Runs load/backfill Runtime Home lifecycle metadata, expose lifecycle `dispatch_state` as the issue state, and persist tracker status updates through lifecycle metadata.
- Keep the issue boundary at one Compozy PRD Run per work item; Compozy Task Steps remain ordered progress only.
- Pre-change signal: `apps/backend/lib/issue_tracker.ml` currently maps Compozy candidates via `Compozy_tasks_tracker.issue_of_prd_run` and has `update_status = (fun _ _ -> Ok ())`.

## Important Decisions
- `Issue_tracker.compozy` owns lifecycle application at the PRD Run boundary: discovery loads/backfills/reconciles lifecycle metadata, and issue rows use lifecycle `dispatch_state`.
- Tracker `update_status` persists only lifecycle `dispatch_state` and `updated_at`; later orchestrator tasks still own stage-specific lifecycle phase transitions and PR readiness transitions.
- Compozy Task Step frontmatter is not edited by tracker status updates.

## Learnings
- Task 03 scope is limited to the Compozy-backed Local Issue Tracker adapter and focused backend tests; orchestrator transition writes, PR handoff mirroring, terminal rendering, dashboard rendering, and docs remain later PRD tasks unless required by adapter tests.
- Lazy lifecycle backfill during tracker fetch writes Runtime Home metadata. Git-backed orchestrator tests need Runtime Home ignored before polling so clean-worktree dispatch checks remain meaningful.
- The repository has no coverage tool configured; required coverage evidence is the focused backend test matrix added for every explicit Task 03 test item.

## Files / Surfaces
- Expected code surfaces: `apps/backend/lib/issue_tracker.ml`, `apps/backend/test/test_backend.ml`.
- Implemented surfaces: `apps/backend/lib/compozy_lifecycle.ml`, `apps/backend/lib/issue_tracker.ml`, `apps/backend/test/test_backend.ml`.
- Integration test surfaces covered: `Ordered_queue.validation_gaps` through `Issue_tracker.compozy`, and `Manual_merge.run` with completed lifecycle metadata.

## Errors / Corrections
- First `pnpm test` run failed four Compozy orchestrator tests because discovery backfilled Runtime Home lifecycle files before dispatch and those test fixtures had not ignored `.symphony/`. Fixed fixtures with existing `ignore_runtime_home` helper, then reran verification.

## Ready for Next Run
- Verification after final code change: `pnpm test` passed with 293 tests; `pnpm backend:build` passed.
- Local implementation commit created: `6a834a3 feat: wire Compozy tracker lifecycle state`.
- Workflow memory and tracking files remain unstaged by design; pre-existing `.compozy/agents/*/AGENT.md` deletions and task_01/task_02 tracking edits remain unrelated.
