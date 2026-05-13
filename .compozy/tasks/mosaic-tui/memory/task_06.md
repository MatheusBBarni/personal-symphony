# Task Memory: task_06.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Document the implemented richer default Terminal Console runtime semantics, add Product Repository ADR coverage, update operator docs, add docs assertions, and complete final backend/task/package validation.

## Important Decisions
- Product Repository docs need updating because normal `symphony` now runs the richer read-first Terminal Console in the foreground while orchestration runs in the background when readiness permits.

## Learnings
- Existing product docs did not yet describe the read-first default Terminal Console, safe local aids, or the no task lifecycle mutation MVP boundary.
- Existing backend tests already cover Terminal Console projection, mode selection, safe aids, and Runtime State handoff; task 06 should add documentation assertions rather than broaden runtime behavior.
- `pnpm npm:validate` can fail in this environment before repository validation starts because npm reads user config with `before=null`; setting `NPM_CONFIG_USERCONFIG=/dev/null` lets the package export validation run without editing user config.

## Files / Surfaces
- Planned surfaces: `CONTEXT.md`, `README.md`, `docs/adr/`, `apps/backend/test/test_backend.ml`, task tracking files, and this task memory.
- Touched product surfaces: `CONTEXT.md`, `README.md`, `docs/adr/0024-default-rich-terminal-console.md`, `apps/backend/test/test_backend.ml`, and `scripts/validate-docs-examples.js`.

## Errors / Corrections
- First `pnpm docs:test` failed on overly brittle assertion strings split across wrapped Markdown; fixed by adding explicit docs text and relaxing assertion fragments where appropriate.
- Initial `pnpm npm:validate` failed with `npm error Invalid time value` from user npm config, then passed with `NPM_CONFIG_USERCONFIG=/dev/null`.

## Ready for Next Run
- Validation evidence gathered: `pnpm docs:test`, `pnpm backend:build`, `pnpm test`, `compozy tasks validate --name mosaic-tui`, `pnpm prepack`, and `pnpm npm:validate` with npm user config isolated.
