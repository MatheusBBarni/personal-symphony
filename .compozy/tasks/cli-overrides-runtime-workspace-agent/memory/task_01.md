# Task Memory: task_01.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Implement Task 01: add a Cmdliner-independent transient Runtime Settings Invocation Override record and helper that applies the five issue-66 fields to a loaded `Config.t` without changing Runtime Settings parsing or files.

## Important Decisions
- Keep the model/helper in `apps/backend/lib/config.ml` so it can reuse existing `expand_path` behavior directly and avoid Dune dependency churn.

## Learnings
- Pre-change search found no existing `runtime_invocation` or `apply_runtime_invocation` symbols under `apps/backend`.
- `Config.from_settings_file` already resolves `workspace.root` with `expand_path ~base_dir:workspace_root`; the override helper should call the same function.
- The apply helper also reuses existing positive integer validation for numeric override values, preserving `Config.t` numeric invariants before later CLI parsing work is added.
- No repository coverage command or Bisect instrumentation was found by searching for `coverage`, `bisect`, `bisect_ppx`, or `instrument`; verification used the full backend test suite and build gate.

## Files / Surfaces
- Implemented in `apps/backend/lib/config.ml`: `runtime_invocation_overrides` record plus `apply_runtime_invocation_overrides`.
- Tested in `apps/backend/test/test_backend.ml`: polling-only override, agent-only overrides, no overrides, relative/absolute/home workspace root expansion, and settings-file preservation.

## Errors / Corrections
- First `pnpm test` attempt failed because OCaml warning 23 treats redundant record `with` on fully listed records as an error; helper was corrected to construct `polling`, `workspace`, and `agent` records directly.
- Second `pnpm test` attempt exposed that path tests must expect `expand_path` parent canonicalization (`/private/var` on macOS temp paths), matching existing Runtime Settings behavior.

## Ready for Next Run
- Task 01 implementation is ready for tracking update and commit after final verification. Later tasks can call `Config.apply_runtime_invocation_overrides ~workspace_root loaded_config overrides` after Runtime Settings load.
