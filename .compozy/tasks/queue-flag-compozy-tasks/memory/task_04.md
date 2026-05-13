# Task Memory: task_04.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Update task 04 user-facing queue documentation and CLI help after tasks 02/03 stabilized runtime behavior.
- Acceptance hinges on narrow `--queue` bare Compozy slug guidance, readiness-owned tracker mismatch text, raw-sequence resume wording, tests, verification, tracking updates, and one local commit.

## Important Decisions
- Treat ADR-003 as the refinement of ADR-001's earlier implementation note: queue state/resume preserve raw queue identifiers, while canonical identifiers remain downstream tracker identity.

## Learnings
- Current pre-change signal: `README.md`, `CONTEXT.md`, `docs/adr/0010-ordered-queue-runtime-state.md`, and `apps/backend/lib/cli_command.ml` do not contain the expected bare-Compozy queue shortcut wording.
- Existing runtime tests already cover bare slug readiness mismatch, mixed Compozy styles, raw-sequence resume, and bare Compozy dispatch; task 04 should add docs/help assertions rather than duplicate runtime implementation coverage.
- Final verification evidence: `pnpm docs:test` passed with 9 JSON examples checked; `pnpm test` passed 354 Alcotest tests; `pnpm backend:build` exited 0; `git diff --check` exited 0.
- No coverage-specific command exists in this repository (`bisect_ppx`/coverage tooling is not configured); the task's test coverage requirement is represented by focused docs/help assertions plus the full backend suite.

## Files / Surfaces
- Candidate update surfaces: `apps/backend/lib/cli_command.ml`, `README.md`, `CONTEXT.md`, `docs/adr/0010-ordered-queue-runtime-state.md`, `apps/backend/test/test_backend.ml`, and `scripts/validate-docs-examples.js`.
- Final implementation surfaces: `apps/backend/lib/cli_command.ml`, `README.md`, `CONTEXT.md`, `docs/adr/0010-ordered-queue-runtime-state.md`, `apps/backend/test/test_backend.ml`, and `scripts/validate-docs-examples.js`.

## Errors / Corrections
- First `pnpm docs:test` failed because a new README assertion crossed a markdown line break; narrowed the assertion to a stable semantic fragment.
- First `pnpm test` failed in the new CLI help assertion because Cmdliner wraps "Workspace Repository issue identifiers"; split that expectation into separately rendered fragments.

## Ready for Next Run
- Task 04 implementation and verification are complete; only commit/final reporting should remain if this memory is read again during closeout.
