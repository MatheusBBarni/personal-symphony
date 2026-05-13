# Task Memory: task_04.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Implement Task 04 by rendering MVP active-run panels from `Terminal_console_model.t` only: Active Work Home, Readiness/Attention, Ordered Queue, Compozy PRD Run progress, task detail summaries, narrow/minimum terminal handling, and snapshot/unit coverage.

## Important Decisions
- Keep this task read-only over projected Runtime State data; do not add task lifecycle controls, Runtime State fields, or Web Dashboard parity behavior.
- Add pure panel-formatting helpers in `terminal_console_mosaic.ml` and render Mosaic widgets from those helpers, so tests can snapshot panel text without coupling to Mosaic internals.

## Learnings
- Repo-level `AGENTS.md` and `CLAUDE.md` were not present in `/Users/matheusbbarni/projects/pi-agent-native`; the prompt's AGENTS instruction resolved to `/Users/matheusbbarni/.codex/RTK.md`, requiring shell commands to be prefixed with `rtk`.
- The actual implementation worktree for this PRD is `/Users/matheusbbarni/projects/symphony-orchestrator`; `/Users/matheusbbarni/projects/pi-agent-native` does not contain the `apps/backend/...` task paths.
- `pnpm test` initially exposed two unrelated orchestrator context-diagnostic flakes after the new panel tests passed; the focused rerun of orchestrator cases 49-50 passed, and the final full `pnpm test` run passed all 303 tests.

## Files / Surfaces
- Planned primary surfaces: `apps/backend/bin/terminal_console_mosaic.ml`, `apps/backend/lib/terminal_console_model.ml`, `apps/backend/test/test_backend.ml`, and task tracking files after verification.
- Touched implementation/test surfaces: `apps/backend/bin/terminal_console_mosaic.ml` and `apps/backend/test/test_backend.ml`.

## Errors / Corrections
- Corrected one readiness-panel test assertion to join wrapped lines before checking remediation text, because narrow rendering can split phrases across physical terminal lines while preserving the full text.

## Ready for Next Run
- Task 04 implementation is verified with `pnpm backend:build` and `pnpm test` after code/test changes. Task 04 tracking has been marked complete; commit only implementation/test files unless tracking files are explicitly requested.
