# Task Memory: task_11.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Update operator documentation for the Compozy-backed Local Issue Tracker after runtime behavior from tasks 01/06/09/10, including opt-in tracker selection, GitHub default preservation, PRD-run/task-step semantics, retry/progress behavior, selector support, and secret-free examples.
- Baseline before docs edits: `pnpm docs:test` passed for existing GitHub/minibeads-only examples, but `rg "compozy_tasks|compozy:<task_name>|maxTaskStepRetries|\\.compozy/tasks/<task_name>|Compozy PRD" README.md .github/project-tracking.md CONTEXT.md scripts/validate-docs-examples.js` found no Compozy tracker documentation.

## Important Decisions
- Added glossary entries for **Compozy PRD Run** and **Compozy Task Step** because the main README now uses those terms as operator-facing domain language.
- Kept `.github/project-tracking.md` scoped to the GitHub Tracker and added only a pointer to Compozy-backed Local Issue Tracker setup in the README.
- Extended `scripts/validate-docs-examples.js` instead of adding a separate docs test runner so `pnpm docs:test` remains the focused documentation validation command.

## Learnings
- Existing `scripts/validate-docs-examples.js` is the focused docs verification surface and currently checks README plus `.github/project-tracking.md` JSON examples, secret-free wording, glossary usage, and GitHub tracker scoping.
- `pnpm frontend:test` and `pnpm frontend:build` should not be run concurrently because both invoke ReScript build state. `pnpm test` and `pnpm backend:build` should not be run concurrently because both invoke Dune.

## Files / Surfaces
- Updated docs/test surfaces: `README.md`, `.github/project-tracking.md`, `CONTEXT.md`, and `scripts/validate-docs-examples.js`.

## Errors / Corrections
- Initial broad verification was run in parallel and produced build-state contention: `pnpm backend:build` failed with "Another Dune instance is currently running" while `pnpm test` was active, and concurrent ReScript commands emitted compiler-info replacement errors. Reran the verification commands sequentially.

## Ready for Next Run
- Sequential verification before tracking updates passed: `pnpm docs:test`, `pnpm test`, `pnpm backend:build`, `pnpm frontend:test`, and `pnpm frontend:build`. `frontend:build` emitted existing dependency "use client" bundling warnings and exited 0.
- Self-review checks before tracking updates: docs secret scan returned no matches, no `apps/frontend/src` files changed, and legacy `WORKFLOW.md` references were scoped to existing legacy/fixture/history wording.
