# Task Memory: task_02.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Extract existing Cmdliner command construction into backend library module without adding override flags.

## Important Decisions
- Use `Cli_command` in `apps/backend/lib` as a parser/command boundary that accepts executable callbacks; this keeps runtime process wiring in `apps/backend/bin/main.ml` while allowing backend tests to evaluate the command directly.

## Learnings
- Pre-change signal: `apps/backend/bin/main.ml` owned `open Cmdliner`, existing args, `Cmd.group`, and help argv normalization.
- Direct backend tests can evaluate the factored `Cli_command.cmd` with fake callbacks, proving parser behavior without shelling out to the built executable.

## Files / Surfaces
- Touched: `apps/backend/lib/cli_command.ml`, `apps/backend/bin/main.ml`, `apps/backend/lib/dune`, `apps/backend/test/dune`, `apps/backend/test/test_backend.ml`.

## Errors / Corrections
- RTK filtered cached `pnpm test` output too aggressively for final evidence; reran `opam exec -- dune runtest --force` through `rtk proxy` to capture the full 161-test passing result.

## Ready for Next Run
- Task 02 implementation verified with `opam exec -- dune build @all`, `opam exec -- dune runtest --force`, and `git diff --check` for changed code files.
- No durable cross-task memory promotion needed; the extracted `Cli_command` module is discoverable from the code and task tracking.
