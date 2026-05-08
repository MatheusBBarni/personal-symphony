# Task Memory: task_04.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Completed: parsed Runtime Settings Invocation Overrides now flow from `Cli_command` through default runtime startup, applying after Runtime Home bootstrap and settings load while preserving root validation order and settings bytes.

## Important Decisions
- Keep override application in a small runtime startup helper so `Config.from_settings_file` remains file-only and default startup paths receive one effective `Config.t`.
- Startup reporting should derive from the effective config and include the effective `workspace.root` so tests can prove the report observes `--workspace.root`.

## Learnings
- `apps/backend/bin/main.ml` currently parses overrides through `Cli_command` but drops them in `callbacks`.
- `Config.apply_runtime_invocation_overrides` already resolves `--workspace.root` relative to the Workspace Repository root and copies the loaded config.
- `Runtime_startup.prepare_runtime` now captures the validated/bootstrap/load boundary; production startup and tests both use that helper.
- `pnpm test` ran successfully with 172 Alcotest cases after the runtime startup changes.

## Files / Surfaces
- Touched: `apps/backend/bin/main.ml`, `apps/backend/lib/runtime_startup.ml`, `apps/backend/test/test_backend.ml`.
- Tracking/memory touched: current task memory; task tracking pending after final status update.

## Errors / Corrections
- `ocamlformat` is not installed in the active opam switch; kept edits in existing local style and verified with Dune tests/build.
- Running `pnpm test` and `pnpm backend:build` in parallel races on Dune `_build/.lock`; rerun them sequentially for final verification.

## Ready for Next Run
- Task tracking for task 04 was marked complete after passing backend verification and self-review.
- Check `Runtime_startup` for the effective config load path if a later task needs runtime consumer assertions.
