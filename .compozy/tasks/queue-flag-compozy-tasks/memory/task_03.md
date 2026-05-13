# Task Memory: task_03.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Refactor Ordered Queue orchestration so Runtime State and `.symphony/state/ordered_queue.json` keep operator-supplied queue identifiers, while dispatch/order/admission/state updates use resolved canonical issue identifiers.

## Important Decisions
- Store `Ordered_queue.resolved` on the orchestrator for queue matching/order/admission, while keeping the raw `Ordered_queue.t` as the source for Runtime State projection and persisted resume-key matching.
- Keep skipped queue diagnostics keyed to `Runtime_state.ordered_queue_entry.issue_identifier`; for bare Compozy queues that remains the operator-facing raw slug.

## Learnings
- Pre-change orchestrator already projects queue state from `Ordered_queue.entry.issue_identifier`, so raw bare slugs would be persisted when passed in.
- Pre-change matching still compares queue entry text directly to `Issue.identifier`, so bare Compozy queue entries do not match canonical `compozy:<slug>` candidates.
- The repository has no configured coverage tooling or `bisect_ppx` dependency; verification evidence is the full backend Alcotest suite rather than a coverage report.

## Files / Surfaces
- Expected code surfaces: `apps/backend/lib/orchestrator.ml`, `apps/backend/test/test_backend.ml`.
- Touched code surfaces: `apps/backend/lib/orchestrator.ml`, `apps/backend/test/test_backend.ml`.
- Tracking surfaces to update after verification: `task_03.md`, `_tasks.md`.

## Errors / Corrections
- Initial compile failed because `Option.exists` is unavailable in this OCaml environment; replaced it with direct option equality.

## Ready for Next Run
- `pnpm test` passed after implementation: 352 backend tests, including new bare Compozy raw-resume, raw skip diagnostic, and raw-state dispatch-order coverage.
- Final forced verification passed with `opam exec -- dune runtest --force`: 352 backend tests. Code/test commit created as `3dc57d8 fix: resolve Compozy queue orchestration identifiers`; tracking and memory files were intentionally left unstaged.
