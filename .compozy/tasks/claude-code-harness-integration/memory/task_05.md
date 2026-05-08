# Task Memory: task_05.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Rename Runtime State aggregate token totals from `codex_totals` to `usage_totals`, remove the old JSON key, and expose selected Harness identity on running rows.
- Scope is backend Runtime State/orchestrator/CLI/test updates; frontend live-state migration is deferred to task 06 per `_tasks.md`.

## Important Decisions
- Treat ADR-004's frontend "same change" note as feature-level guidance, not a blocker for task 05, because the master task split explicitly assigns frontend state updates to task 06.
- Model running-row Harness identity as nullable Runtime State fields so manually constructed or legacy in-memory rows can serialize with the key present even when no selected Harness is known.

## Learnings
- Pre-change scan found `codex_totals` in `Runtime_state.t`, Runtime State JSON serialization, terminal summary rendering, orchestrator aggregate updates, and backend tests.
- The Product Repository has no Bisect/coverage command configured; validation evidence is the required backend Alcotest suite.

## Files / Surfaces
- Touched: `apps/backend/lib/runtime_state.ml`, `apps/backend/lib/orchestrator.ml`, `apps/backend/bin/main.ml`, `apps/backend/test/test_backend.ml`.
- Tracking/memory touched: task 05 memory and task tracking files.

## Errors / Corrections
- A first mechanical test edit inserted Harness identity fields into a non-record assertion block; removed it and reran `pnpm test` cleanly.
- `pnpm test` passed after implementation: 169 backend tests, including Runtime State JSON and Codex/Claude dispatch Harness identity cases.

## Ready for Next Run
- Backend Runtime State now serializes `usage_totals`, omits `codex_totals`, and adds running-row `harness_name`/`harness_kind`.
- Task 06 should update frontend ReScript live-state types/tests from `codex_totals` to `usage_totals` and consume the new Harness identity fields.
