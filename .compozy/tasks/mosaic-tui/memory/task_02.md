# Task Memory: task_02.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Implement Task 02: add Mosaic as a reproducible backend executable dependency and introduce the minimal executable-side `Terminal_console_mosaic` shell that renders a `Terminal_console_model` projection without runtime wiring or lifecycle mutation.
- Pre-change signal captured: `apps/backend/bin/terminal_console_mosaic.ml` is absent and no `mosaic` dependency appears in `dune-project` or backend Dune files.

## Important Decisions
- Scope remains dependency metadata plus compile/link shell only. Do not rewire `main.ml` default Terminal Console runtime in this task.
- Use Dune-generated `personal_symphony.opam` from `dune-project` instead of maintaining separate hand-written opam dependency metadata.
- Update the npm export workflow's OCaml dependency install steps to consume local opam metadata so Mosaic is installed in packaging CI.

## Learnings
- Current opam metadata reports `mosaic` version `0.1.0` with dependencies `ocaml >= 5.1`, `dune >= 3.19`, `matrix`, `toffee`, `cmarkit`, and `tree-sitter`.
- Active opam switch has Dune `3.23.0`, which satisfies Mosaic's `dune >= 3.19` requirement.
- `opam install . --deps-only --dry-run` now recognizes the generated package definition and reports no dependency work in the prepared switch.
- `apps/backend/lib` remains Mosaic-free; Mosaic is confined to the private executable-side `symphony_terminal_console_shell` library under `apps/backend/bin`.
- `Terminal_console_mosaic` currently renders a projected snapshot only. Runtime orchestration wiring remains for a later task.

## Files / Surfaces
- Expected implementation surfaces: `dune-project`, `apps/backend/bin/dune`, new `apps/backend/bin/terminal_console_mosaic.ml`, and focused backend tests.
- Additional dependency surfaces touched: generated `personal_symphony.opam`, `.github/workflows/export-npm.yml`, and README Product Repository development dependency notes.
- `apps/backend/bin/main.ml` has a no-op compile/link anchor so the shell module is linked into the backend executable without changing `--once` or `--web` behavior.

## Errors / Corrections
- A parallel smoke run attempted two Dune executions at once and one exited with Dune's single-instance lock error; reran the plain `--once` smoke sequentially and it passed.

## Ready for Next Run
- Verification evidence before tracking update: `pnpm backend:build` exit 0; `pnpm test` exit 0; direct Alcotest JSON run reported `success: 289`, `failures: 0`; `opam install . --deps-only --with-test --dry-run` exit 0; `node scripts/package-binary.js` wrote `vendor/symphony-darwin-arm64`; `--once` and `--web --once` smokes exited 0.
- Implementation commit: `f164005 build: add mosaic terminal shell dependency`. Tracking and workflow memory files remain unstaged by repository instruction.
