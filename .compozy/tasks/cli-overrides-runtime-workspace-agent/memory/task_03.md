# Task Memory: task_03.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Implement task 03: add five runtime-only CLI override flags to the extracted Cmdliner module, strict positive-integer parsing, help text, unsupported-mode pre-scan, and focused tests. Do not wire parsed values into runtime startup; task 04 owns pass-through.

## Important Decisions
- Follow task 03 plus ADR-004 for CLI parsing location: override parsing belongs in `apps/backend/lib/cli_command.ml`, while `apps/backend/bin/main.ml` stays thin.
- Keep Cmdliner's observed duplicate-option behavior: repeated `--polling.intervalMs` is rejected with exit 124 and "cannot be repeated" wording.

## Learnings
- Pre-change signal: `apps/backend/lib/cli_command.ml` has no runtime override args; existing `polling.intervalMs` references are config helper/tests from task 01, not CLI parsing or help coverage.
- Cmdliner classifies `--polling.intervalMs -1` as an unknown `-1` option unless the CLI module normalizes runtime override values before evaluation; task 03 added parser-local normalization so strict field-specific validation handles negative values.

## Files / Surfaces
- Expected implementation surfaces: `apps/backend/lib/cli_command.ml` and `apps/backend/test/test_backend.ml`.
- `apps/backend/bin/main.ml` now calls `Cli_command.eval`; runtime startup intentionally ignores parsed overrides until task 04 wires pass-through.

## Errors / Corrections
- Initial direct `dune build` failed because the project expects `opam exec`; `rtk opam exec -- dune build apps/backend/test/test_backend.exe` succeeded after using the project environment.
- Initial duplicate-option test expected last-value-wins, but observed Cmdliner behavior rejects repeated `opt` values; tests now document rejection.
- Repository has no installed coverage tooling (`bisect_ppx` absent and no coverage scripts found), so verification used focused CLI tests plus full `pnpm test` rather than a numeric coverage report.

## Ready for Next Run
- Verification evidence before tracking: `rtk pnpm backend:build` exit 0; `rtk pnpm test` exit 0 with 166 backend tests run; `rtk git diff --check` exit 0.
- Task 04 should consume `args.Cli_command.overrides` from the runtime callback and apply/pass it through startup; task 03 intentionally stops at parsing and guard behavior.
