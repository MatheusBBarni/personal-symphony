# Task Memory: task_08.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Add selected Issue Tracker kind to Runtime State snapshots and frontend parsing.
- Replace Terminal Console and Web Dashboard copy that assumes GitHub Projects/project-only issues.
- Keep V1 dashboard scope limited to wording and tracker context, without local metadata cards.

## Important Decisions
- Runtime State always serializes `tracker_kind`; the backend default is `github` so older construction paths remain compatible.
- Frontend defaulting for absent/blank tracker kind lives in `apps/frontend/src/RuntimeState.res` and is used by dashboard mapping.
- Dashboard V1 only shows tracker kind and neutral issue-tracker wording; it does not render local metadata cards.

## Learnings
- Baseline before implementation: Runtime State/backend/frontend sources do not expose `tracker_kind`; dashboard still says "Project board" and "No project issues...".
- Worktree already had prior task-tracking modifications and an untracked memory directory before task 08 edits; do not revert or commit unrelated prior changes.
- No repository coverage command is configured; verification used the required focused frontend/backend tests and package build gate.
- `pnpm prepack` rewrites tracked `vendor/symphony-darwin-arm64`; this is a verification artifact for this task and should not be included in the task source commit.

## Files / Surfaces
- Expected surfaces: `apps/backend/lib/runtime_state.ml`, `apps/backend/lib/orchestrator.ml`, `apps/backend/bin/main.ml`, `apps/backend/test/test_backend.ml`, `apps/frontend/src/Main.res`, `apps/frontend/src/Pages/Dashboard.res`, `apps/frontend/test/liveState.test.mjs`.
- Added `apps/frontend/src/RuntimeState.res` for frontend Runtime State defaulting helpers.

## Errors / Corrections
- Initial `pnpm frontend:test` failed before tests because `node_modules` was missing and `rescript` was unavailable; ran `pnpm install`, then frontend verification passed.

## Ready for Next Run
- Verification evidence before tracking update: `pnpm frontend:test`, `pnpm frontend:build`, `pnpm test`, `pnpm backend:build`, `pnpm prepack`, and `git diff --check` exited 0. Frontend build/prepack emitted existing dependency "use client" bundling warnings.
