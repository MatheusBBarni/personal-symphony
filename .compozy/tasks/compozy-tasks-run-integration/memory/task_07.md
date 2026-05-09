# Task Memory: task_07.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Implement sequential Compozy PRD task-step orchestration inside one Agent Worktree and Task Branch. Intermediate step completion must update task frontmatter and relaunch the next step without running final Stage Commit, Stage Push, Task Branch Integration, or cleanup.

## Important Decisions
- Kept the change scoped to the existing `orchestrator.ml` completion path plus small `Compozy_tasks_tracker` status helpers; no shared tracker abstraction was introduced for this task.
- Dispatch now marks the selected Compozy task step `in_progress` in the Agent Worktree before composing the task-step prompt so Runtime State agrees with the active step that will be committed on the Task Branch.
- Completion now marks the current Compozy task step `completed` in the Agent Worktree, refreshes Runtime State progress from that worktree copy, and relaunches the next runnable step before falling through to final completion behavior only when no current step remains.

## Learnings
- `Issue_tracker.compozy.update_status` is intentionally still no-op; task-step status persistence belongs to Compozy task frontmatter updates in `Compozy_tasks_tracker`.
- The existing Agent Worktree reuse logic already keys Compozy workspaces and Task Branches by the stable `compozy:<slug>` identifier, so relaunch can reuse `dispatch_issue` after clearing the completed child runtime row.
- Compozy task-step frontmatter updates must target the Agent Worktree copy, not only the Loop-Start checkout, so the final Stage Commit can include the task-step status changes.
- Alcotest does not support `--list-test-cases`; use `test <suite-regex> [case-number]` or run a suite regex directly.

## Files / Surfaces
- `apps/backend/lib/orchestrator.ml`
- `apps/backend/lib/compozy_tasks_tracker.ml`
- `apps/backend/test/test_backend.ml`

## Errors / Corrections
- Initial test placement referenced helpers defined later in `test_backend.ml`; corrected by making the Compozy sequential test self-contained.
- Self-review found that updating only the Loop-Start checkout would leave frontmatter out of the final Task Branch commit; corrected orchestration to derive the Compozy root inside the reused Agent Worktree.

## Ready for Next Run
- Verification after final code changes: `pnpm test` passed with 272 backend tests. `git diff --check` passed before the final full test run and no code changed afterward.
- Task tracking was updated after verification: `task_07.md` status/checklists completed and `_tasks.md` row 07 completed.
- Coverage target note: this repository still has no configured coverage command; evidence remains focused Alcotest coverage for the new sequential path plus the full backend test suite.
