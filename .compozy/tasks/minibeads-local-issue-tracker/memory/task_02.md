# Task Memory: task_02.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Implement task 02: add the shared `Issue_tracker` boundary and a GitHub adapter over existing `Github_tracker` behavior without refactoring orchestration callers yet.
- Required evidence: adapter selection test, GitHub active/terminal parity tests, rate-limit mapping test, lookup diagnostic preservation test, existing GitHub tracker tests still passing, and full backend verification before commit.

## Important Decisions
- Scope stays limited to the boundary and GitHub adapter. Minibeads implementation, orchestrator injection, Ordered Queue validation, Manual Task Merge validation, and Runtime State tracker kind are later tasks.
- `fetch_by_identifiers` keeps the TechSpec option-list shape; `fetch_by_identifiers_detailed` is included to preserve GitHub lookup diagnostics that later tasks need.

## Learnings
- No conflict found between task 02, `_techspec.md`, and ADR-003/ADR-006: the boundary should exist now, but shared callers move to it in later tasks.
- Focused backend test run after implementation: `opam exec -- dune runtest apps/backend/test` passed with 162 tests.
- Required verification: `pnpm test` exited 0; `pnpm backend:build` exited 0.

## Files / Surfaces
- Added: `apps/backend/lib/issue_tracker.ml`
- Updated: `apps/backend/test/test_backend.ml`

## Errors / Corrections
- Initial focused test run failed because the GitHub adapter test fixture did not create `.symphony/` before `Config.from_settings_file`; fixed by creating the Runtime Home directory in the helper.

## Ready for Next Run
- Task 02 implementation and verification are complete.
- Local implementation commit: `dc866e1 feat: add issue tracker GitHub adapter`.
- Tracking/memory files were intentionally left outside the implementation commit per repository staging rules.
